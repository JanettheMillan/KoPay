'use strict';

const express = require('express');

const { loadConfig } = require('./config');
const { createMemoryStore } = require('./data/store');
const { errorHandler, notFound } = require('./middleware/errors');
const { createRbac } = require('./middleware/rbac');
const { apiRoutes } = require('./routes');
const { createAccountantAccessService } = require('./services/accountant-access.service');
const { createAuthService } = require('./services/auth.service');
const { createExchangeRateService } = require('./services/exchange-rate.service');
const { createHealthService } = require('./services/health.service');
const { createSessionService } = require('./services/session.service');

/**
 * Crea la aplicación Express sin abrir el puerto, para poder probarla
 * con supertest. Las dependencias se pueden reemplazar en las pruebas.
 */
function createApp({
  config = loadConfig(),
  store = createMemoryStore(),
  now,
  exchangeRateService = createExchangeRateService({ token: config.banxicoToken }),
} = {}) {
  const sessionService = createSessionService({ store, now });
  const services = {
    healthService: createHealthService({ store, config }),
    sessionService,
    authService: createAuthService({ store, sessionService }),
    accountantAccessService: createAccountantAccessService({ store }),
    exchangeRateService,
    // El rol se lee de la base en cada petición (S4-04).
    rbac: createRbac({
      getUserRole: async (userId) => (await store.findUserById(userId))?.role ?? null,
    }),
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
