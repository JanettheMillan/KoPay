// S4-17 · Roles y aislamiento entre cuentas sobre PostgreSQL, que es lo
// que usa server.js (HU-34, HU-37 a HU-39, HU-41). Son los mismos casos
// que en memoria, para comprobar que las consultas SQL aíslan igual.
//
//   DATABASE_URL=postgres://USUARIO:CLAVE@localhost:5432/kopay_test npm run test:db
//
// ATENCIÓN: borra el esquema `public` de esa base, como migrations.test.js.

const { Client } = require('pg');

const { createApp } = require('../../src/app');
const { loadConfig } = require('../../src/config');
const { runMigrations } = require('../../src/data/migrate');
const { createPgStore } = require('../../src/data/pg-store');
const { definirCasosDeAislamiento } = require('../helpers/rbac-isolation-cases');

const config = loadConfig({ ...process.env, NODE_ENV: 'test' });
let client;
let store;

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
  store = createPgStore({ databaseUrl: config.databaseUrl });
});

afterAll(async () => {
  await store?.close();
  await client?.end();
});

describe('Roles y aislamiento · PostgreSQL', () => {
  definirCasosDeAislamiento(async () => {
    await client.query('TRUNCATE users CASCADE');
    return { app: createApp({ config, store }), store };
  });
});
