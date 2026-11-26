'use strict';

const { createApp } = require('./app');
const { describeConfig, loadConfig, loadEnvFile } = require('./config');

/** Abre el puerto y devuelve el servidor HTTP; falla si no puede. */
function start(config = loadConfig()) {
  const app = createApp({ config });
  return new Promise((resolve, reject) => {
    const server = app.listen(config.port);
    server.once('listening', () => {
      const { port } = server.address();
      console.log(`KoPay API (${config.env}) en http://localhost:${port}`);
      console.log('Configuración:', describeConfig(config));
      resolve(server);
    });
    // Por ejemplo, el puerto ya está ocupado.
    server.once('error', reject);
  });
}

if (require.main === module) {
  // Primero el archivo .env (si existe) y después la validación: si falta
  // un secreto en producción, el servidor no arranca.
  loadEnvFile();
  Promise.resolve()
    .then(() => start())
    .catch((err) => {
      console.error(err.message);
      process.exit(1);
    });
}

module.exports = { start };
