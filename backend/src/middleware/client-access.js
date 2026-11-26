'use strict';

const { HttpError } = require('../errors');
const { MESSAGES } = require('./rbac');

/**
 * Paso 3 de la comprobación del servidor (docs/reglas-roles-contador.md,
 * sección 5, S4-06): el contador de la sesión debe tener hoy un permiso
 * vigente sobre `:userId`. Va después de la sesión (paso 1) y de
 * `rbac.readClients()` (paso 2), que ya dejaron `req.user`.
 *
 * Un `:userId` sin permiso, revocado, inexistente o mal formado responde
 * el mismo `403`, así cambiar el número en la URL no revela qué cuentas
 * existen (ROL-08). El permiso se consulta en cada petición, sin caché,
 * así que revocar tiene efecto inmediato (sección 4.2).
 *
 * Si pasa, deja `req.client = { id, name, email, grantedAt }`. Las
 * consultas de S5-03 deben filtrar siempre por `req.client.id`, nunca por
 * un identificador del cuerpo o de la consulta.
 */
function requireClientAccess({ accountantAccessService }) {
  return async function clientAccessGuard(req, _res, next) {
    const client = await accountantAccessService.findClient({
      userId: req.params.userId,
      accountantId: req.user.id,
    });
    if (!client) return next(new HttpError(403, MESSAGES.clientForbidden));
    req.client = Object.freeze(client);
    return next();
  };
}

module.exports = { requireClientAccess };
