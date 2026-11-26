'use strict';

// S5-02 · Ingresos contra PostgreSQL (HU-02, HU-09, HU-34).
// DB-10 revisa las restricciones de la tabla y E2E-06 recorre la API con
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

test('DB-10 · HU-02 · la tabla incomes rechaza montos no positivos, nombres vacíos y notas largas', async () => {
  const { rows } = await client.query(
    `INSERT INTO users (name, email, password_hash) VALUES ('Ana', 'ana@db.com', $1) RETURNING id`,
    ['$2b$12$abcdefghijklmnopqrstuuJr0mK8m3pU3nH6bZyX9q2a1b3c4d5e6'],
  );
  const user = rows[0].id;
  const insert = (cols) =>
    errorCode(
      'INSERT INTO incomes (user_id, name, amount, date, note) VALUES ($1, $2, $3, now(), $4)',
      [user, cols.name ?? 'Nómina', cols.amount ?? 100, cols.note ?? null],
    );

  expect(await insert({})).toBeNull();
  expect(await insert({ amount: 0 })).toBe('23514');
  expect(await insert({ amount: -5 })).toBe('23514');
  expect(await insert({ amount: 1000000000 })).toBe('23514');
  expect(await insert({ amount: 999999999.99 })).toBeNull();
  expect(await insert({ name: '' })).toBe('23514');
  expect(await insert({ name: ' Nómina' })).toBe('23514');
  expect(await insert({ name: 'x'.repeat(61) })).toBe('23514');
  expect(await insert({ note: 'x'.repeat(141) })).toBe('23514');

  // Borrar la cuenta borra sus ingresos.
  await client.query('DELETE FROM users WHERE id = $1', [user]);
  const left = await client.query('SELECT count(*)::int AS n FROM incomes WHERE user_id = $1', [user]);
  expect(left.rows[0].n).toBe(0);
});

test('E2E-06 · HU-02 · HU-09 · HU-34 · CRUD de ingresos con PostgreSQL', async () => {
  const api = request(createApp({ config, store }));
  const tokens = {};
  for (const [who, email] of [['ana', 'ana@inc.com'], ['beto', 'beto@inc.com']]) {
    await api.post('/api/auth/register').send({ name: who, email, password: 'kopay2026' }).expect(201);
    tokens[who] = `Bearer ${(await api.post('/api/auth/login').send({ email, password: 'kopay2026' })).body.accessToken}`;
  }
  const as = (who) => ({
    create: (b) => api.post('/api/incomes').set('Authorization', tokens[who]).send(b),
    list: (q = '') => api.get(`/api/incomes${q}`).set('Authorization', tokens[who]),
    get: (id) => api.get(`/api/incomes/${id}`).set('Authorization', tokens[who]),
    update: (id, b) => api.put(`/api/incomes/${id}`).set('Authorization', tokens[who]).send(b),
    remove: (id) => api.delete(`/api/incomes/${id}`).set('Authorization', tokens[who]),
  });

  const created = await as('ana').create({ name: 'Nómina', amount: 12500.75, date: '2026-11-15' });
  expect(created.status).toBe(201);
  const { id } = created.body.income;
  expect(created.body.income).toMatchObject({ amount: 12500.75, version: 1, date: '2026-11-15T00:00:00.000Z' });
  await as('ana').create({ name: 'Venta', amount: 800, date: '2026-10-02' });

  expect((await as('ana').list('?month=2026-11')).body.incomes.map((i) => i.name)).toEqual(['Nómina']);
  expect((await as('ana').list()).body.incomes).toHaveLength(2);

  // DB-04: la cuenta B no ve ni toca el ingreso de A; un id mal formado es 404.
  expect((await as('beto').list()).body.incomes).toEqual([]);
  expect((await as('beto').get(id)).status).toBe(404);
  expect((await as('beto').get('no-es-uuid')).status).toBe(404);
  expect((await as('beto').remove(id)).status).toBe(404);

  const edited = await as('ana').update(id, { name: 'Nómina', amount: 13000, date: '2026-12-15', version: 1 });
  expect(edited.body.income).toMatchObject({ amount: 13000, version: 2 });
  expect((await as('ana').list('?month=2026-11')).body.incomes).toEqual([]);
  expect((await as('ana').update(id, { name: 'x', amount: 1, date: '2026-11-26', version: 1 })).status).toBe(409);

  expect((await as('ana').remove(id)).status).toBe(204);
  const { rows } = await client.query('SELECT count(*)::int AS n FROM incomes WHERE id = $1', [id]);
  expect(rows[0].n).toBe(0);
});
