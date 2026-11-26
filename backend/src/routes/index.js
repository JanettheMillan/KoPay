'use strict';

const { Router } = require('express');
const { accountantRoutes } = require('./accountants.routes');
const { authRoutes } = require('./auth.routes');
const { clientRoutes } = require('./clients.routes');
const { exchangeRateRoutes } = require('./exchange-rates.routes');
const { financeRoutes } = require('./finances.routes');
const { healthRoutes } = require('./health.routes');

/**
 * Todas las rutas bajo `/api`. Cada módulo nuevo (cuentas, sesión,
 * datos) agrega aquí su router.
 */
function apiRoutes(services) {
  const router = Router();
  router.use('/health', healthRoutes(services));
  router.use('/auth', authRoutes(services));
  router.use('/accountants', accountantRoutes(services));
  router.use('/clients', clientRoutes(services));
  router.use('/exchange-rates', exchangeRateRoutes(services));
  // Movimientos, ingresos, tarjetas y deudas propios (S4-03; rutas en S5-01 a S5-05).
  router.use(financeRoutes(services, services.financeRegistrars));
  return router;
}

module.exports = { apiRoutes };
