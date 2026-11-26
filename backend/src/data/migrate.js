'use strict';

const fs = require('node:fs');
const path = require('node:path');

/**
 * Migraciones de PostgreSQL (S3-05). Reglas en docs/base-de-datos.md §4:
 *
 * - Archivos `NNN_nombre.sql` en `backend/migrations/`, aplicados en
 *   orden de número.
 * - Cada una en su propia transacción. Si falla, se deshace completa y
 *   no se aplican las siguientes.
 * - El número aplicado se anota en `schema_migrations`; correr otra vez
 *   no repite nada.
 */

const MIGRATIONS_DIR = path.join(__dirname, '..', '..', 'migrations');
const FILE_PATTERN = /^(\d{3})_[a-z0-9_]+\.sql$/;

/** Número fijo para que dos `migrate` a la vez no se pisen. */
const LOCK_ID = 20261126;

/**
 * Lee las migraciones de [dir] en orden. Lanza un error si un archivo
 * `.sql` no sigue el formato o si dos comparten número.
 */
function listMigrations(dir = MIGRATIONS_DIR) {
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .sort();
  const seen = new Set();
  return files.map((file) => {
    const match = FILE_PATTERN.exec(file);
    if (!match) {
      throw new Error(
        `Migración con nombre inválido: "${file}". Usa NNN_nombre.sql.`,
      );
    }
    const version = match[1];
    if (seen.has(version)) {
      throw new Error(`Dos migraciones con el número ${version}.`);
    }
    seen.add(version);
    return {
      version,
      name: file,
      sql: fs.readFileSync(path.join(dir, file), 'utf8'),
    };
  });
}

/**
 * Aplica las migraciones pendientes con [client] (un `pg.Client` o un
 * cliente tomado de un `pg.Pool`, ya conectado). Devuelve los nombres
 * que aplicó; vacío si ya estaba todo.
 */
async function runMigrations(client, { migrations = listMigrations() } = {}) {
  await client.query('SELECT pg_advisory_lock($1)', [LOCK_ID]);
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version    text        PRIMARY KEY,
        name       text        NOT NULL,
        applied_at timestamptz NOT NULL DEFAULT now()
      )`);
    const { rows } = await client.query('SELECT version FROM schema_migrations');
    const applied = new Set(rows.map((r) => r.version));

    const done = [];
    for (const m of migrations) {
      if (applied.has(m.version)) continue;
      await client.query('BEGIN');
      try {
        await client.query(m.sql);
        await client.query(
          'INSERT INTO schema_migrations (version, name) VALUES ($1, $2)',
          [m.version, m.name],
        );
        await client.query('COMMIT');
      } catch (err) {
        await client.query('ROLLBACK');
        throw new Error(`La migración ${m.name} falló y se deshizo: ${err.message}`);
      }
      done.push(m.name);
    }
    return done;
  } finally {
    await client.query('SELECT pg_advisory_unlock($1)', [LOCK_ID]);
  }
}

module.exports = { MIGRATIONS_DIR, listMigrations, runMigrations };
