'use strict';

// S5-03 · Consulta del contador contra PostgreSQL (HU-39, HU-40, HU-41).
// E2E-07 recorre permiso, resumen, movimientos y revocación con la base
// real, con un pago guardado en `movements` (type = payment).
//
//   DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/kopay_test npm run test:db

const { Client } = require('pg');
const request = require('supertest');

const { createApp } = require('../../src/app');
const { loadConfig } = require('../../src/config');
const { runMigrations } = require('../../src/data/migrate');
const { createPgStore } = require('../../src/data/pg-store');
const { hashPassword } = require('../../src/services/password.service');

const config = loadConfig({ ...process.env, NODE_ENV: 'test' });
let client;
let store;

beforeAll(async () => {
  client = new Client({ connectionString: config.databaseUrl });
  await client.connect();
  const { rows } = await client.query('SELECT current_database() AS db');
  if (!/test/.test(rows[0].db)) throw new Error(`"${rows[0].db}" no parece de pruebas.`);
  await client.query('DROP SCHEMA public CASCADE');
  await client.query('CREATE SCHEMA public');
  await runMigrations(client);
  store = createPgStore({ databaseUrl: config.databaseUrl });
});

afterAll(async () => {
  await store?.close();
  await client?.end();
});

test('E2E-07 · HU-39 · HU-40 · HU-41 · el contador consulta el mes de quien lo autorizó, con PostgreSQL', async () => {
  const api = request(createApp({ config, store }));
  const clave = 'kopay2026';
  const tokens = {};
  for (const [who, email] of [['ana', 'ana@fic.com'], ['beto', 'beto@fic.com']]) {
    await api.post('/api/auth/register').send({ name: who, email, password: clave }).expect(201);
  }
  await store.createUser({
    name: 'Carla',
    email: 'carla@fic.mx',
    passwordHash: await hashPassword(clave),
    role: 'accountant',
  });
  for (const [who, email] of [['ana', 'ana@fic.com'], ['beto', 'beto@fic.com'], ['carla', 'carla@fic.mx']]) {
    tokens[who] = `Bearer ${(await api.post('/api/auth/login').send({ email, password: clave })).body.accessToken}`;
  }
  const as = (who) => ({
    get: (path) => api.get(path).set('Authorization', tokens[who]),
    post: (path, body) => api.post(path).set('Authorization', tokens[who]).send(body),
    del: (path) => api.delete(path).set('Authorization', tokens[who]),
  });
  const ana = await store.findUserByEmail('ana@fic.com');
  const beto = await store.findUserByEmail('beto@fic.com');

  await as('ana').post('/api/incomes', { name: 'Nómina', amount: 15000.1, date: '2026-11-01' }).expect(201);
  await as('ana').post('/api/movements', { amount: -1820.5, description: 'Súper', category: 'Comida', date: '2026-11-04' }).expect(201);
  await as('ana').post('/api/movements', { amount: -320, description: 'Cine', category: 'Ocio', date: '2026-10-14' }).expect(201);
  // Pago desligado, como los deja S2-15; S5-05 los creará desde su tarjeta.
  await client.query(
    `INSERT INTO movements (user_id, amount, description, category, date, type)
     VALUES ($1, -2000.2, 'Pago tarjeta', 'Pago', '2026-11-08', 'payment')`,
    [ana.id],
  );
  await as('beto').post('/api/movements', { amount: -999, description: 'Secreto', category: 'Otros', date: '2026-11-03' }).expect(201);

  // Sin permiso: 403 igual que con un id inexistente.
  expect((await as('carla').get(`/api/clients/${ana.id}/summary?month=2026-11`)).status).toBe(403);
  const grant = (await as('ana').post('/api/accountants', { accountantEmail: 'carla@fic.mx' }).expect(201)).body.grant;

  const summary = await as('carla').get(`/api/clients/${ana.id}/summary?month=2026-11`);
  expect(summary.status).toBe(200);
  expect(summary.body).toEqual({
    month: '2026-11',
    income: 15000.1,
    expenses: 1820.5,
    payments: 2000.2,
    balance: 11179.4,
  });

  const lista = await as('carla').get(`/api/clients/${ana.id}/movements?month=2026-11`);
  expect(lista.body.movements.map((m) => [m.description, m.type])).toEqual([
    ['Pago tarjeta', 'payment'],
    ['Súper', 'regular'],
  ]);
  expect(lista.body.incomes.map((i) => i.name)).toEqual(['Nómina']);
  expect((await as('carla').get(`/api/clients/${beto.id}/movements?month=2026-11`)).status).toBe(403);

  await as('ana').del(`/api/accountants/${grant.id}`).expect(204);
  expect((await as('carla').get(`/api/clients/${ana.id}/movements?month=2026-11`)).status).toBe(403);
});
