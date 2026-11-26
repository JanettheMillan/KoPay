'use strict';

const { Router } = require('express');

const { authenticate } = require('../middleware/authenticate');

/**
 * Contadores autorizados de la persona usuaria, bajo `/api/accountants`
 * (HU-38, HU-41, S4-05). Primero la sesión (401) y luego el rol (403):
 * solo una cuenta `user` decide quién ve sus finanzas.
 */
function accountantRoutes({ sessionService, rbac, accountantAccessService }) {
  const router = Router();
  router.use(authenticate({ sessionService }), rbac.manageAccountants());

  /** `GET /api/accountants`: 200 con los permisos vigentes. */
  router.get('/', async (req, res) => {
    res.status(200).json({ grants: await accountantAccessService.list(req.user.id) });
  });

  /** `POST /api/accountants`: 201 con el permiso nuevo, o 200 si ya estaba vigente. */
  router.post('/', async (req, res) => {
    const { grant, created } = await accountantAccessService.grant(req.user.id, req.body);
    res.status(created ? 201 : 200).json({ grant });
  });

  /** `DELETE /api/accountants/:grantId`: 204 sin cuerpo. */
  router.delete('/:grantId', async (req, res) => {
    await accountantAccessService.revoke(req.user.id, req.params.grantId);
    res.status(204).end();
  });

  return router;
}

module.exports = { accountantRoutes };
