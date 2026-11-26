'use strict';

const { Pool } = require('pg');

const { ERROR_CODES, HttpError } = require('../errors');

/**
 * Capa de datos sobre PostgreSQL (S3-05). Tiene la misma interfaz que
 * `createMemoryStore`: `ping()`, así que la ruta de salud responde 503 si
 * la base no contesta (caso DB-05); `createUser`, `findUserByEmail` y
 * `findUserById` sobre la tabla `users`, y `createSession` y
 * `findSessionByTokenHash` sobre `sessions` (S3-09).
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

/**
 * Errores de conexión: la base no responde, no se encuentra o cortó la
 * conexión. Clase 08 (conexión) y 57P0x (servidor apagándose) de
 * PostgreSQL, más los errores de red de Node.
 */
const UNAVAILABLE_CODES = new Set([
  'ECONNREFUSED',
  'ECONNRESET',
  'ENOTFOUND',
  'ETIMEDOUT',
  'EAI_AGAIN',
  '57P01',
  '57P02',
  '57P03',
]);

function isUnavailable(err) {
  if (!err) return false;
  if (UNAVAILABLE_CODES.has(err.code)) return true;
  if (typeof err.code === 'string' && err.code.startsWith('08')) return true;
  return /timeout exceeded when trying to connect|Connection terminated/i.test(
    err.message ?? '',
  );
}

/**
 * Si la base no responde, el contrato pide `503 UNAVAILABLE` (sección 2),
 * no un 500. El mensaje nunca muestra la cadena de conexión.
 */
function unavailable() {
  return new HttpError(503, 'El servicio no está disponible. Inténtalo de nuevo.', {
    code: ERROR_CODES.UNAVAILABLE,
  });
}

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

/** Fila de `sessions` con los nombres que usan los servicios. */
function toSession(row) {
  return {
    id: row.id,
    userId: row.user_id,
    tokenHash: row.token_hash,
    createdAt: row.created_at.toISOString(),
    expiresAt: row.expires_at.toISOString(),
    revokedAt: row.revoked_at ? row.revoked_at.toISOString() : null,
  };
}

function createPgStore({ databaseUrl, PoolClass = Pool } = {}) {
  if (!databaseUrl) throw new Error('Falta DATABASE_URL para PostgreSQL.');
  const pool = new PoolClass({ connectionString: databaseUrl, ...POOL_OPTIONS });
  // Un cliente inactivo que pierde la conexión no debe tumbar la API.
  pool.on('error', () => {});

  /** `pool.query` que convierte una caída de la base en 503. */
  async function query(text, params) {
    try {
      return await pool.query(text, params);
    } catch (err) {
      if (isUnavailable(err)) throw unavailable();
      throw err;
    }
  }

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
        const { rows } = await query(
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
      const { rows } = await query(
        `SELECT id, name, email, password_hash, role, created_at
         FROM users WHERE email = $1`,
        [email],
      );
      return rows.length === 0 ? null : toUser(rows[0]);
    },

    /** Cuenta con ese `id`, o `null` si no existe. */
    async findUserById(id) {
      const { rows } = await query(
        `SELECT id, name, email, password_hash, role, created_at
         FROM users WHERE id = $1`,
        [id],
      );
      return rows.length === 0 ? null : toUser(rows[0]);
    },

    /**
     * Abre una sesión (S3-09). Solo guarda el hash del token; el token en
     * claro lo tiene únicamente la app.
     */
    async createSession({ userId, tokenHash, expiresAt }) {
      const { rows } = await query(
        `INSERT INTO sessions (user_id, token_hash, expires_at)
         VALUES ($1, $2, $3)
         RETURNING id, user_id, token_hash, created_at, expires_at, revoked_at`,
        [userId, tokenHash, expiresAt],
      );
      return toSession(rows[0]);
    },

    /** Sesión con ese hash de token, o `null` si no existe. */
    async findSessionByTokenHash(tokenHash) {
      const { rows } = await query(
        `SELECT id, user_id, token_hash, created_at, expires_at, revoked_at
         FROM sessions WHERE token_hash = $1`,
        [tokenHash],
      );
      return rows.length === 0 ? null : toSession(rows[0]);
    },

    /** Cierra las conexiones (pruebas y apagado del servidor). */
    close() {
      return pool.end();
    },
  };
}

module.exports = { POOL_OPTIONS, createPgStore, isUnavailable };
