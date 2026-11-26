// S3-07 · Endpoint de registro de usuario (HU-30).
//
// CON-05 a CON-09 son los casos de registro de
// docs/contrato-api-acceso.md (sección 5). REG-01 a REG-08 son pruebas
// nuevas de esta tarjeta, anotadas en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { MESSAGES, validateRegistration } = require('../src/validators/auth.validator');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };

/** App con su propio almacén en memoria, para revisar lo que se guardó. */
function setup() {
  const store = createMemoryStore({ now: () => new Date('2026-11-26T18:30:00.000Z') });
  const app = createApp({ store });
  const register = (body) => request(app).post('/api/auth/register').send(body);
  return { store, register };
}

describe('POST /api/auth/register', () => {
  test('CON-05 · HU-30 · registro válido → 201 con role user y sin password', async () => {
    const { register } = setup();

    const res = await register(ana);

    expect(res.status).toBe(201);
    expect(res.headers['content-type']).toMatch(/application\/json/);
    expect(res.body).toEqual({
      user: {
        id: expect.stringMatching(UUID),
        name: 'Ana López',
        email: 'ana@mail.com',
        role: 'user',
        createdAt: '2026-11-26T18:30:00.000Z',
      },
    });
    expect(JSON.stringify(res.body)).not.toContain('kopay2026');
    expect(res.body.user).not.toHaveProperty('password');
    expect(res.body.user).not.toHaveProperty('passwordHash');
  });

  test('CON-06 · HU-30 · role: "accountant" se ignora y la cuenta queda como user', async () => {
    const { store, register } = setup();

    const res = await register({ ...ana, role: 'accountant' });

    expect(res.status).toBe(201);
    expect(res.body.user.role).toBe('user');
    expect((await store.findUserByEmail('ana@mail.com')).role).toBe('user');
  });

  test('CON-07 · HU-30 · nombre vacío, correo inválido y contraseña de 7 → los tres en fields', async () => {
    const { store, register } = setup();

    const res = await register({ name: '   ', email: 'ana@mail', password: 'abc1234' });

    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: {
        name: MESSAGES.nameRequired,
        email: MESSAGES.emailInvalid,
        password: MESSAGES.passwordTooShort,
      },
    });
    expect(await store.findUserByEmail('ana@mail')).toBeNull();
  });

  test('CON-08 · HU-30 · contraseña sin números y otra de 73 → mensaje de cada regla', async () => {
    const { register } = setup();

    const sinNumeros = await register({ ...ana, password: 'abcdefgh' });
    const larga = await register({ ...ana, password: `a1${'x'.repeat(71)}` });

    expect(sinNumeros.status).toBe(400);
    expect(sinNumeros.body.fields).toEqual({ password: MESSAGES.passwordWeak });
    expect(larga.status).toBe(400);
    expect(larga.body.fields).toEqual({ password: MESSAGES.passwordTooLong });
  });

  test('CON-09 · HU-30 · el mismo correo con mayúsculas y espacios → 409 EMAIL_TAKEN', async () => {
    const { store, register } = setup();
    const primera = await register(ana);

    const res = await register({ ...ana, name: 'Otra Ana', email: '  ANA@Mail.COM ' });

    expect(primera.status).toBe(201);
    expect(res.status).toBe(409);
    expect(res.body).toEqual({
      error: 'Ya existe una cuenta con ese correo',
      code: 'EMAIL_TAKEN',
    });
    // No se creó otra cuenta ni se cambió la primera.
    expect(await store.findUserByEmail('ana@mail.com')).toMatchObject({
      id: primera.body.user.id,
      name: 'Ana López',
    });
  });

  test('REG-01 · HU-30 · el nombre se guarda sin espacios y el correo en minúsculas', async () => {
    const { store, register } = setup();

    const res = await register({ ...ana, name: '  Ana López  ', email: ' Ana@Mail.com ' });

    expect(res.status).toBe(201);
    expect(res.body.user).toMatchObject({ name: 'Ana López', email: 'ana@mail.com' });
    expect(await store.findUserByEmail('ana@mail.com')).not.toBeNull();
  });

  test('REG-02 · HU-30 · sin cuerpo o con un cuerpo que no es objeto → 400 con los tres campos', async () => {
    const { register } = setup();

    for (const body of [undefined, [], 'texto']) {
      const res = await register(body);
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('VALIDATION_FAILED');
      expect(Object.keys(res.body.fields).sort()).toEqual(['email', 'name', 'password']);
    }
  });

  test('REG-03 · HU-30 · campos que no son texto se tratan como vacíos', async () => {
    const { register } = setup();

    const res = await register({ name: 42, email: ['ana@mail.com'], password: 12345678 });

    expect(res.status).toBe(400);
    expect(res.body.fields).toEqual({
      name: MESSAGES.nameRequired,
      email: MESSAGES.emailInvalid,
      password: MESSAGES.passwordTooShort,
    });
  });

  test('REG-04 · HU-30 · el error de validación no repite los valores enviados', async () => {
    const { register } = setup();

    const res = await register({ name: '', email: 'secreto@', password: 'clave' });

    expect(res.status).toBe(400);
    expect(JSON.stringify(res.body)).not.toMatch(/secreto|clave/);
  });

  test('REG-05 · HU-30 · dos correos distintos crean dos cuentas con id distinto', async () => {
    const { register } = setup();

    const a = await register(ana);
    const b = await register({ ...ana, email: 'beto@mail.com' });

    expect(a.status).toBe(201);
    expect(b.status).toBe(201);
    expect(a.body.user.id).not.toBe(b.body.user.id);
  });

  test('REG-06 · HU-30 · si la capa de datos falla responde 500 sin detalles', async () => {
    const store = {
      kind: 'memory',
      ping: async () => true,
      createUser: async () => {
        throw new Error('postgres://usuario:clave@db sin conexión');
      },
    };
    const log = jest.spyOn(console, 'error').mockImplementation(() => {});

    const res = await request(createApp({ store })).post('/api/auth/register').send(ana);
    log.mockRestore();

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: 'Error interno del servidor', code: 'INTERNAL' });
  });
});

describe('validateRegistration', () => {
  test('REG-07 · HU-30 · límites de nombre, correo y contraseña', () => {
    const fieldsOf = (cambios) => validateRegistration({ ...ana, ...cambios }).fields;

    expect(fieldsOf({ name: 'A' })).toEqual({});
    expect(fieldsOf({ name: 'a'.repeat(80) })).toEqual({});
    expect(fieldsOf({ name: 'a'.repeat(81) })).toEqual({ name: MESSAGES.nameTooLong });

    const local = 'a'.repeat(64);
    const correo254 = `${local}@${'b'.repeat(185)}.com`;
    expect(correo254).toHaveLength(254);
    expect(fieldsOf({ email: correo254 })).toEqual({});
    expect(fieldsOf({ email: `a${correo254}` })).toEqual({ email: MESSAGES.emailInvalid });
    for (const email of ['', 'ana', 'ana@mail', '@mail.com', 'ana@@mail.com', 'a na@mail.com']) {
      expect(fieldsOf({ email })).toEqual({ email: MESSAGES.emailInvalid });
    }

    expect(fieldsOf({ password: 'abcdef12' })).toEqual({});
    expect(fieldsOf({ password: `a1${'x'.repeat(70)}` })).toEqual({});
    expect(fieldsOf({ password: '12345678' })).toEqual({ password: MESSAGES.passwordWeak });
    expect(fieldsOf({ password: 'ñandú2026' })).toEqual({});
  });

  test('REG-08 · HU-30 · la contraseña no se recorta y role no se copia', () => {
    const { value, fields } = validateRegistration({
      ...ana,
      password: '  abc12  ',
      role: 'accountant',
    });

    expect(fields).toEqual({});
    expect(value).toEqual({ name: 'Ana López', email: 'ana@mail.com', password: '  abc12  ' });
  });
});
