'use strict';

// S3-05 · Migraciones de usuarios, roles y sesiones contra PostgreSQL
// real (HU-30 a HU-34), permisos de contador (S3-06, HU-37 a HU-42) y
// códigos de recuperación (S4-19, HU-32). Casos DB-01 a DB-03 de
// docs/base-de-datos.md, y DB-06 de S4-19.
//
//   DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/kopay_test npm run test:db
//
// ATENCIÓN: borra todo el esquema `public` de esa base. Nunca la apuntes
// a `development` ni a `production`.

const { Client } = require('pg');

const { loadConfig } = require('../../src/config');
const { runMigrations } = require('../../src/data/migrate');

const config = loadConfig({ ...process.env, NODE_ENV: 'test' });
const HASH = '$2b$12$abcdefghijklmnopqrstuuJr0mK8m3pU3nH6bZyX9q2a1b3c4d5e6';

let client;

/** Corre [sql] y devuelve el código de error de PostgreSQL, o null. */
async function errorCode(sql, params) {
  try {
    await client.query(sql, params);
    return null;
  } catch (err) {
    return err.code;
  }
}

async function insertUser(email, role = 'user') {
  const { rows } = await client.query(
    `INSERT INTO users (name, email, password_hash, role)
     VALUES ('Ana López', $1, $2, $3) RETURNING id, role, created_at`,
    [email, HASH, role],
  );
  return rows[0];
}

beforeAll(async () => {
  client = new Client({ connectionString: config.databaseUrl });
  await client.connect();
  const { rows } = await client.query('SELECT current_database() AS db');
  if (!/test/.test(rows[0].db)) {
    throw new Error(
      `La base "${rows[0].db}" no parece de pruebas; se detiene para no borrarla.`,
    );
  }
  await client.query('DROP SCHEMA public CASCADE');
  await client.query('CREATE SCHEMA public');
});

afterAll(async () => {
  await client?.end();
});

describe('DB-01 · Migración desde cero', () => {
  test('DB-01 · HU-30 · la primera vez crea todas las tablas en orden', async () => {
    const done = await runMigrations(client);
    expect(done).toEqual([
      '001_users_roles_sessions.sql',
      '002_accountant_access.sql',
      '003_password_resets.sql',
    ]);

    const { rows } = await client.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' ORDER BY table_name`,
    );
    expect(rows.map((r) => r.table_name)).toEqual([
      'accountant_access',
      'password_resets',
      'schema_migrations',
      'sessions',
      'users',
    ]);
  });

  test('DB-01 · HU-30 · la segunda vez no hace nada y no falla', async () => {
    await expect(runMigrations(client)).resolves.toEqual([]);
    const { rows } = await client.query(
      'SELECT version FROM schema_migrations ORDER BY version',
    );
    expect(rows).toEqual([{ version: '001' }, { version: '002' }, { version: '003' }]);
  });
});

describe('DB-02 · Restricciones', () => {
  beforeEach(() => client.query('TRUNCATE users CASCADE'));

  test('DB-02 · HU-30 · un usuario válido recibe uuid, rol user y fecha', async () => {
    const user = await insertUser('ana@mail.com');
    expect(user.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(user.role).toBe('user');
    expect(user.created_at).toBeInstanceOf(Date);
  });

  test('DB-02 · HU-30 · el mismo correo no crea otra cuenta', async () => {
    await insertUser('ana@mail.com');
    expect(
      await errorCode(
        `INSERT INTO users (name, email, password_hash) VALUES ('Otra', 'ana@mail.com', $1)`,
        [HASH],
      ),
    ).toBe('23505'); // unique_violation
  });

  test('DB-02 · HU-30 · un correo con mayúsculas o espacios se rechaza (se guarda normalizado)', async () => {
    for (const email of ['Ana@Mail.com', ' ana@mail.com']) {
      expect(
        await errorCode(
          `INSERT INTO users (name, email, password_hash) VALUES ('Ana', $1, $2)`,
          [email, HASH],
        ),
      ).toBe('23514'); // check_violation
    }
  });

  test('DB-02 · HU-37 · un rol que no existe se rechaza', async () => {
    expect(
      await errorCode(
        `INSERT INTO users (name, email, password_hash, role) VALUES ('Ana', 'ana@mail.com', $1, 'admin')`,
        [HASH],
      ),
    ).toBe('23514');
    await expect(insertUser('conta@mail.com', 'accountant')).resolves.toMatchObject({
      role: 'accountant',
    });
  });

  test('DB-02 · HU-30 · nombre vacío o de más de 80 caracteres se rechaza', async () => {
    for (const name of ['', '   ', ' Ana', 'a'.repeat(81)]) {
      expect(
        await errorCode(
          `INSERT INTO users (name, email, password_hash) VALUES ($1, 'ana@mail.com', $2)`,
          [name, HASH],
        ),
      ).toBe('23514');
    }
  });

  test('DB-02 · HU-30 · una contraseña corta en texto plano no cabe como hash', async () => {
    expect(
      await errorCode(
        `INSERT INTO users (name, email, password_hash) VALUES ('Ana', 'ana@mail.com', 'kopay2026')`,
      ),
    ).toBe('23514');
  });

  test('DB-02 · HU-31 · una sesión necesita usuario existente, token único y expiración futura', async () => {
    const user = await insertUser('ana@mail.com');
    const insert = (userId, token, expires) =>
      errorCode(
        `INSERT INTO sessions (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
        [userId, token, expires],
      );
    const later = new Date(Date.now() + 3600_000);

    expect(await insert(user.id, 'hash-1', later)).toBeNull();
    expect(await insert(user.id, 'hash-1', later)).toBe('23505');
    expect(await insert(user.id, 'hash-2', new Date(Date.now() - 1000))).toBe('23514');
    expect(
      await insert('00000000-0000-0000-0000-000000000000', 'hash-3', later),
    ).toBe('23503'); // foreign_key_violation
  });

  test('DB-02 · HU-34 · borrar un usuario borra sus sesiones', async () => {
    const user = await insertUser('ana@mail.com');
    await client.query(
      `INSERT INTO sessions (user_id, token_hash, expires_at)
       VALUES ($1, 'hash-1', now() + interval '1 hour')`,
      [user.id],
    );
    await client.query('DELETE FROM users WHERE id = $1', [user.id]);
    const { rows } = await client.query('SELECT count(*)::int AS n FROM sessions');
    expect(rows[0].n).toBe(0);
  });
});

describe('Capa de datos PostgreSQL', () => {
  const { createPgStore } = require('../../src/data/pg-store');
  let store;

  beforeAll(() => {
    store = createPgStore({ databaseUrl: config.databaseUrl });
  });
  afterAll(() => store.close());
  beforeEach(() => client.query('TRUNCATE users CASCADE'));

  test('DB-07 · HU-30 · createUser guarda la cuenta y un correo repetido devuelve null', async () => {
    const user = await store.createUser({
      name: 'Ana López',
      email: 'ana@mail.com',
      passwordHash: HASH,
      role: 'user',
    });
    expect(user).toMatchObject({ name: 'Ana López', email: 'ana@mail.com', role: 'user' });
    expect(user.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(new Date(user.createdAt).toISOString()).toBe(user.createdAt);

    await expect(
      store.createUser({ name: 'Otra', email: 'ana@mail.com', passwordHash: HASH, role: 'user' }),
    ).resolves.toBeNull();
  });

  test('DB-07 · HU-31 · findUserByEmail devuelve la cuenta con su hash, o null', async () => {
    await store.createUser({ name: 'Ana', email: 'ana@mail.com', passwordHash: HASH, role: 'user' });
    await expect(store.findUserByEmail('ana@mail.com')).resolves.toMatchObject({
      email: 'ana@mail.com',
      passwordHash: HASH,
    });
    await expect(store.findUserByEmail('nadie@mail.com')).resolves.toBeNull();
    await expect(store.ping()).resolves.toBe(true);
  });
});

describe('DB-03 · Conceder y revocar acceso a un contador', () => {
  const { createPgStore } = require('../../src/data/pg-store');
  let store;
  let ana;
  let luis;
  let conta;
  let otro;

  beforeAll(() => {
    store = createPgStore({ databaseUrl: config.databaseUrl });
  });
  afterAll(() => store.close());
  beforeEach(async () => {
    await client.query('TRUNCATE users CASCADE');
    ana = await insertUser('ana@mail.com');
    luis = await insertUser('luis@mail.com');
    conta = await insertUser('conta@mail.com', 'accountant');
    otro = await insertUser('otro@mail.com', 'accountant');
  });

  test('DB-03 · HU-38 · conceder crea un permiso vigente con fecha', async () => {
    const { grant, created } = await store.createGrant({
      userId: ana.id,
      accountantId: conta.id,
    });
    expect(created).toBe(true);
    expect(grant).toMatchObject({
      userId: ana.id,
      accountantId: conta.id,
      revokedAt: null,
    });
    expect(grant.id).toMatch(/^[0-9a-f-]{36}$/);
    expect(new Date(grant.grantedAt).toISOString()).toBe(grant.grantedAt);
    await expect(
      store.findActiveGrant({ userId: ana.id, accountantId: conta.id }),
    ).resolves.toEqual(grant);
  });

  test('DB-03 · HU-38 · conceder dos veces no crea otro permiso vigente', async () => {
    const first = await store.createGrant({ userId: ana.id, accountantId: conta.id });
    const second = await store.createGrant({ userId: ana.id, accountantId: conta.id });
    expect(second.created).toBe(false);
    expect(second.grant).toEqual(first.grant);
    // El índice único parcial también lo impide sin pasar por la capa.
    expect(
      await errorCode(
        'INSERT INTO accountant_access (user_id, accountant_id) VALUES ($1, $2)',
        [ana.id, conta.id],
      ),
    ).toBe('23505');
  });

  test('DB-03 · HU-41 · revocar solo cuenta el permiso vigente y conserva el historial', async () => {
    const { grant } = await store.createGrant({ userId: ana.id, accountantId: conta.id });

    await expect(store.revokeGrant({ grantId: grant.id, userId: ana.id })).resolves.toBe(true);
    await expect(
      store.findActiveGrant({ userId: ana.id, accountantId: conta.id }),
    ).resolves.toBeNull();
    await expect(store.listActiveGrantsByUser(ana.id)).resolves.toEqual([]);
    // Revocar otra vez no hace nada.
    await expect(store.revokeGrant({ grantId: grant.id, userId: ana.id })).resolves.toBe(false);

    const history = await store.listGrantsByUser(ana.id);
    expect(history).toHaveLength(1);
    expect(history[0].revokedAt).not.toBeNull();

    // Después de revocar se puede conceder de nuevo: queda uno vigente.
    const again = await store.createGrant({ userId: ana.id, accountantId: conta.id });
    expect(again.created).toBe(true);
    expect(await store.listGrantsByUser(ana.id)).toHaveLength(2);
    expect(await store.listActiveGrantsByUser(ana.id)).toEqual([again.grant]);
  });

  test('DB-03 · HU-34 · nadie revoca un permiso ajeno; un id mal formado no existe', async () => {
    const { grant } = await store.createGrant({ userId: ana.id, accountantId: conta.id });
    await expect(store.revokeGrant({ grantId: grant.id, userId: luis.id })).resolves.toBe(false);
    await expect(store.revokeGrant({ grantId: 'no-es-uuid', userId: ana.id })).resolves.toBe(false);
    await expect(
      store.findActiveGrant({ userId: 'no-es-uuid', accountantId: conta.id }),
    ).resolves.toBeNull();
    await expect(
      store.findActiveGrant({ userId: ana.id, accountantId: conta.id }),
    ).resolves.not.toBeNull();
  });

  test('DB-03 · HU-39 · cada permiso es de un contador concreto', async () => {
    await store.createGrant({ userId: ana.id, accountantId: conta.id });
    await store.createGrant({ userId: luis.id, accountantId: otro.id });

    await expect(
      store.findActiveGrant({ userId: ana.id, accountantId: otro.id }),
    ).resolves.toBeNull();
    const anas = await store.listActiveGrantsByUser(ana.id);
    expect(anas.map((g) => g.accountantId)).toEqual([conta.id]);
  });

  test('DB-03 · HU-42 · un usuario no se autoriza a sí mismo y una fecha de revocación previa se rechaza', async () => {
    expect(
      await errorCode(
        'INSERT INTO accountant_access (user_id, accountant_id) VALUES ($1, $1)',
        [ana.id],
      ),
    ).toBe('23514');
    expect(
      await errorCode(
        `INSERT INTO accountant_access (user_id, accountant_id, granted_at, revoked_at)
         VALUES ($1, $2, now(), now() - interval '1 day')`,
        [ana.id, conta.id],
      ),
    ).toBe('23514');
  });

  test('DB-03 · HU-34 · borrar a la persona o al contador borra sus permisos', async () => {
    await store.createGrant({ userId: ana.id, accountantId: conta.id });
    await store.createGrant({ userId: luis.id, accountantId: otro.id });
    await client.query('DELETE FROM users WHERE id = $1', [ana.id]);
    await client.query('DELETE FROM users WHERE id = $1', [otro.id]);
    const { rows } = await client.query('SELECT count(*)::int AS n FROM accountant_access');
    expect(rows[0].n).toBe(0);
  });
});

describe('DB-06 · Códigos de recuperación (S4-19)', () => {
  const { createPgStore } = require('../../src/data/pg-store');
  const CODE_HASH = 'c'.repeat(64);
  let store;
  let user;

  beforeAll(() => {
    store = createPgStore({ databaseUrl: config.databaseUrl });
  });
  afterAll(() => store.close());
  beforeEach(async () => {
    await client.query('TRUNCATE users CASCADE');
    user = await insertUser('ana@mail.com');
  });

  const enUnRato = () => new Date(Date.now() + 15 * 60_000).toISOString();

  test('DB-06 · HU-32 · el hash debe tener 64 caracteres y los intentos van de 0 a 5', async () => {
    const insert = (hash, attempts = 0) =>
      errorCode(
        `INSERT INTO password_resets (user_id, code_hash, expires_at, attempts)
         VALUES ($1, $2, now() + interval '15 minutes', $3)`,
        [user.id, hash, attempts],
      );

    expect(await insert('048213')).toBe('23514');
    expect(await insert(CODE_HASH, 6)).toBe('23514');
    expect(await insert(CODE_HASH, 5)).toBeNull();
  });

  test('DB-06 · HU-32 · un código nuevo borra el anterior y los intentos llegan hasta 5', async () => {
    await store.createPasswordReset({ userId: user.id, codeHash: 'a'.repeat(64), expiresAt: enUnRato() });
    const nuevo = await store.createPasswordReset({ userId: user.id, codeHash: CODE_HASH, expiresAt: enUnRato() });

    const { rows } = await client.query('SELECT count(*)::int AS n FROM password_resets');
    expect(rows[0].n).toBe(1);
    expect((await store.findLatestPasswordReset(user.id)).id).toBe(nuevo.id);

    const intentos = [];
    for (let i = 0; i < 6; i += 1) intentos.push(await store.recordPasswordResetFailure(nuevo.id));
    expect(intentos).toEqual([1, 2, 3, 4, 5, null]);
  });

  test('DB-06 · HU-32, HU-34 · completar cambia el hash, cierra las sesiones y no se repite', async () => {
    const reset = await store.createPasswordReset({ userId: user.id, codeHash: CODE_HASH, expiresAt: enUnRato() });
    await store.createSession({ userId: user.id, tokenHash: 't'.repeat(64), expiresAt: enUnRato() });

    const primero = await store.completePasswordReset({
      resetId: reset.id,
      userId: user.id,
      passwordHash: 'scrypt$16384$8$1$bnVldmE=$bnVldmFjbGF2ZQ==',
    });
    const segundo = await store.completePasswordReset({
      resetId: reset.id,
      userId: user.id,
      passwordHash: 'scrypt$16384$8$1$b3RyYQ==$b3RyYWNsYXZl',
    });

    expect(primero).toBe(true);
    expect(segundo).toBe(false);
    expect((await store.findUserById(user.id)).passwordHash).toMatch(/bnVldmFjbGF2ZQ/);
    expect((await store.findLatestPasswordReset(user.id)).usedAt).not.toBeNull();
    const { rows } = await client.query(
      'SELECT count(*)::int AS abiertas FROM sessions WHERE user_id = $1 AND revoked_at IS NULL',
      [user.id],
    );
    expect(rows[0].abiertas).toBe(0);
  });

  test('DB-06 · HU-32 · borrar la cuenta borra sus códigos', async () => {
    await store.createPasswordReset({ userId: user.id, codeHash: CODE_HASH, expiresAt: enUnRato() });

    await client.query('DELETE FROM users WHERE id = $1', [user.id]);

    const { rows } = await client.query('SELECT count(*)::int AS n FROM password_resets');
    expect(rows[0].n).toBe(0);
  });
});
