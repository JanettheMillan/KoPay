'use strict';

// S5-01 · Movimientos contra PostgreSQL (HU-01, HU-05, HU-06, HU-34).
// DB-09 revisa las restricciones de la tabla y E2E-05 recorre la API con
// la base real, incluido DB-04 (aislamiento).
//
//   DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/kopay_test npm run test:db

const { Client } = require('pg');
const request = require('supertest');

const { createApp } = require('../../src/app');
const { loadConfig } = require('../../src/config');
const { runMigrations } = require('../../src/data/migrate');
const { createPgStore } = require('../../src/data/pg-store');

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

async function errorCode(sql, params) {
  try {
    await client.query(sql, params);
    return null;
  } catch (err) {
    return err.code;
  }
}

test('DB-09 · HU-04 · la tabla movements rechaza monto cero, textos vacíos, tipo inválido y pagos con dos ligas', async () => {
  const { rows } = await client.query(
    `INSERT INTO users (name, email, password_hash) VALUES ('Ana', 'ana@db.com', $1) RETURNING id`,
    ['$2b$12$abcdefghijklmnopqrstuuJr0mK8m3pU3nH6bZyX9q2a1b3c4d5e6'],
  );
  const user = rows[0].id;
  const insert = (cols) =>
    errorCode(
      `INSERT INTO movements (user_id, amount, description, category, date, type, card_id, debt_id)
       VALUES ($1, $2, $3, $4, now(), $5, $6, $7)`,
      [user, cols.amount ?? -10, cols.description ?? 'Café', cols.category ?? 'Comida',
        cols.type ?? 'regular', cols.card ?? null, cols.debt ?? null],
    );
  const u = '00000000-0000-0000-0000-000000000001';

  expect(await insert({})).toBeNull();
  expect(await insert({ amount: 0 })).toBe('23514');
  expect(await insert({ description: '' })).toBe('23514');
  expect(await insert({ category: ' x' })).toBe('23514');
  expect(await insert({ type: 'otro' })).toBe('23514');
  expect(await insert({ card: u })).toBe('23514'); // regular con tarjeta
  expect(await insert({ type: 'payment', card: u, debt: u })).toBe('23514');
  expect(await insert({ type: 'payment', card: u })).toBeNull();
  expect(await insert({ type: 'payment' })).toBeNull(); // pago desligado (S2-15)
  // Cabe en numeric(14,2), pero pasa del máximo de la app: lo detiene el CHECK.
  expect(await insert({ amount: 1000000000 })).toBe('23514');
  expect(await insert({ amount: 999999999.99 })).toBeNull();
});

test('E2E-05 · HU-01 · HU-05 · HU-06 · HU-34 · CRUD de movimientos con PostgreSQL', async () => {
  const api = request(createApp({ config, store }));
  const tokens = {};
  for (const [who, email] of [['ana', 'ana@e2e.com'], ['beto', 'beto@e2e.com']]) {
    await api.post('/api/auth/register').send({ name: who, email, password: 'kopay2026' }).expect(201);
    tokens[who] = `Bearer ${(await api.post('/api/auth/login').send({ email, password: 'kopay2026' })).body.accessToken}`;
  }
  const as = (who) => ({
    create: (b) => api.post('/api/movements').set('Authorization', tokens[who]).send(b),
    list: (q = '') => api.get(`/api/movements${q}`).set('Authorization', tokens[who]),
    get: (id) => api.get(`/api/movements/${id}`).set('Authorization', tokens[who]),
    update: (id, b) => api.put(`/api/movements/${id}`).set('Authorization', tokens[who]).send(b),
    remove: (id) => api.delete(`/api/movements/${id}`).set('Authorization', tokens[who]),
  });

  const created = await as('ana').create({ amount: -150.55, description: 'Súper', category: 'Comida', date: '2026-11-26' });
  expect(created.status).toBe(201);
  const { id } = created.body.movement;
  expect(created.body.movement).toMatchObject({ amount: -150.55, version: 1, date: '2026-11-26T00:00:00.000Z' });
  await as('ana').create({ amount: 500, description: 'Venta', category: 'Otros', date: '2026-10-02' });

  expect((await as('ana').list('?month=2026-11')).body.movements.map((m) => m.description)).toEqual(['Súper']);
  expect((await as('ana').list()).body.movements).toHaveLength(2);

  // DB-04: la cuenta B no ve ni toca el movimiento de A; un id mal formado es 404.
  expect((await as('beto').list()).body.movements).toEqual([]);
  expect((await as('beto').get(id)).status).toBe(404);
  expect((await as('beto').get('no-es-uuid')).status).toBe(404);
  expect((await as('beto').remove(id)).status).toBe(404);

  const edited = await as('ana').update(id, { amount: -160, description: 'Súper', category: 'Comida', date: '2026-11-26', version: 1 });
  expect(edited.body.movement).toMatchObject({ amount: -160, version: 2 });
  expect((await as('ana').update(id, { amount: -1, description: 'x', category: 'y', date: '2026-11-26', version: 1 })).status).toBe(409);

  expect((await as('ana').remove(id)).status).toBe(204);
  const { rows } = await client.query('SELECT count(*)::int AS n FROM movements WHERE id = $1', [id]);
  expect(rows[0].n).toBe(0);
});
