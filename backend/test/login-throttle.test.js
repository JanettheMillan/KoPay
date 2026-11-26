'use strict';

// S4-13 · Revisar seguridad de sesiones y permisos (HU-31, HU-34).
// Hallazgo SEG-H1 de docs/revision-seguridad-s4-13.md: el login no
// limitaba los intentos fallidos. Casos nuevos SEG-01 a SEG-07.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const {
  INVALID_CREDENTIALS_MESSAGE,
  LOGIN_TOO_MANY_MESSAGE,
} = require('../src/services/auth.service');
const {
  MAX_FAILURES,
  WINDOW_SECONDS,
  createLoginThrottle,
} = require('../src/services/login-throttle');

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };
const demasiados = { error: LOGIN_TOO_MANY_MESSAGE, code: 'TOO_MANY_ATTEMPTS' };

async function setup() {
  let ahora = new Date('2026-11-26T18:00:00.000Z');
  const store = createMemoryStore({ now: () => ahora });
  const api = request(createApp({ store, now: () => ahora }));
  await api.post('/api/auth/register').send(ana).expect(201);
  return {
    login: (body) => api.post('/api/auth/login').send(body),
    adelantar: (segundos) => {
      ahora = new Date(ahora.getTime() + segundos * 1000);
    },
  };
}

async function fallar(login, email, veces) {
  for (let i = 0; i < veces; i += 1) {
    const res = await login({ email, password: `mala-${i}` });
    expect(res.status).toBe(401);
    expect(res.body.error).toBe(INVALID_CREDENTIALS_MESSAGE);
  }
}

describe('Límite de intentos del login (S4-13)', () => {
  test(`SEG-01 · HU-31 · después de ${MAX_FAILURES} fallos responde 429, aun con la contraseña correcta`, async () => {
    const { login } = await setup();
    await fallar(login, ana.email, MAX_FAILURES);

    const res = await login({ email: ana.email, password: ana.password });
    expect(res.status).toBe(429);
    expect(res.body).toEqual(demasiados);
    expect(res.body).not.toHaveProperty('accessToken');
  });

  test('SEG-02 · HU-31 · el correo se normaliza: mayúsculas y espacios cuentan como el mismo', async () => {
    const { login } = await setup();
    await fallar(login, '  ANA@Mail.com ', MAX_FAILURES);
    expect((await login({ email: ana.email, password: ana.password })).status).toBe(429);
  });

  test('SEG-03 · HU-31 · un correo sin cuenta recibe lo mismo: el 429 no revela qué correos existen', async () => {
    const { login } = await setup();
    await fallar(login, 'nadie@mail.com', MAX_FAILURES);
    const res = await login({ email: 'nadie@mail.com', password: 'otra' });
    expect(res.status).toBe(429);
    expect(res.body).toEqual(demasiados);
  });

  test('SEG-04 · HU-31 · un login correcto reinicia el contador', async () => {
    const { login } = await setup();
    await fallar(login, ana.email, MAX_FAILURES - 1);
    expect((await login({ email: ana.email, password: ana.password })).status).toBe(200);
    await fallar(login, ana.email, MAX_FAILURES - 1);
    expect((await login({ email: ana.email, password: ana.password })).status).toBe(200);
  });

  test('SEG-05 · HU-31 · al pasar la ventana se puede volver a entrar', async () => {
    const { login, adelantar } = await setup();
    await fallar(login, ana.email, MAX_FAILURES);
    adelantar(WINDOW_SECONDS - 1);
    expect((await login({ email: ana.email, password: ana.password })).status).toBe(429);
    adelantar(1);
    expect((await login({ email: ana.email, password: ana.password })).status).toBe(200);
  });

  test('SEG-06 · HU-34 · un bloqueo no afecta a otra cuenta', async () => {
    const { login } = await setup();
    await fallar(login, 'otra@mail.com', MAX_FAILURES);
    expect((await login({ email: ana.email, password: ana.password })).status).toBe(200);
  });

  test('SEG-07 · HU-31 · en paralelo no se compara la contraseña más veces que el máximo', async () => {
    const { login } = await setup();
    const res = await Promise.all(
      Array.from({ length: 40 }, (_, i) => login({ email: ana.email, password: `mala-${i}` })),
    );
    const cuenta = (status) => res.filter((r) => r.status === status).length;
    expect(cuenta(401)).toBe(MAX_FAILURES);
    expect(cuenta(429)).toBe(40 - MAX_FAILURES);
  });

  test('SEG-07b · el contador en memoria no crece sin fin con muchos correos distintos', () => {
    const throttle = createLoginThrottle({ maxTracked: 100 });
    for (let i = 0; i < 1000; i += 1) throttle.claim(`c${i}@mail.com`);
    expect(throttle.size).toBeLessThanOrEqual(100);
  });
});
