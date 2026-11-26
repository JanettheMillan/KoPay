'use strict';

const { createHash } = require('node:crypto');

const { signToken, verifyToken } = require('./jwt');

/** Vigencia del token de acceso, en segundos (contrato, sección 3.2). */
const ACCESS_TOKEN_TTL_SECONDS = 900;

/** Hash con el que se guarda y se busca un token. */
function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Sesiones con JWT (S4-01). El token de acceso es un JWT HS256 firmado
 * con `JWT_SECRET` que lleva el id del usuario (`sub`) y vence en 15
 * minutos. Para la app sigue siendo opaco: la respuesta del login no
 * cambia (contrato §3.2).
 *
 * Además de la firma, cada token tiene su fila en `sessions` (solo su
 * hash). Así un token bien firmado deja de servir si la sesión se cierra
 * (S4-02) o si la fila ya no existe.
 */
function createSessionService({ store, secret, now = () => new Date() }) {
  if (!secret) throw new Error('Falta JWT_SECRET para las sesiones.');
  return {
    /** Abre una sesión para `userId` y devuelve el token en claro. */
    async open(userId) {
      const accessToken = signToken({
        subject: userId,
        expiresIn: ACCESS_TOKEN_TTL_SECONDS,
        secret,
        now,
      });
      const expiresAt = new Date(now().getTime() + ACCESS_TOKEN_TTL_SECONDS * 1000);
      await store.createSession({
        userId,
        tokenHash: hashToken(accessToken),
        expiresAt: expiresAt.toISOString(),
      });
      return { accessToken, tokenType: 'Bearer', expiresIn: ACCESS_TOKEN_TTL_SECONDS };
    },

    /**
     * Sesión vigente de `token`, o `null` si la firma no es válida, el
     * token venció, la sesión no existe o se cerró. Devuelve
     * `{ sessionId, userId }`. Primero se revisa la firma: un token falso
     * no llega a consultar la base.
     */
    async resolve(token) {
      const claims = verifyToken(token, { secret, now });
      if (!claims) return null;
      const session = await store.findSessionByTokenHash(hashToken(token));
      if (!session || session.revokedAt) return null;
      if (session.userId !== claims.sub) return null;
      if (new Date(session.expiresAt).getTime() <= now().getTime()) return null;
      return { sessionId: session.id, userId: session.userId };
    },
  };
}

module.exports = { ACCESS_TOKEN_TTL_SECONDS, createSessionService, hashToken };
