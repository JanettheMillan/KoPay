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
  };
}

module.exports = { createMemoryStore };
