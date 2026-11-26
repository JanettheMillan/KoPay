'use strict';

const { Router } = require('express');

const { authenticate } = require('../middleware/authenticate');
const { bindOwner } = require('../middleware/owner');

/**
 * Recursos financieros propios de la persona usuaria (S4-03, HU-34).
 * S5-01 a S5-05 agregan sus rutas dentro de estos routers.
 */
const FINANCE_RESOURCES = Object.freeze(['movements', 'incomes', 'cards', 'debts']);

/**
 * Router protegido para un recurso financiero. Cada petición pasa, en
 * orden, por:
 * 1. Sesión válida (`401 UNAUTHENTICATED`, S4-01).
 * 2. Rol `user` con el permiso `own-finances` (`403 FORBIDDEN`, S4-04):
 *    el contador no tiene finanzas propias.
 * 3. `req.ownerId` tomado de la sesión, sin campos de dueño que mande la
 *    app (S4-03).
 *
 * [register] recibe el router ya protegido y le agrega las rutas.
 */
function protectedFinanceRouter({ sessionService, rbac }, register = () => {}) {
  const router = Router();
  router.use(authenticate({ sessionService }), rbac.ownFinances(), bindOwner);
  register(router);
  return router;
}

/**
 * Monta los cuatro recursos financieros bajo `/api`. [registrars] trae,
 * por recurso, la función que agrega sus rutas (S5-01 a S5-05). Mientras
 * un recurso no tenga rutas, una cuenta `user` recibe `404 NOT_FOUND`
 * (después de pasar la sesión y el rol), no un error interno.
 */
function financeRoutes(services, registrars = {}) {
  const router = Router();
  for (const resource of FINANCE_RESOURCES) {
    router.use(`/${resource}`, protectedFinanceRouter(services, registrars[resource]));
  }
  return router;
}

module.exports = { FINANCE_RESOURCES, financeRoutes, protectedFinanceRouter };
