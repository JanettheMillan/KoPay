'use strict';

const { version } = require('../../package.json');

/**
 * Estado del servicio para la ruta de salud. Consulta la capa de datos
 * y responde `ok` solo si también está disponible.
 */
function createHealthService({ store, config, now = () => new Date() }) {
  return {
    async check() {
      let dataOk = false;
      try {
        dataOk = await store.ping();
      } catch {
        dataOk = false;
      }
      return {
        status: dataOk ? 'ok' : 'error',
        service: 'kopay-api',
        version,
        environment: config.env,
        data: { kind: store.kind, ok: dataOk },
        timestamp: now().toISOString(),
      };
    },
  };
}

module.exports = { createHealthService };
