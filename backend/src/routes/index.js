'use strict';

const { Router } = require('express');
const { authRoutes } = require('./auth.routes');
const { healthRoutes } = require('./health.routes');

/**
 * Todas las rutas bajo `/api`. Cada módulo nuevo (cuentas, sesión,
 * datos) agrega aquí su router.
 */
function apiRoutes(services) {
  const router = Router();
  router.use('/health', healthRoutes(services));
  router.use('/auth', authRoutes(services));
  return router;
}

module.exports = { apiRoutes };
