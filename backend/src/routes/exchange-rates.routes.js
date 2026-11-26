'use strict';

const { Router } = require('express');

const { authenticate } = require('../middleware/authenticate');

/**
 * Tipo de cambio bajo `/api/exchange-rates` (HU-35, S5-06). Requiere
 * sesión de cualquier rol: es información pública, pero la consulta usa
 * el token de Banxico del servidor y no debe quedar abierta.
 */
function exchangeRateRoutes({ sessionService, exchangeRateService }) {
  const router = Router();
  router.use(authenticate({ sessionService }));

  /** `GET /api/exchange-rates`: 200 con el FIX USD/MXN más reciente. */
  router.get('/', async (_req, res) => {
    res.status(200).json(await exchangeRateService.getUsdMxn());
  });

  return router;
}

module.exports = { exchangeRateRoutes };
