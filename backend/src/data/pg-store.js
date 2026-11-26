'use strict';

const { Pool } = require('pg');

const { ERROR_CODES, HttpError } = require('../errors');

/**
 * Capa de datos sobre PostgreSQL (S3-05). Tiene la misma interfaz que
 * `createMemoryStore`: `ping()`, así que la ruta de salud responde 503 si
 * la base no contesta (caso DB-05); `createUser`, `findUserByEmail` y
 * `findUserById` sobre la tabla `users`; `createSession` y
 * `findSessionByTokenHash` sobre `sessions` (S3-09), y los permisos de
 * contador sobre `accountant_access` (S3-06): `createGrant`,
 * `listActiveGrantsByUser`, `listActiveGrantsByAccountant`,
 * `findActiveGrant`, `revokeGrant` y `listGrantsByUser`, con la misma interfaz que S4-05 usa en memoria.
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
 * Código de PostgreSQL para un texto que no es un `uuid` válido. Los ids
 * de permisos llegan de la URL: uno mal formado equivale a uno que no
 * existe, igual que en la capa en memoria.
 */
const INVALID_TEXT = '22P02';

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
    refreshTokenHash: row.refresh_token_hash ?? null,
    refreshExpiresAt: row.refresh_expires_at ? row.refresh_expires_at.toISOString() : null,
  };
}

const SESSION_COLUMNS =
  'id, user_id, token_hash, created_at, expires_at, revoked_at, refresh_token_hash, refresh_expires_at';

/** Fila de `accountant_access` con los nombres que usan los servicios. */
function toGrant(row) {
  return {
    id: row.id,
    userId: row.user_id,
    accountantId: row.accountant_id,
    grantedAt: row.granted_at.toISOString(),
    revokedAt: row.revoked_at ? row.revoked_at.toISOString() : null,
  };
}

const GRANT_COLUMNS = 'id, user_id, accountant_id, granted_at, revoked_at';

/** Fila de `password_resets` con los nombres que usan los servicios. */
function toReset(row) {
  return {
    id: row.id,
    userId: row.user_id,
    codeHash: row.code_hash,
    createdAt: row.created_at.toISOString(),
    expiresAt: row.expires_at.toISOString(),
    attempts: row.attempts,
    usedAt: row.used_at ? row.used_at.toISOString() : null,
  };
}

const RESET_COLUMNS = 'id, user_id, code_hash, created_at, expires_at, attempts, used_at';

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
    async createSession({
      userId,
      tokenHash,
      expiresAt,
      refreshTokenHash = null,
      refreshExpiresAt = null,
    }) {
      const { rows } = await query(
        `INSERT INTO sessions
           (user_id, token_hash, expires_at, refresh_token_hash, refresh_expires_at)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING ${SESSION_COLUMNS}`,
        [userId, tokenHash, expiresAt, refreshTokenHash, refreshExpiresAt],
      );
      return toSession(rows[0]);
    },

    /** Sesión con ese hash de token, o `null` si no existe. */
    async findSessionByTokenHash(tokenHash) {
      const { rows } = await query(
        `SELECT ${SESSION_COLUMNS} FROM sessions WHERE token_hash = $1`,
        [tokenHash],
      );
      return rows.length === 0 ? null : toSession(rows[0]);
    },

    /** Sesión con ese hash de refreshToken, o `null` (S4-02). */
    async findSessionByRefreshHash(refreshTokenHash) {
      const { rows } = await query(
        `SELECT ${SESSION_COLUMNS} FROM sessions WHERE refresh_token_hash = $1`,
        [refreshTokenHash],
      );
      return rows.length === 0 ? null : toSession(rows[0]);
    },

    /**
     * Cierra la sesión `sessionId` llenando `revoked_at` (S4-02). Devuelve
     * `true` solo si estaba abierta: dos renovaciones a la vez con el
     * mismo refreshToken no pueden ganar las dos.
     */
    async revokeSession(sessionId) {
      const { rowCount } = await query(
        'UPDATE sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL',
        [sessionId],
      );
      return rowCount === 1;
    },

    /**
     * Concede a `accountantId` acceso a las finanzas de `userId` (S3-06,
     * S4-05). Si la pareja ya tiene un permiso vigente lo devuelve sin
     * crear otro (índice único parcial `accountant_access_active_key`).
     * Devuelve `{ grant, created }`. Los roles los revisa el servicio.
     */
    async createGrant({ userId, accountantId }) {
      const { rows } = await query(
        `INSERT INTO accountant_access (user_id, accountant_id)
         VALUES ($1, $2)
         ON CONFLICT (user_id, accountant_id) WHERE revoked_at IS NULL
         DO NOTHING
         RETURNING ${GRANT_COLUMNS}`,
        [userId, accountantId],
      );
      if (rows.length > 0) return { grant: toGrant(rows[0]), created: true };
      const existing = await query(
        `SELECT ${GRANT_COLUMNS} FROM accountant_access
         WHERE user_id = $1 AND accountant_id = $2 AND revoked_at IS NULL`,
        [userId, accountantId],
      );
      return { grant: toGrant(existing.rows[0]), created: false };
    },

    /** Permisos vigentes que dio `userId`, del más antiguo al más nuevo. */
    async listActiveGrantsByUser(userId) {
      const { rows } = await query(
        `SELECT ${GRANT_COLUMNS} FROM accountant_access
         WHERE user_id = $1 AND revoked_at IS NULL
         ORDER BY granted_at, id`,
        [userId],
      );
      return rows.map(toGrant);
    },

    /**
     * Permisos vigentes que recibió `accountantId` (S4-06), del más
     * antiguo al más nuevo. Es la lista de clientes del contador y usa el
     * índice parcial `accountant_access_accountant_idx`.
     */
    async listActiveGrantsByAccountant(accountantId) {
      const { rows } = await query(
        `SELECT ${GRANT_COLUMNS} FROM accountant_access
         WHERE accountant_id = $1 AND revoked_at IS NULL
         ORDER BY granted_at, id`,
        [accountantId],
      );
      return rows.map(toGrant);
    },

    /** Permiso vigente entre `userId` y `accountantId`, o `null`. */
    async findActiveGrant({ userId, accountantId }) {
      try {
        const { rows } = await query(
          `SELECT ${GRANT_COLUMNS} FROM accountant_access
           WHERE user_id = $1 AND accountant_id = $2 AND revoked_at IS NULL`,
          [userId, accountantId],
        );
        return rows.length === 0 ? null : toGrant(rows[0]);
      } catch (err) {
        if (err.code === INVALID_TEXT) return null;
        throw err;
      }
    },

    /**
     * Revoca el permiso `grantId` solo si es de `userId` y sigue vigente.
     * Devuelve `true` si lo revocó. No borra nada: llena `revoked_at`.
     */
    async revokeGrant({ grantId, userId }) {
      try {
        const { rowCount } = await query(
          `UPDATE accountant_access SET revoked_at = now()
           WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL`,
          [grantId, userId],
        );
        return rowCount === 1;
      } catch (err) {
        if (err.code === INVALID_TEXT) return false;
        throw err;
      }
    },

    /**
     * Guarda el código de recuperación de `userId` (S4-19) y borra los
     * anteriores en la misma sentencia. Solo recibe el hash del código.
     */
    async createPasswordReset({ userId, codeHash, expiresAt }) {
      const { rows } = await query(
        `WITH previous AS (DELETE FROM password_resets WHERE user_id = $1)
         INSERT INTO password_resets (user_id, code_hash, expires_at)
         VALUES ($1, $2, $3)
         RETURNING ${RESET_COLUMNS}`,
        [userId, codeHash, expiresAt],
      );
      return toReset(rows[0]);
    },

    /** Código de recuperación más reciente de `userId`, o `null`. */
    async findLatestPasswordReset(userId) {
      const { rows } = await query(
        `SELECT ${RESET_COLUMNS} FROM password_resets
         WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [userId],
      );
      return rows.length === 0 ? null : toReset(rows[0]);
    },

    /**
     * Suma un intento fallido al código `resetId` si sigue sin usar y
     * tiene menos de 5. Devuelve los intentos, o `null` si no lo sumó.
     */
    async recordPasswordResetFailure(resetId) {
      const { rows } = await query(
        `UPDATE password_resets SET attempts = attempts + 1
         WHERE id = $1 AND used_at IS NULL AND attempts < 5
         RETURNING attempts`,
        [resetId],
      );
      return rows.length === 0 ? null : rows[0].attempts;
    },

    /**
     * Cambia la contraseña con el código `resetId` (S4-19) en una sola
     * transacción: marca el código usado, guarda `passwordHash` y llena
     * `revoked_at` en todas las sesiones abiertas de `userId`. Devuelve
     * `false`, sin cambiar nada, si el código ya se usó.
     */
    async completePasswordReset({ resetId, userId, passwordHash }) {
      let client;
      try {
        client = await pool.connect();
      } catch (err) {
        if (isUnavailable(err)) throw unavailable();
        throw err;
      }
      try {
        await client.query('BEGIN');
        const used = await client.query(
          `UPDATE password_resets SET used_at = now()
           WHERE id = $1 AND user_id = $2 AND used_at IS NULL
           RETURNING id`,
          [resetId, userId],
        );
        if (used.rows.length === 0) {
          await client.query('ROLLBACK');
          return false;
        }
        await client.query(
          'UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2',
          [passwordHash, userId],
        );
        await client.query(
          'UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
          [userId],
        );
        await client.query('COMMIT');
        return true;
      } catch (err) {
        await client.query('ROLLBACK').catch(() => {});
        if (isUnavailable(err)) throw unavailable();
        throw err;
      } finally {
        client.release();
      }
    },

    /** Todos los permisos de `userId`, incluidos los revocados (historial). */
    async listGrantsByUser(userId) {
      const { rows } = await query(
        `SELECT ${GRANT_COLUMNS} FROM accountant_access
         WHERE user_id = $1
         ORDER BY granted_at, id`,
        [userId],
      );
      return rows.map(toGrant);
    },

    /** Cierra las conexiones (pruebas y apagado del servidor). */
    close() {
      return pool.end();
    },
  };
}

module.exports = { POOL_OPTIONS, createPgStore, isUnavailable };
