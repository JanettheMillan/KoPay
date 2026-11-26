'use strict';

const { createHash, randomBytes } = require('node:crypto');

/** Vigencia del token de acceso, en segundos (contrato, sección 3.2). */
const ACCESS_TOKEN_TTL_SECONDS = 900;
const TOKEN_BYTES = 32;

/** Hash con el que se guarda y se busca un token. */
function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Sesiones del Sprint 3: el token de acceso es texto aleatorio y opaco, y
 * en la capa de datos solo se guarda su hash (tabla `sessions` de S3-05).
 * S4-01 lo cambia por un JWT sin cambiar la respuesta del login.
 */
function createSessionService({ store, now = () => new Date() }) {
  return {
    /** Abre una sesión para `userId` y devuelve el token en claro. */
    async open(userId) {
      const accessToken = randomBytes(TOKEN_BYTES).toString('base64url');
      const expiresAt = new Date(now().getTime() + ACCESS_TOKEN_TTL_SECONDS * 1000);
      await store.createSession({
        userId,
        tokenHash: hashToken(accessToken),
        expiresAt: expiresAt.toISOString(),
      });
      return { accessToken, tokenType: 'Bearer', expiresIn: ACCESS_TOKEN_TTL_SECONDS };
    },

    /**
     * Sesión vigente de `token`, o `null` si no existe, expiró o se
     * cerró. Devuelve `{ sessionId, userId }`.
     */
    async resolve(token) {
      if (typeof token !== 'string' || token === '') return null;
      const session = await store.findSessionByTokenHash(hashToken(token));
      if (!session || session.revokedAt) return null;
      if (new Date(session.expiresAt).getTime() <= now().getTime()) return null;
      return { sessionId: session.id, userId: session.userId };
    },
  };
}

module.exports = { ACCESS_TOKEN_TTL_SECONDS, createSessionService, hashToken };
