'use strict';

/**
 * Capa de datos. Por ahora guarda en memoria; cuando se autorice la
 * base PostgreSQL (`pg`), solo cambia este módulo y los servicios
 * siguen usando la misma interfaz.
 */
function createMemoryStore() {
  const startedAt = new Date();
  return {
    kind: 'memory',
    /** Indica si la capa de datos responde. */
    async ping() {
      return true;
    },
    startedAt,
  };
}

module.exports = { createMemoryStore };
