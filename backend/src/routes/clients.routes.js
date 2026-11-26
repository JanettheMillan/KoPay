'use strict';

const { Router } = require('express');

const { authenticate } = require('../middleware/authenticate');
const { requireClientAccess } = require('../middleware/client-access');

/**
 * Consultas del contador bajo `/api/clients` (HU-39, HU-40, HU-42, S4-06).
 * Cada petición pasa por los tres pasos de la sección 5 de las reglas:
 * sesión (401), rol `accountant` y solo lectura (403) y, en las rutas de
 * una persona, permiso vigente (403).
 */
function clientRoutes({ sessionService, rbac, accountantAccessService }) {
  const router = Router();
  router.use(authenticate({ sessionService }), ...rbac.readClients());

  /** `GET /api/clients`: 200 con las personas que lo autorizaron y siguen vigentes. */
  router.get('/', async (req, res) => {
    res.status(200).json({ clients: await accountantAccessService.listClients(req.user.id) });
  });

  /**
   * Todo lo que cuelga de una persona exige un permiso vigente. S5-03
   * agrega aquí `/summary` y `/movements`, que leen `req.client.id`.
   */
  const client = Router({ mergeParams: true });
  router.use('/:userId', requireClientAccess({ accountantAccessService }), client);

  /** `GET /api/clients/:userId`: 200 con los datos de la persona en la lista. */
  client.get('/', (req, res) => {
    res.status(200).json({ client: req.client });
  });

  return router;
}

module.exports = { clientRoutes };
