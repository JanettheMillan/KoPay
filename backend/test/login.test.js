// S3-09 · Inicio de sesión y sesión actual (HU-31).
//
// CON-11 a CON-14 son los casos de docs/contrato-api-acceso.md
// (sección 5). LOG-01 a LOG-09 son pruebas nuevas de esta tarjeta,
// anotadas en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { ACCESS_TOKEN_TTL_SECONDS, hashToken } = require('../src/services/session.service');
const { MESSAGES } = require('../src/validators/auth.validator');

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };
const credencialesMalas = { error: 'Correo o contraseña incorrectos', code: 'INVALID_CREDENTIALS' };
const sinSesion = { error: 'Inicia sesión para continuar', code: 'UNAUTHENTICATED' };

/** App con su almacén y un reloj que las pruebas pueden adelantar. */
async function setup({ registrar = true } = {}) {
  let ahora = new Date('2026-11-26T18:00:00.000Z');
  const store = createMemoryStore({ now: () => ahora });
  const app = createApp({ store, now: () => ahora });
  const api = request(app);
  if (registrar) await api.post('/api/auth/register').send(ana).expect(201);
  return {
    store,
    login: (body) => api.post('/api/auth/login').send(body),
    me: (authorization) => {
      const req = api.get('/api/auth/me');
      return authorization === undefined ? req : req.set('Authorization', authorization);
    },
    adelantar: (segundos) => {
      ahora = new Date(ahora.getTime() + segundos * 1000);
    },
  };
}

describe('POST /api/auth/login', () => {
  test('CON-11 · HU-31 · credenciales correctas → 200 con accessToken, tokenType, expiresIn y user', async () => {
    const { login } = await setup();

    const res = await login({ email: 'ana@mail.com', password: 'kopay2026' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      accessToken: expect.any(String),
      tokenType: 'Bearer',
      expiresIn: 900,
      // S4-02 agrega la renovación (contrato §3.2 y §3.5).
      refreshToken: expect.any(String),
      refreshExpiresIn: 2592000,
      user: {
        id: expect.any(String),
        name: 'Ana López',
        email: 'ana@mail.com',
        role: 'user',
        createdAt: expect.any(String),
      },
    });
    expect(res.body.accessToken.length).toBeGreaterThanOrEqual(32);
    expect(JSON.stringify(res.body)).not.toMatch(/kopay2026|password|scrypt/i);
  });

  test('CON-12 · HU-31 · correo inexistente y contraseña incorrecta → el mismo 401', async () => {
    const { login } = await setup();

    const noExiste = await login({ email: 'nadie@mail.com', password: 'kopay2026' });
    const malaClave = await login({ email: 'ana@mail.com', password: 'kopay2027' });

    expect(noExiste.status).toBe(401);
    expect(malaClave.status).toBe(401);
    expect(noExiste.body).toEqual(credencialesMalas);
    expect(malaClave.body).toEqual(noExiste.body);
  });

  test('CON-13 · HU-31 · login sin password → 400 VALIDATION_FAILED con fields.password', async () => {
    const { login } = await setup();

    const res = await login({ email: 'ana@mail.com' });

    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: { password: MESSAGES.loginPasswordRequired },
    });
  });

  test('LOG-01 · HU-31 · sin cuerpo, o con campos que no son texto → 400 con los dos campos', async () => {
    const { login } = await setup();

    for (const body of [undefined, [], { email: 42, password: true }, { email: '  ', password: '' }]) {
      const res = await login(body);
      expect(res.status).toBe(400);
      expect(res.body.fields).toEqual({
        email: MESSAGES.loginEmailRequired,
        password: MESSAGES.loginPasswordRequired,
      });
    }
  });

  test('LOG-02 · HU-31 · el correo no distingue mayúsculas ni espacios; la contraseña sí', async () => {
    const { login } = await setup();

    const ok = await login({ email: '  ANA@Mail.com ', password: 'kopay2026' });
    const mayus = await login({ email: 'ana@mail.com', password: 'KOPAY2026' });

    expect(ok.status).toBe(200);
    expect(mayus.status).toBe(401);
  });

  test('LOG-03 · HU-31 · en el login no se revisan las reglas del registro', async () => {
    const { login } = await setup();

    // Contraseña corta: no es 400 por longitud, solo no coincide.
    const res = await login({ email: 'ana@mail.com', password: 'abc' });

    expect(res.status).toBe(401);
    expect(res.body).toEqual(credencialesMalas);
  });

  test('LOG-04 · HU-31 · solo se guarda el hash del token, no el token', async () => {
    const { store, login } = await setup();

    const { accessToken } = (await login(ana)).body;
    const sesion = await store.findSessionByTokenHash(hashToken(accessToken));

    expect(sesion).toMatchObject({ userId: expect.any(String), revokedAt: null });
    expect(sesion.tokenHash).not.toBe(accessToken);
    expect(JSON.stringify(sesion)).not.toContain(accessToken);
    expect(await store.findSessionByTokenHash(accessToken)).toBeNull();
  });

  test('LOG-05 · HU-31 · dos logins abren dos sesiones con tokens distintos y válidos', async () => {
    const { login, me } = await setup();

    const a = (await login(ana)).body.accessToken;
    const b = (await login(ana)).body.accessToken;

    expect(a).not.toBe(b);
    expect((await me(`Bearer ${a}`)).status).toBe(200);
    expect((await me(`Bearer ${b}`)).status).toBe(200);
  });
});

describe('GET /api/auth/me', () => {
  test('CON-14 · HU-31 · token válido → 200; sin token → 401; token alterado → 401', async () => {
    const { login, me } = await setup();
    const { accessToken, user } = (await login(ana)).body;
    const alterado = `${accessToken.slice(0, -1)}${accessToken.endsWith('A') ? 'B' : 'A'}`;

    const valido = await me(`Bearer ${accessToken}`);
    const sinToken = await me();
    const malo = await me(`Bearer ${alterado}`);

    expect(valido.status).toBe(200);
    expect(valido.body).toEqual({ user });
    expect(sinToken.status).toBe(401);
    expect(sinToken.body).toEqual(sinSesion);
    expect(malo.status).toBe(401);
    expect(malo.body).toEqual(sinSesion);
  });

  test('LOG-06 · HU-31 · el token vence a los 900 segundos', async () => {
    const { login, me, adelantar } = await setup();
    const { accessToken } = (await login(ana)).body;

    adelantar(ACCESS_TOKEN_TTL_SECONDS - 1);
    expect((await me(`Bearer ${accessToken}`)).status).toBe(200);

    adelantar(1);
    const vencido = await me(`Bearer ${accessToken}`);
    expect(vencido.status).toBe(401);
    expect(vencido.body).toEqual(sinSesion);
  });

  test('LOG-07 · HU-31 · encabezados mal formados → 401', async () => {
    const { login, me } = await setup();
    const { accessToken } = (await login(ana)).body;

    for (const header of ['', 'Bearer', 'Bearer ', accessToken, `Basic ${accessToken}`, `Bearer ${accessToken} extra`]) {
      const res = await me(header);
      expect(res.status).toBe(401);
      expect(res.body.code).toBe('UNAUTHENTICATED');
    }
    // El esquema no distingue mayúsculas.
    expect((await me(`bearer ${accessToken}`)).status).toBe(200);
  });

  test('LOG-08 · HU-31 · una sesión revocada ya no sirve', async () => {
    const { store, login, me } = await setup();
    const { accessToken } = (await login(ana)).body;

    // S4-02 llenará revoked_at al cerrar sesión; aquí se simula.
    const original = store.findSessionByTokenHash;
    store.findSessionByTokenHash = async (h) => {
      const s = await original(h);
      return s && { ...s, revokedAt: '2026-11-26T18:05:00.000Z' };
    };

    expect((await me(`Bearer ${accessToken}`)).status).toBe(401);
  });

  test('LOG-09 · HU-31 · si la cuenta ya no existe, la sesión responde 401', async () => {
    const { store, login, me } = await setup();
    const { accessToken } = (await login(ana)).body;
    store.findUserById = async () => null;

    const res = await me(`Bearer ${accessToken}`);

    expect(res.status).toBe(401);
    expect(res.body).toEqual(sinSesion);
  });
});
