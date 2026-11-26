'use strict';

// S3-05 · Migraciones de usuarios, roles y sesiones contra PostgreSQL
// real (HU-30 a HU-34). Casos DB-01 y DB-02 de docs/base-de-datos.md.
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
  test('DB-01 · HU-30 · la primera vez crea users, sessions y schema_migrations', async () => {
    const done = await runMigrations(client);
    expect(done).toEqual(['001_users_roles_sessions.sql']);

    const { rows } = await client.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' ORDER BY table_name`,
    );
    expect(rows.map((r) => r.table_name)).toEqual([
      'schema_migrations',
      'sessions',
      'users',
    ]);
  });

  test('DB-01 · HU-30 · la segunda vez no hace nada y no falla', async () => {
    await expect(runMigrations(client)).resolves.toEqual([]);
    const { rows } = await client.query('SELECT version FROM schema_migrations');
    expect(rows).toEqual([{ version: '001' }]);
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
