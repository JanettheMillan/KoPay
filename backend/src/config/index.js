'use strict';

/**
 * Configuración de la API, leída una sola vez de las variables de
 * entorno. El resto del código la recibe de aquí y no lee
 * `process.env` directamente.
 *
 * S3-02 agrega la separación por ambientes y los secretos.
 */
function loadConfig(env = process.env) {
  const port = Number(env.PORT ?? 3000);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error(`PORT inválido: "${env.PORT}"`);
  }
  return Object.freeze({
    port,
    env: env.NODE_ENV || 'development',
  });
}

module.exports = { loadConfig };
