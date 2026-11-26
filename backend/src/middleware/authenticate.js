'use strict';

const { HttpError } = require('../errors');
const { MESSAGES } = require('./rbac');

/** `Authorization: Bearer <token>`; el esquema no distingue mayúsculas. */
const BEARER = /^Bearer[ ]+(\S+)[ ]*$/i;

/**
 * Exige una sesión vigente. Lee el token del encabezado `Authorization`
 * y deja `req.auth = { sessionId, userId }`, que es lo que usa el control
 * de roles (S4-04). Sin token, con uno inválido o expirado responde
 * `401 UNAUTHENTICATED`.
 */
function authenticate({ sessionService }) {
  return async function authenticateGuard(req, _res, next) {
    const match = BEARER.exec(req.get('authorization') ?? '');
    const auth = match ? await sessionService.resolve(match[1]) : null;
    if (!auth) return next(new HttpError(401, MESSAGES.unauthenticated));
    req.auth = Object.freeze(auth);
    return next();
  };
}

module.exports = { authenticate };
