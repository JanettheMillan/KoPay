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
     */
    async createUser({ name, email, password, role }) {
      if (usersByEmail.has(email)) return null;
      const user = {
        id: randomUUID(),
        name,
        email,
        password,
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
  };
}

module.exports = { createMemoryStore };
