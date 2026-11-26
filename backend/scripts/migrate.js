'use strict';

/**
 * `npm run migrate`: aplica las migraciones pendientes en la base de
 * DATABASE_URL del ambiente actual (S3-05). Nunca muestra la cadena.
 */

const { Client } = require('pg');

const { loadConfig, loadEnvFile } = require('../src/config');
const { runMigrations } = require('../src/data/migrate');

async function main() {
  loadEnvFile();
  const config = loadConfig();
  const client = new Client({ connectionString: config.databaseUrl });
  await client.connect();
  try {
    const done = await runMigrations(client);
    if (done.length === 0) {
      console.log(`(${config.env}) Sin migraciones pendientes.`);
    } else {
      console.log(`(${config.env}) Migraciones aplicadas: ${done.join(', ')}`);
    }
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
