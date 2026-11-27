'use strict';

const { ERROR_CODES, HttpError } = require('../errors');

/**
 * Control de acceso por rol (S4-04, HU-34, HU-37).
 *
 * Reglas en docs/reglas-roles-contador.md, secciones 1, 3 y 5:
 * - El rol se lee de la base en **cada** petición, a partir de la sesión.
 *   Nunca se usa un rol que mande la app.
 * - `user` maneja sus propias finanzas y sus contadores autorizados.
 * - `accountant` no tiene finanzas propias: solo consulta, en lectura,
 *   a sus clientes bajo `/api/clients`.
 *
 * Integración pendiente:
 * - S4-01 deja el id de la sesión en `req.auth.userId`.
 * - S3-06 / S4-03 entregan la consulta del rol en la base.
 * - S4-06 agrega el paso 3, el permiso vigente con cada cliente.
 */

const ROLES = Object.freeze({
  USER: 'user',
  ACCOUNTANT: 'accountant',
});

/** Operaciones que se autorizan por rol. */
const PERMISSIONS = Object.freeze({
  /** Movimientos, ingresos, tarjetas, deudas y pagos propios. */
  OWN_FINANCES: 'own-finances',
  /** Autorizar y revocar contadores: `/api/accountants` (S4-05). */
  MANAGE_ACCOUNTANTS: 'manage-accountants',
  /** Consultar clientes en solo lectura: `/api/clients` (S4-06). */
  READ_CLIENTS: 'read-clients',
});

/** Qué puede hacer cada rol. Un rol que no está aquí no puede nada. */
const ROLE_PERMISSIONS = Object.freeze({
  [ROLES.USER]: Object.freeze([
    PERMISSIONS.OWN_FINANCES,
    PERMISSIONS.MANAGE_ACCOUNTANTS,
  ]),
  [ROLES.ACCOUNTANT]: Object.freeze([PERMISSIONS.READ_CLIENTS]),
});

const MESSAGES = Object.freeze({
  unauthenticated: 'Inicia sesión para continuar',
  forbidden: 'No tienes permiso para esta operación',
  /** Mismo texto con o sin permiso del cliente (reglas, sección 5). */
  clientForbidden: 'No tienes acceso a los datos de esta persona',
  unavailable: 'El servicio no está disponible. Inténtalo de nuevo.',
});

/** Métodos que no modifican datos. */
const READ_METHODS = new Set(['GET', 'HEAD', 'OPTIONS']);

/**
 * Indica si [role] tiene [permission]. Un rol desconocido responde
 * `false`, incluso si coincide con un nombre heredado de `Object`, como
 * `'constructor'` o `'__proto__'` (D-07).
 */
function can(role, permission) {
  if (typeof role !== 'string' || !Object.hasOwn(ROLE_PERMISSIONS, role)) return false;
  return ROLE_PERMISSIONS[role].includes(permission);
}

/**
 * Crea los middlewares de roles.
 *
 * [getUserRole] recibe el id de la sesión y devuelve el rol guardado en
 * la base (`'user'`, `'accountant'`) o `null` si la cuenta ya no existe.
 */
function createRbac({ getUserRole }) {
  if (typeof getUserRole !== 'function') {
    throw new TypeError('createRbac necesita getUserRole(userId)');
  }

  /**
   * Deja pasar solo a los roles que tienen [permission]. Al pasar,
   * `req.user` queda con `{ id, role }` leídos de la base.
   *
   * - Sin sesión, o con una cuenta que ya no existe: `401 UNAUTHENTICATED`.
   * - Con un rol sin ese permiso: `403 FORBIDDEN` con [message].
   * - Si la base no responde: `503 UNAVAILABLE`.
   */
  function requirePermission(permission, { message = MESSAGES.forbidden } = {}) {
    if (!Object.values(PERMISSIONS).includes(permission)) {
      throw new TypeError(`Permiso desconocido: ${permission}`);
    }
    return async function rbacGuard(req, _res, next) {
      const userId = req.auth?.userId;
      if (!userId) {
        return next(new HttpError(401, MESSAGES.unauthenticated));
      }

      let role;
      try {
        role = await getUserRole(userId);
      } catch {
        return next(
          new HttpError(503, MESSAGES.unavailable, {
            code: ERROR_CODES.UNAVAILABLE,
          }),
        );
      }
      if (!role) {
        return next(new HttpError(401, MESSAGES.unauthenticated));
      }
      if (!can(role, permission)) {
        return next(new HttpError(403, message));
      }

      req.user = Object.freeze({ id: userId, role });
      return next();
    };
  }

  /**
   * Rechaza con `403` cualquier método que modifique datos. Se monta en
   * `/api/clients` para que el contador solo pueda leer (HU-42), aunque
   * más adelante alguien agregue por error una ruta de escritura.
   */
  function readOnly({ message = MESSAGES.clientForbidden } = {}) {
    return function readOnlyGuard(req, _res, next) {
      if (READ_METHODS.has(req.method)) return next();
      return next(new HttpError(403, message));
    };
  }

  return {
    requirePermission,
    readOnly,
    /** Rutas financieras propias (S4-03, S5-01 a S5-05). */
    ownFinances: () => requirePermission(PERMISSIONS.OWN_FINANCES),
    /** Contadores autorizados de la persona (S4-05). */
    manageAccountants: () => requirePermission(PERMISSIONS.MANAGE_ACCOUNTANTS),
    /** Consultas del contador (S4-06): rol y solo lectura. */
    readClients: () => [
      requirePermission(PERMISSIONS.READ_CLIENTS, {
        message: MESSAGES.clientForbidden,
      }),
      readOnly(),
    ],
  };
}

module.exports = {
  MESSAGES,
  PERMISSIONS,
  ROLES,
  ROLE_PERMISSIONS,
  can,
  createRbac,
};
