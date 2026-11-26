'use strict';

const { createHmac, randomBytes, timingSafeEqual } = require('node:crypto');

/**
 * JSON Web Tokens firmados con HS256 (S4-01, HU-31, HU-34), con
 * `node:crypto` y sin librerías externas.
 *
 * Solo se acepta exactamente `{"alg":"HS256","typ":"JWT"}`: un token con
 * `alg: none` u otro algoritmo se rechaza aunque su firma "coincida".
 * La firma se compara en tiempo constante y en su forma canónica.
 */

const HEADER = Object.freeze({ alg: 'HS256', typ: 'JWT' });
const ENCODED_HEADER = base64url(JSON.stringify(HEADER));
const SEGMENT = /^[A-Za-z0-9_-]+$/;

function base64url(text) {
  return Buffer.from(text).toString('base64url');
}

function signature(data, secret) {
  return createHmac('sha256', secret).update(data).digest('base64url');
}

function parseJson(segment) {
  try {
    const value = JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
    return value !== null && typeof value === 'object' && !Array.isArray(value)
      ? value
      : null;
  } catch {
    return null;
  }
}

/**
 * Firma un token para el usuario [subject] que vence en [expiresIn]
 * segundos. Lleva `sub`, `jti` (aleatorio, para que dos sesiones nunca
 * compartan token), `iat` y `exp`.
 */
function signToken({ subject, expiresIn, secret, now = () => new Date() }) {
  if (!secret) throw new Error('Falta JWT_SECRET para firmar tokens.');
  if (typeof subject !== 'string' || subject === '') {
    throw new TypeError('El token necesita el id del usuario en subject.');
  }
  const iat = Math.floor(now().getTime() / 1000);
  const payload = {
    sub: subject,
    jti: randomBytes(16).toString('base64url'),
    iat,
    exp: iat + expiresIn,
  };
  const data = `${ENCODED_HEADER}.${base64url(JSON.stringify(payload))}`;
  return `${data}.${signature(data, secret)}`;
}

/**
 * Verifica [token]. Devuelve su contenido (`{ sub, jti, iat, exp }`) si
 * la firma es válida, el encabezado es HS256 y no ha vencido; si no,
 * devuelve `null`. Nunca lanza por un token mal formado.
 */
function verifyToken(token, { secret, now = () => new Date() }) {
  if (!secret || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 3 || !parts.every((p) => SEGMENT.test(p))) return null;
  const [header, payload, sig] = parts;

  if (header !== ENCODED_HEADER) return null;
  const expected = Buffer.from(signature(`${header}.${payload}`, secret));
  const given = Buffer.from(sig);
  if (given.length !== expected.length || !timingSafeEqual(given, expected)) {
    return null;
  }

  const claims = parseJson(payload);
  if (!claims) return null;
  const { sub, jti, iat, exp } = claims;
  if (typeof sub !== 'string' || sub === '') return null;
  if (typeof jti !== 'string' || jti === '') return null;
  if (!Number.isInteger(iat) || !Number.isInteger(exp)) return null;
  if (exp <= Math.floor(now().getTime() / 1000)) return null;
  return { sub, jti, iat, exp };
}

module.exports = { HEADER, signToken, verifyToken };
