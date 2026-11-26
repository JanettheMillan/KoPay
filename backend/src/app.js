'use strict';

const express = require('express');

const { loadConfig } = require('./config');
const { createMemoryStore } = require('./data/store');
const { errorHandler, notFound } = require('./middleware/errors');
const { apiRoutes } = require('./routes');
const { createAuthService } = require('./services/auth.service');
const { createHealthService } = require('./services/health.service');
const { createSessionService } = require('./services/session.service');

/**
 * Crea la aplicación Express sin abrir el puerto, para poder probarla
 * con supertest. Las dependencias se pueden reemplazar en las pruebas.
 */
function createApp({ config = loadConfig(), store = createMemoryStore(), now } = {}) {
  const sessionService = createSessionService({ store, now });
  const services = {
    healthService: createHealthService({ store, config }),
    sessionService,
    authService: createAuthService({ store, sessionService }),
  };

  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '100kb' }));
  app.use('/api', apiRoutes(services));
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

module.exports = { createApp };
