'use strict';

const { HttpError } = require('../errors');
const { normalizeEmail } = require('../validators/auth.validator');

/**
 * Conceder y revocar el acceso de un contador (HU-38, HU-41, S4-05) y
 * consultar a quién puede ver (HU-39, HU-40, S4-06).
 * Reglas en docs/reglas-roles-contador.md, secciones 2 y 4.
 */
const MESSAGES = Object.freeze({
  validation: 'Revisa los datos marcados',
  emailInvalid: 'Escribe un correo válido',
  accountantNotFound: 'No hay un contador con ese correo',
  grantNotFound: 'No encontramos ese permiso',
});

const ACCOUNTANT_ROLE = 'accountant';
const EMAIL_MAX = 254;
/** `texto@dominio.ext`, igual que el registro. */
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
/** Los `id` son UUID (docs/base-de-datos.md). */
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Lo que ve la persona usuaria de un permiso: nunca datos de la sesión. */
function publicGrant(grant, accountant) {
  return {
    id: grant.id,
    accountant: { id: accountant.id, name: accountant.name, email: accountant.email },
    grantedAt: grant.grantedAt,
  };
}

/** Lo que ve el contador de un cliente: nombre, correo y fecha del permiso. */
function publicClient(user, grant) {
  return { id: user.id, name: user.name, email: user.email, grantedAt: grant.grantedAt };
}

/**
 * `userId` siempre es el de la sesión. Nada del cuerpo decide sobre qué
 * cuenta se actúa, así nadie autoriza ni revoca en nombre de otra.
 */
function createAccountantAccessService({ store }) {
  return {
    /** Permisos vigentes que dio `userId` (`GET /api/accountants`). */
    async list(userId) {
      const grants = await store.listActiveGrantsByUser(userId);
      const result = [];
      for (const grant of grants) {
        const accountant = await store.findUserById(grant.accountantId);
        // Si la cuenta del contador se borró, su permiso ya no cuenta (sección 4.6).
        if (accountant) result.push(publicGrant(grant, accountant));
      }
      return result;
    },

    /**
     * Autoriza al contador con `accountantEmail` (`POST /api/accountants`).
     * Devuelve `{ grant, created }`: `created` es `false` si ya había un
     * permiso vigente, y entonces no se crea otro (sección 2.5).
     * Lanza 400 si el correo no es válido y 404 si no es de un contador.
     */
    async grant(userId, body) {
      const input = body !== null && typeof body === 'object' && !Array.isArray(body) ? body : {};
      const email = normalizeEmail(input.accountantEmail);
      if (email.length > EMAIL_MAX || !EMAIL_PATTERN.test(email)) {
        throw new HttpError(400, MESSAGES.validation, {
          fields: { accountantEmail: MESSAGES.emailInvalid },
        });
      }

      const accountant = await store.findUserByEmail(email);
      // Mismo 404 si el correo no existe o es de una cuenta `user`, así
      // no se puede averiguar qué correos tienen cuenta.
      if (!accountant || accountant.role !== ACCOUNTANT_ROLE || accountant.id === userId) {
        throw new HttpError(404, MESSAGES.accountantNotFound);
      }

      const { grant, created } = await store.createGrant({ userId, accountantId: accountant.id });
      return { grant: publicGrant(grant, accountant), created };
    },

    /**
     * Revoca el permiso `grantId` de `userId` (`DELETE /api/accountants/:grantId`).
     * Efecto inmediato: `hasAccess` deja de devolver `true` en la siguiente
     * consulta. Lanza 404 si el permiso no existe, no es suyo o ya estaba
     * revocado (sección 7).
     */
    async revoke(userId, grantId) {
      const revoked =
        typeof grantId === 'string' &&
        UUID_PATTERN.test(grantId) &&
        (await store.revokeGrant({ grantId, userId }));
      if (!revoked) throw new HttpError(404, MESSAGES.grantNotFound);
    },

    /**
     * Personas que autorizaron a `accountantId` y siguen vigentes
     * (`GET /api/clients`, HU-39, S4-06). Nunca devuelve sus finanzas.
     */
    async listClients(accountantId) {
      const grants = await store.listActiveGrantsByAccountant(accountantId);
      const result = [];
      for (const grant of grants) {
        const user = await store.findUserById(grant.userId);
        // Si la cuenta de la persona se borró, su permiso ya no cuenta (sección 4.6).
        if (user) result.push(publicClient(user, grant));
      }
      return result;
    },

    /**
     * La persona `userId`, solo si `accountantId` tiene hoy un permiso
     * vigente sobre ella; si no, `null`. Un id mal formado, una cuenta que
     * no existe y una sin permiso dan lo mismo (sección 5, ROL-08).
     */
    async findClient({ userId, accountantId }) {
      if (typeof userId !== 'string' || !UUID_PATTERN.test(userId)) return null;
      const grant = await store.findActiveGrant({ userId, accountantId });
      if (!grant) return null;
      const user = await store.findUserById(userId);
      return user ? publicClient(user, grant) : null;
    },

    /**
     * Indica si `accountantId` tiene hoy un permiso vigente sobre `userId`.
     * Se consulta en cada petición, sin caché (sección 4.2). Lo usa S4-06
     * como paso 3 de la sección 5.
     */
    async hasAccess({ userId, accountantId }) {
      return (await store.findActiveGrant({ userId, accountantId })) !== null;
    },
  };
}

module.exports = { MESSAGES, createAccountantAccessService };
