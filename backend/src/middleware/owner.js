'use strict';

const { HttpError } = require('../errors');

/**
 * Identidad del dueño en las rutas financieras (S4-03, HU-34).
 *
 * Regla de docs/base-de-datos.md §3: el `user_id` sale **siempre** de la
 * sesión verificada, nunca del cuerpo, la URL ni la consulta.
 *
 * - [bindOwner] deja `req.ownerId` con el id de la sesión (que ya puso
 *   `rbac.ownFinances()` en `req.user`) y borra de `req.body` y
 *   `req.query` cualquier `userId`/`user_id`/`ownerId`, para que ningún
 *   servicio lo use por error.
 * - [ensureOwned] responde `404 NOT_FOUND` si un registro no existe o es
 *   de otra cuenta: la respuesta es la misma, así no se revela que existe.
 */

/** Campos que una petición nunca puede usar para elegir dueño. */
const OWNER_FIELDS = Object.freeze(['userId', 'user_id', 'ownerId', 'owner_id']);

const NOT_FOUND_MESSAGE = 'No encontramos ese registro';

function stripOwnerFields(target) {
  if (target === null || typeof target !== 'object' || Array.isArray(target)) return;
  for (const field of OWNER_FIELDS) delete target[field];
}

/** Middleware: `req.ownerId` = id de la sesión. Va después de `ownFinances()`. */
function bindOwner(req, _res, next) {
  const id = req.user?.id;
  if (!id) return next(new HttpError(401, 'Inicia sesión para continuar'));
  stripOwnerFields(req.body);
  // En Express 5 `req.query` es de solo lectura: se copia sin los campos.
  if (req.query && typeof req.query === 'object') {
    const query = { ...req.query };
    stripOwnerFields(query);
    Object.defineProperty(req, 'query', { value: query, writable: true, configurable: true });
  }
  req.ownerId = id;
  return next();
}

/**
 * Devuelve [record] si es de [ownerId]; si no existe o es ajeno, lanza
 * `404 NOT_FOUND`. [ownerOf] lee el dueño del registro (por defecto
 * `record.userId`).
 */
function ensureOwned(record, ownerId, { ownerOf = (r) => r.userId } = {}) {
  if (!record || !ownerId || ownerOf(record) !== ownerId) {
    throw new HttpError(404, NOT_FOUND_MESSAGE);
  }
  return record;
}

module.exports = { NOT_FOUND_MESSAGE, OWNER_FIELDS, bindOwner, ensureOwned };
