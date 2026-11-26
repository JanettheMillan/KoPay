'use strict';

const { randomUUID } = require('node:crypto');

/**
 * Capa de datos. Por ahora guarda en memoria; cuando se autorice la
 * base PostgreSQL (`pg`, S3-05), solo cambia este módulo y los servicios
 * siguen usando la misma interfaz.
 */
function createMemoryStore({ now = () => new Date() } = {}) {
  const startedAt = new Date();
  /** Cuentas por correo normalizado, como el índice único de `users`. */
  const usersByEmail = new Map();
  /** Sesiones por hash del token, como el índice único de `sessions`. */
  const sessionsByTokenHash = new Map();
  /**
   * Permisos de contador por `id`, como la tabla `accountant_access`
   * (docs/reglas-roles-contador.md, sección 6). Uno revocado se conserva
   * con su `revokedAt`, como historial.
   */
  const grantsById = new Map();

  /** Permiso vigente (`revokedAt` nulo) de esa pareja, o `undefined`. */
  const activeGrant = (userId, accountantId) =>
    [...grantsById.values()].find(
      (g) => g.userId === userId && g.accountantId === accountantId && g.revokedAt === null,
    );

  return {
    kind: 'memory',
    /** Indica si la capa de datos responde. */
    async ping() {
      return true;
    },
    startedAt,

    /**
     * Guarda una cuenta nueva y la devuelve con `id` (UUID) y
     * `createdAt`. Devuelve `null` si ya hay una cuenta con ese correo,
     * igual que la restricción única de la tabla `users`.
     * `email` ya debe venir normalizado (sin espacios y en minúsculas).
     * Solo guarda `passwordHash` (columna `password_hash`), nunca la
     * contraseña (S3-08).
     */
    async createUser({ name, email, passwordHash, role }) {
      if (usersByEmail.has(email)) return null;
      const user = {
        id: randomUUID(),
        name,
        email,
        passwordHash,
        role,
        createdAt: now().toISOString(),
      };
      usersByEmail.set(email, user);
      return { ...user };
    },

    /** Cuenta con ese correo normalizado, o `null` si no existe. */
    async findUserByEmail(email) {
      const user = usersByEmail.get(email);
      return user ? { ...user } : null;
    },

    /** Cuenta con ese `id`, o `null` si no existe. */
    async findUserById(id) {
      for (const user of usersByEmail.values()) {
        if (user.id === id) return { ...user };
      }
      return null;
    },

    /**
     * Abre una sesión (tabla `sessions`). Solo guarda el hash del token;
     * el token en claro lo tiene únicamente la app.
     */
    async createSession({ userId, tokenHash, expiresAt }) {
      const session = {
        id: randomUUID(),
        userId,
        tokenHash,
        createdAt: now().toISOString(),
        expiresAt,
        revokedAt: null,
      };
      sessionsByTokenHash.set(tokenHash, session);
      return { ...session };
    },

    /** Sesión con ese hash de token, o `null` si no existe. */
    async findSessionByTokenHash(tokenHash) {
      const session = sessionsByTokenHash.get(tokenHash);
      return session ? { ...session } : null;
    },

    /**
     * Concede a `accountantId` acceso a las finanzas de `userId` (S4-05).
     * Si la pareja ya tiene un permiso vigente lo devuelve sin crear otro,
     * igual que el índice único parcial de la sección 6. Devuelve
     * `{ grant, created }`. Los roles los revisa el servicio.
     */
    async createGrant({ userId, accountantId }) {
      const existing = activeGrant(userId, accountantId);
      if (existing) return { grant: { ...existing }, created: false };
      const grant = {
        id: randomUUID(),
        userId,
        accountantId,
        grantedAt: now().toISOString(),
        revokedAt: null,
      };
      grantsById.set(grant.id, grant);
      return { grant: { ...grant }, created: true };
    },

    /** Permisos vigentes que dio `userId`, del más antiguo al más nuevo. */
    async listActiveGrantsByUser(userId) {
      return [...grantsById.values()]
        .filter((g) => g.userId === userId && g.revokedAt === null)
        .sort((a, b) => a.grantedAt.localeCompare(b.grantedAt))
        .map((g) => ({ ...g }));
    },

    /** Permiso vigente entre `userId` y `accountantId`, o `null`. */
    async findActiveGrant({ userId, accountantId }) {
      const grant = activeGrant(userId, accountantId);
      return grant ? { ...grant } : null;
    },

    /**
     * Revoca el permiso `grantId` solo si es de `userId` y sigue vigente.
     * Devuelve `true` si lo revocó. No borra nada: llena `revokedAt`.
     */
    async revokeGrant({ grantId, userId }) {
      const grant = grantsById.get(grantId);
      if (!grant || grant.userId !== userId || grant.revokedAt !== null) return false;
      grant.revokedAt = now().toISOString();
      return true;
    },

    /** Todos los permisos de `userId`, incluidos los revocados (historial). */
    async listGrantsByUser(userId) {
      return [...grantsById.values()]
        .filter((g) => g.userId === userId)
        .map((g) => ({ ...g }));
    },
  };
}

module.exports = { createMemoryStore };
