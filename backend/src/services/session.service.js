'use strict';

const { createHash, randomBytes } = require('node:crypto');

const { signToken, verifyToken } = require('./jwt');

/** Vigencia del token de acceso, en segundos (contrato, sección 3.2). */
const ACCESS_TOKEN_TTL_SECONDS = 900;

/** Vigencia del refreshToken: 30 días (contrato, sección 3.5). */
const REFRESH_TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60;
const REFRESH_TOKEN_BYTES = 32;

/** Hash con el que se guarda y se busca un token. */
function hashToken(token) {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Sesiones con JWT (S4-01) que se renuevan y se cierran (S4-02).
 *
 * - El token de acceso es un JWT HS256 firmado con `JWT_SECRET` que lleva
 *   el id del usuario (`sub`) y vence en 15 minutos.
 * - El refreshToken es texto aleatorio y opaco que vence en 30 días.
 * - De los dos solo se guarda el hash, en la misma fila de `sessions`.
 *
 * Renovar cierra la sesión (llena `revoked_at`) y abre otra con tokens
 * nuevos: un refreshToken sirve una sola vez. Cerrar sesión llena
 * `revoked_at`, así que el token de acceso deja de servir aunque su firma
 * siga vigente.
 */
function createSessionService({ store, secret, now = () => new Date() }) {
  if (!secret) throw new Error('Falta JWT_SECRET para las sesiones.');

  const later = (seconds) => new Date(now().getTime() + seconds * 1000).toISOString();

  const service = {
    /**
     * Abre una sesión para `userId`. Devuelve los tokens en claro con sus
     * vigencias, como pide el contrato (§3.2 y §3.5).
     */
    async open(userId) {
      const accessToken = signToken({
        subject: userId,
        expiresIn: ACCESS_TOKEN_TTL_SECONDS,
        secret,
        now,
      });
      const refreshToken = randomBytes(REFRESH_TOKEN_BYTES).toString('base64url');
      await store.createSession({
        userId,
        tokenHash: hashToken(accessToken),
        expiresAt: later(ACCESS_TOKEN_TTL_SECONDS),
        refreshTokenHash: hashToken(refreshToken),
        refreshExpiresAt: later(REFRESH_TOKEN_TTL_SECONDS),
      });
      return {
        accessToken,
        tokenType: 'Bearer',
        expiresIn: ACCESS_TOKEN_TTL_SECONDS,
        refreshToken,
        refreshExpiresIn: REFRESH_TOKEN_TTL_SECONDS,
      };
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

    /**
     * Renueva con `refreshToken` (S4-02). Cierra la sesión anterior y abre
     * otra. Devuelve `{ userId, tokens }`, o `null` si el refreshToken no
     * existe, venció, ya se usó o la sesión se cerró.
     */
    async refresh(refreshToken) {
      if (typeof refreshToken !== 'string' || refreshToken === '') return null;
      const session = await store.findSessionByRefreshHash(hashToken(refreshToken));
      if (!session || session.revokedAt || !session.refreshExpiresAt) return null;
      if (new Date(session.refreshExpiresAt).getTime() <= now().getTime()) return null;
      // Solo una renovación gana: si otra ya cerró esta sesión, esta no.
      if (!(await store.revokeSession(session.id))) return null;
      return { userId: session.userId, tokens: await service.open(session.userId) };
    },

    /**
     * Cierra la sesión del token de acceso `token` (S4-02). No falla si el
     * token no existe, es inválido o ya estaba cerrado: el resultado para
     * la persona es el mismo (contrato §3.4).
     */
    async close(token) {
      if (typeof token !== 'string' || token === '') return;
      const session = await store.findSessionByTokenHash(hashToken(token));
      if (session && !session.revokedAt) await store.revokeSession(session.id);
    },
  };
  return service;
}

module.exports = {
  ACCESS_TOKEN_TTL_SECONDS,
  REFRESH_TOKEN_TTL_SECONDS,
  createSessionService,
  hashToken,
};
