// S3-08 · Almacenamiento seguro de credenciales (HU-30, HU-31).
//
// CON-10 es el caso de docs/contrato-api-acceso.md (sección 5).
// CRED-01 a CRED-09 son pruebas nuevas de esta tarjeta, anotadas en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { createAuthService } = require('../src/services/auth.service');
const passwords = require('../src/services/password.service');

const { hashPassword, parseHash, verifyPassword } = passwords;

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };

/** App y servicio sobre el mismo almacén, para revisar lo guardado. */
function setup() {
  const store = createMemoryStore();
  const app = createApp({ store });
  const auth = createAuthService({ store });
  const register = (body) => request(app).post('/api/auth/register').send(body);
  return { store, auth, register };
}

describe('Contraseña guardada', () => {
  test('CON-10 · HU-30 · después de un registro la contraseña no está en texto plano', async () => {
    const { store, register } = setup();

    const res = await register(ana);
    const guardada = await store.findUserByEmail('ana@mail.com');

    expect(res.status).toBe(201);
    expect(guardada).not.toHaveProperty('password');
    expect(guardada.passwordHash).toMatch(/^scrypt\$\d+\$\d+\$\d+\$[A-Za-z0-9+/=]+\$[A-Za-z0-9+/=]+$/);
    expect(guardada.passwordHash).not.toContain('kopay2026');
    // Cabe en la columna de S3-05: CHECK (char_length(password_hash) >= 20).
    expect(guardada.passwordHash.length).toBeGreaterThanOrEqual(20);
    // Ni la contraseña ni el hash salen en la respuesta.
    const cuerpo = JSON.stringify(res.body);
    expect(cuerpo).not.toContain('kopay2026');
    expect(cuerpo).not.toContain(guardada.passwordHash);
    expect(cuerpo).not.toMatch(/password/i);
  });

  test('CRED-01 · HU-30 · la misma contraseña da hashes distintos (sal aleatoria)', async () => {
    const a = await hashPassword('kopay2026');
    const b = await hashPassword('kopay2026');

    expect(a).not.toBe(b);
    expect(parseHash(a).salt.equals(parseHash(b).salt)).toBe(false);
    expect(await verifyPassword('kopay2026', a)).toBe(true);
    expect(await verifyPassword('kopay2026', b)).toBe(true);
  });

  test('CRED-02 · HU-30 · el hash guarda sus parámetros, sal de 16 bytes y clave de 64', async () => {
    const parsed = parseHash(await hashPassword('kopay2026'));

    expect(parsed).toMatchObject({ N: 16384, r: 8, p: 1 });
    expect(parsed.salt).toHaveLength(16);
    expect(parsed.key).toHaveLength(64);
  });

  test('CRED-03 · HU-30 · no se calcula el hash de una contraseña vacía o que no es texto', async () => {
    await expect(hashPassword('')).rejects.toThrow(TypeError);
    await expect(hashPassword(undefined)).rejects.toThrow(TypeError);
  });
});

describe('Validar la contraseña al entrar', () => {
  test('CRED-04 · HU-31 · la contraseña correcta coincide y las demás no', async () => {
    const hash = await hashPassword('kopay2026');

    expect(await verifyPassword('kopay2026', hash)).toBe(true);
    for (const otra of ['kopay2027', 'Kopay2026', ' kopay2026', 'kopay2026 ', '', undefined]) {
      expect(await verifyPassword(otra, hash)).toBe(false);
    }
  });

  test('CRED-05 · HU-31 · un hash alterado o con formato desconocido nunca coincide', async () => {
    const hash = await hashPassword('kopay2026');
    const partes = hash.split('$');
    const clave = Buffer.from(partes[5], 'base64');
    clave[0] ^= 1;
    const alterado = [...partes.slice(0, 5), clave.toString('base64')].join('$');

    expect(await verifyPassword('kopay2026', alterado)).toBe(false);
    for (const raro of ['kopay2026', '', null, 'bcrypt$10$abc', 'scrypt$x$8$1$abc$def']) {
      expect(await verifyPassword('kopay2026', raro)).toBe(false);
    }
  });

  test('CRED-06 · HU-31 · la misma contraseña escrita con otra forma Unicode coincide', async () => {
    // "ñ" precompuesta (teclado de iPhone) y "n" + tilde combinada.
    const hash = await hashPassword('mañana2026');

    expect(await verifyPassword('mañana2026', hash)).toBe(true);
  });

  test('CRED-07 · HU-31 · verifyCredentials devuelve la cuenta solo con los datos correctos', async () => {
    const { auth, register } = setup();
    await register(ana);

    const ok = await auth.verifyCredentials('  ANA@mail.com ', 'kopay2026');
    const mala = await auth.verifyCredentials('ana@mail.com', 'kopay2027');
    const sinTexto = await auth.verifyCredentials('ana@mail.com', 12345678);

    expect(ok).toEqual({
      id: expect.any(String),
      name: 'Ana López',
      email: 'ana@mail.com',
      role: 'user',
      createdAt: expect.any(String),
    });
    expect(ok).not.toHaveProperty('passwordHash');
    expect(mala).toBeNull();
    expect(sinTexto).toBeNull();
  });

  test('CRED-08 · HU-31 · con un correo que no existe también compara contra un hash', async () => {
    const store = createMemoryStore();
    const verify = jest.fn(passwords.verifyPassword);
    const auth = createAuthService({
      store,
      passwordService: { hashPassword: passwords.hashPassword, verifyPassword: verify },
    });
    await auth.register(ana);

    const noExiste = await auth.verifyCredentials('nadie@mail.com', 'kopay2026');
    const malaClave = await auth.verifyCredentials('ana@mail.com', 'otra2026');

    expect(noExiste).toBeNull();
    expect(malaClave).toBeNull();
    // Las dos rutas calculan scrypt, así tardan lo mismo.
    expect(verify).toHaveBeenCalledTimes(2);
    expect(parseHash(verify.mock.calls[0][1])).not.toBeNull();
  });

  test('CRED-09 · HU-30 · un correo repetido no llega a calcular el hash', async () => {
    const store = createMemoryStore();
    const hash = jest.fn(passwords.hashPassword);
    const auth = createAuthService({
      store,
      passwordService: { hashPassword: hash, verifyPassword: passwords.verifyPassword },
    });
    await auth.register(ana);

    await expect(auth.register({ ...ana, email: 'ANA@mail.com' })).rejects.toMatchObject({
      status: 409,
      code: 'EMAIL_TAKEN',
    });
    expect(hash).toHaveBeenCalledTimes(1);
  });
});
