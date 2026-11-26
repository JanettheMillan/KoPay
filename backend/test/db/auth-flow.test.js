'use strict';

// S4-01 · Registro, login y sesión de punta a punta sobre PostgreSQL
// (HU-30, HU-31, HU-34). Comprueba que la cuenta y la sesión siguen
// después de "reiniciar" la API, que es lo que pasa con server.js ahora
// que usa createPgStore.
//
//   DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/kopay_test npm run test:db
//
// ATENCIÓN: borra el esquema `public` de esa base, como migrations.test.js.

const { Client } = require('pg');
const request = require('supertest');

const { createApp } = require('../../src/app');
const { loadConfig } = require('../../src/config');
const { runMigrations } = require('../../src/data/migrate');
const { createPgStore } = require('../../src/data/pg-store');

const config = loadConfig({ ...process.env, NODE_ENV: 'test' });
const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };

let client;
const stores = [];

/** Una API nueva con su propio pool, como al arrancar el servidor. */
function boot() {
  const store = createPgStore({ databaseUrl: config.databaseUrl });
  stores.push(store);
  return request(createApp({ config, store }));
}

beforeAll(async () => {
  client = new Client({ connectionString: config.databaseUrl });
  await client.connect();
  const { rows } = await client.query('SELECT current_database() AS db');
  if (!/test/.test(rows[0].db)) {
    throw new Error(`La base "${rows[0].db}" no parece de pruebas; se detiene.`);
  }
  await client.query('DROP SCHEMA public CASCADE');
  await client.query('CREATE SCHEMA public');
  await runMigrations(client);
});

afterAll(async () => {
  await Promise.all(stores.map((s) => s.close()));
  await client?.end();
});

test('E2E-01 · HU-30 · HU-31 · la cuenta y la sesión sobreviven a un reinicio', async () => {
  const first = boot();
  expect((await first.post('/api/auth/register').send(ana)).status).toBe(201);
  const login = await first.post('/api/auth/login').send(ana);
  expect(login.status).toBe(200);
  const { accessToken } = login.body;

  // "Reinicio": otra app y otro pool sobre la misma base.
  const second = boot();
  const me = await second.get('/api/auth/me').set('Authorization', `Bearer ${accessToken}`);
  expect(me.status).toBe(200);
  expect(me.body.user).toMatchObject({ email: ana.email, role: 'user' });
  expect((await second.post('/api/auth/login').send(ana)).status).toBe(200);
  expect((await second.post('/api/auth/register').send(ana)).body.code).toBe('EMAIL_TAKEN');
});

test('E2E-02 · HU-34 · en la base no hay contraseña ni token en claro', async () => {
  const { rows: users } = await client.query('SELECT * FROM users');
  expect(JSON.stringify(users)).not.toContain(ana.password);
  const { rows: sessions } = await client.query('SELECT token_hash FROM sessions');
  expect(sessions.length).toBeGreaterThanOrEqual(2);
  for (const s of sessions) expect(s.token_hash).toMatch(/^[0-9a-f]{64}$/);
});

test('E2E-03 · HU-34 · un token alterado se rechaza también contra la base', async () => {
  const api = boot();
  const { accessToken } = (await api.post('/api/auth/login').send(ana)).body;
  const altered = `${accessToken.slice(0, -2)}${accessToken.endsWith('AA') ? 'BB' : 'AA'}`;
  const res = await api.get('/api/auth/me').set('Authorization', `Bearer ${altered}`);
  expect(res.status).toBe(401);
});

test('E2E-04 · HU-31 · HU-33 · renovar y cerrar sesión contra PostgreSQL (S4-02)', async () => {
  const api = boot();
  const first = (await api.post('/api/auth/login').send(ana)).body;
  expect(first.refreshToken).toEqual(expect.any(String));

  const renewed = await api.post('/api/auth/refresh').send({ refreshToken: first.refreshToken });
  expect(renewed.status).toBe(200);
  expect((await api.post('/api/auth/refresh').send({ refreshToken: first.refreshToken })).status).toBe(401);

  const { accessToken } = renewed.body;
  expect((await api.get('/api/auth/me').set('Authorization', `Bearer ${accessToken}`)).status).toBe(200);
  expect((await api.post('/api/auth/logout').set('Authorization', `Bearer ${accessToken}`)).status).toBe(204);
  expect((await api.get('/api/auth/me').set('Authorization', `Bearer ${accessToken}`)).status).toBe(401);
  expect((await api.post('/api/auth/refresh').send({ refreshToken: renewed.body.refreshToken })).status).toBe(401);

  const { rows } = await client.query(
    'SELECT refresh_token_hash FROM sessions WHERE refresh_token_hash IS NOT NULL',
  );
  for (const r of rows) expect(r.refresh_token_hash).toMatch(/^[0-9a-f]{64}$/);
});
