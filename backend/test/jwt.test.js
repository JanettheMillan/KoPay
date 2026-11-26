'use strict';

// S4-01 · Emisión y verificación de JWT (HU-31, HU-34).
// Casos nuevos JWT-01 a JWT-09. Criterio de la tarjeta: las rutas
// reconocen tokens válidos y rechazan tokens inválidos.

const { createHmac } = require('node:crypto');
const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { HEADER, signToken, verifyToken } = require('../src/services/jwt');

const SECRET = 'secreto-de-pruebas-de-32-caracteres-o-mas';
const OTHER = 'otro-secreto-de-pruebas-de-32-caracteres!!';
const t0 = new Date('2026-11-26T18:00:00.000Z');
const at = (seconds) => () => new Date(t0.getTime() + seconds * 1000);

const b64 = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const sign = (data, secret) => createHmac('sha256', secret).update(data).digest('base64url');

/** Arma un token a mano con [header] y [payload], firmado con [secret]. */
function forge(header, payload, secret = SECRET) {
  const data = `${b64(header)}.${b64(payload)}`;
  return `${data}.${sign(data, secret)}`;
}

describe('Firma y verificación', () => {
  test('JWT-01 · HU-31 · un token firmado se verifica y trae sub, jti, iat y exp', () => {
    const token = signToken({ subject: 'u-1', expiresIn: 900, secret: SECRET, now: at(0) });
    expect(token.split('.')).toHaveLength(3);
    const claims = verifyToken(token, { secret: SECRET, now: at(10) });
    expect(claims).toMatchObject({ sub: 'u-1', iat: t0.getTime() / 1000, exp: t0.getTime() / 1000 + 900 });
    expect(claims.jti).toEqual(expect.any(String));
  });

  test('JWT-02 · HU-34 · cambiar el contenido invalida la firma', () => {
    const token = signToken({ subject: 'u-1', expiresIn: 900, secret: SECRET, now: at(0) });
    const [h, , s] = token.split('.');
    const payload = { sub: 'u-2', jti: 'x', iat: 0, exp: 9999999999 };
    expect(verifyToken(`${h}.${b64(payload)}.${s}`, { secret: SECRET, now: at(1) })).toBeNull();
  });

  test('JWT-03 · HU-34 · un token firmado con otro secreto se rechaza', () => {
    const token = signToken({ subject: 'u-1', expiresIn: 900, secret: OTHER, now: at(0) });
    expect(verifyToken(token, { secret: SECRET, now: at(1) })).toBeNull();
  });

  test('JWT-04 · HU-31 · vence exactamente a los 900 segundos', () => {
    const token = signToken({ subject: 'u-1', expiresIn: 900, secret: SECRET, now: at(0) });
    expect(verifyToken(token, { secret: SECRET, now: at(899) })).not.toBeNull();
    expect(verifyToken(token, { secret: SECRET, now: at(900) })).toBeNull();
  });

  test('JWT-05 · HU-34 · alg none u otro algoritmo se rechazan', () => {
    const payload = { sub: 'u-1', jti: 'j', iat: 0, exp: 9999999999 };
    const none = `${b64({ alg: 'none', typ: 'JWT' })}.${b64(payload)}.`;
    expect(verifyToken(none, { secret: SECRET })).toBeNull();
    expect(verifyToken(forge({ alg: 'HS512', typ: 'JWT' }, payload), { secret: SECRET })).toBeNull();
    expect(verifyToken(forge(HEADER, payload), { secret: SECRET })).not.toBeNull();
  });

  test('JWT-06 · HU-34 · tokens mal formados devuelven null sin lanzar', () => {
    for (const bad of [undefined, null, 42, '', 'abc', 'a.b', 'a.b.c.d', 'a.b.c', '...', 'ñ.ñ.ñ']) {
      expect(verifyToken(bad, { secret: SECRET })).toBeNull();
    }
    // Contenido que no es un objeto o al que le faltan datos.
    expect(verifyToken(forge(HEADER, ['x']), { secret: SECRET })).toBeNull();
    expect(verifyToken(forge(HEADER, { sub: 'u', iat: 0, exp: 9999999999 }), { secret: SECRET })).toBeNull();
    expect(verifyToken(forge(HEADER, { sub: '', jti: 'j', iat: 0, exp: 9999999999 }), { secret: SECRET })).toBeNull();
  });

  test('JWT-07 · HU-31 · sin secreto no firma, y cada token es distinto', () => {
    expect(() => signToken({ subject: 'u-1', expiresIn: 900, secret: '' })).toThrow('JWT_SECRET');
    const a = signToken({ subject: 'u-1', expiresIn: 900, secret: SECRET, now: at(0) });
    const b = signToken({ subject: 'u-1', expiresIn: 900, secret: SECRET, now: at(0) });
    expect(a).not.toBe(b);
  });
});

describe('Rutas con sesión', () => {
  const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };
  let store;
  let now;
  let app;

  beforeEach(async () => {
    store = createMemoryStore();
    now = new Date(t0);
    app = createApp({ store, now: () => now });
    await request(app).post('/api/auth/register').send(ana);
  });

  const login = () => request(app).post('/api/auth/login').send(ana);
  const me = (token) => request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`);

  test('JWT-08 · HU-31 · CON-11 · el login entrega un JWT del usuario y /me lo reconoce', async () => {
    const res = await login();
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ tokenType: 'Bearer', expiresIn: 900 });
    const [header, payload] = res.body.accessToken.split('.');
    expect(JSON.parse(Buffer.from(header, 'base64url'))).toEqual(HEADER);
    expect(JSON.parse(Buffer.from(payload, 'base64url')).sub).toBe(res.body.user.id);
    // Lo que ve la app no cambia: el contrato no expone el secreto ni la contraseña.
    expect(res.text).not.toContain(ana.password);

    const who = await me(res.body.accessToken);
    expect(who.status).toBe(200);
    expect(who.body.user.email).toBe(ana.email);
  });

  test('JWT-09 · HU-34 · CON-14 · /me rechaza un JWT falso, de otro secreto o vencido', async () => {
    const { accessToken, user } = (await login()).body;

    // Bien firmado con otro secreto, para el mismo usuario.
    const otherSecret = signToken({ subject: user.id, expiresIn: 900, secret: OTHER, now: () => now });
    // Mismo encabezado y firma, pero con el contenido cambiado.
    const [h, , s] = accessToken.split('.');
    const swapped = `${h}.${b64({ sub: user.id, jti: 'x', iat: 0, exp: 9999999999 })}.${s}`;
    // Firmado con el secreto correcto pero sin sesión en la base.
    const noSession = signToken({
      subject: user.id,
      expiresIn: 900,
      secret: 'solo-pruebas-no-usar-en-produccion',
      now: () => now,
    });

    for (const token of [otherSecret, swapped, noSession]) {
      const res = await me(token);
      expect(res.status).toBe(401);
      expect(res.body.code).toBe('UNAUTHENTICATED');
    }

    now = new Date(t0.getTime() + 900 * 1000);
    expect((await me(accessToken)).status).toBe(401);
  });
});
