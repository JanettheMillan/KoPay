'use strict';

const { Router } = require('express');

/** `GET /api/health`: 200 si el servicio está bien, 503 si no. */
function healthRoutes({ healthService }) {
  const router = Router();
  router.get('/', async (_req, res) => {
    const health = await healthService.check();
    res.status(health.status === 'ok' ? 200 : 503).json(health);
  });
  return router;
}

module.exports = { healthRoutes };
