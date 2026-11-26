'use strict';

const { Pool } = require('pg');

/**
 * Capa de datos sobre PostgreSQL (S3-05). Tiene la misma interfaz que
 * `createMemoryStore`: `ping()`, así que la ruta de salud responde 503 si
 * la base no contesta (caso DB-05), y `createUser` y `findUserByEmail`
 * sobre la tabla `users`.
 *
 * Diferencia con la memoria: aquí se guarda `passwordHash`, nunca la
 * contraseña. El servidor cambia a esta capa cuando S3-08 genere el hash.
 *
 * Valores del pool acordados en docs/base-de-datos.md §2. La conexión
 * se abre al primer uso: el servidor arranca aunque la base no esté.
 */
const POOL_OPTIONS = Object.freeze({
  max: 5,
  idleTimeoutMillis: 10_000,
  connectionTimeoutMillis: 5_000,
});

/** Código de PostgreSQL para una restricción única violada. */
const UNIQUE_VIOLATION = '23505';

/** Fila de `users` con los nombres que usan los servicios. */
function toUser(row) {
  return {
    id: row.id,
    name: row.name,
    email: row.email,
    passwordHash: row.password_hash,
    role: row.role,
    createdAt: row.created_at.toISOString(),
  };
}

function createPgStore({ databaseUrl, PoolClass = Pool } = {}) {
  if (!databaseUrl) throw new Error('Falta DATABASE_URL para PostgreSQL.');
  const pool = new PoolClass({ connectionString: databaseUrl, ...POOL_OPTIONS });
  // Un cliente inactivo que pierde la conexión no debe tumbar la API.
  pool.on('error', () => {});

  return {
    kind: 'postgres',
    pool,
    /** Indica si la base responde. Nunca muestra la cadena de conexión. */
    async ping() {
      try {
        await pool.query('SELECT 1');
        return true;
      } catch {
        return false;
      }
    },
    /**
     * Guarda una cuenta y la devuelve con `id` y `createdAt`. Devuelve
     * `null` si el correo ya tiene cuenta (índice único `users_email_key`).
     * `email` ya debe venir normalizado.
     */
    async createUser({ name, email, passwordHash, role }) {
      try {
        const { rows } = await pool.query(
          `INSERT INTO users (name, email, password_hash, role)
           VALUES ($1, $2, $3, $4)
           RETURNING id, name, email, password_hash, role, created_at`,
          [name, email, passwordHash, role],
        );
        return toUser(rows[0]);
      } catch (err) {
        if (err.code === UNIQUE_VIOLATION) return null;
        throw err;
      }
    },

    /** Cuenta con ese correo normalizado, o `null` si no existe. */
    async findUserByEmail(email) {
      const { rows } = await pool.query(
        `SELECT id, name, email, password_hash, role, created_at
         FROM users WHERE email = $1`,
        [email],
      );
      return rows.length === 0 ? null : toUser(rows[0]);
    },

    /** Cierra las conexiones (pruebas y apagado del servidor). */
    close() {
      return pool.end();
    },
  };
}

module.exports = { POOL_OPTIONS, createPgStore };
