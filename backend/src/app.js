'use strict';

const express = require('express');

const { loadConfig } = require('./config');
const { createMemoryStore } = require('./data/store');
const { errorHandler, notFound } = require('./middleware/errors');
const { createRbac } = require('./middleware/rbac');
const { apiRoutes } = require('./routes');
const { incomeRoutes } = require('./routes/incomes.routes');
const { movementRoutes } = require('./routes/movements.routes');
const { createAccountantAccessService } = require('./services/accountant-access.service');
const { createAuthService } = require('./services/auth.service');
const { createExchangeRateService } = require('./services/exchange-rate.service');
const { createHealthService } = require('./services/health.service');
const { createIncomeService } = require('./services/income.service');
const { createLoginThrottle } = require('./services/login-throttle');
const { createMailer } = require('./services/mail.service');
const { createMovementService } = require('./services/movement.service');
const { createRecoveryService } = require('./services/recovery.service');
const { createSessionService } = require('./services/session.service');

/**
 * Crea la aplicación Express sin abrir el puerto, para poder probarla
 * con supertest. Las dependencias se pueden reemplazar en las pruebas.
 */
function createApp({
  config = loadConfig(),
  store = createMemoryStore(),
  now,
  mailer = createMailer({ config }),
  exchangeRateService = createExchangeRateService({ token: config.banxicoToken }),
  // Rutas de cada recurso financiero (S5-01 a S5-05), detrás de la
  // protección de S4-03: { movements: (router) => { … }, … }.
  financeRegistrars = {},
} = {}) {
  const sessionService = createSessionService({ store, now, secret: config.jwtSecret });
  const movementService = createMovementService({ store });
  const incomeService = createIncomeService({ store });
  const services = {
    // Rutas de cada recurso financiero; las pruebas pueden reemplazarlas.
    financeRegistrars: {
      movements: movementRoutes({ movementService }),
      incomes: incomeRoutes({ incomeService }),
      ...financeRegistrars,
    },
    movementService,
    incomeService,
    healthService: createHealthService({ store, config }),
    sessionService,
    authService: createAuthService({
      store,
      sessionService,
      // Límite de intentos del login por correo (S4-13).
      loginThrottle: createLoginThrottle({ now }),
    }),
    recoveryService: createRecoveryService({ store, mailer, secret: config.jwtSecret, now }),
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
