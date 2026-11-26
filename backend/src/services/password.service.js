'use strict';

const { randomBytes, scrypt, timingSafeEqual } = require('node:crypto');
const { promisify } = require('node:util');

const scryptAsync = promisify(scrypt);

/**
 * Hash de contraseñas con scrypt, que viene en Node: no necesita
 * dependencias. Cada hash lleva su propia sal aleatoria y sus parámetros,
 * así que se pueden subir los costos sin invalidar los hashes guardados.
 *
 * Formato guardado en `users.password_hash`:
 * `scrypt$<N>$<r>$<p>$<sal base64>$<hash base64>`.
 */
const DEFAULT_PARAMS = Object.freeze({ N: 16384, r: 8, p: 1 });
const SALT_BYTES = 16;
const KEY_BYTES = 64;
const PREFIX = 'scrypt';

/** Memoria que scrypt necesita con esos parámetros, con margen. */
function maxmemFor({ N, r }) {
  return 256 * N * r;
}

/** Calcula el hash de `password` con una sal nueva. */
async function hashPassword(password, params = DEFAULT_PARAMS) {
  if (typeof password !== 'string' || password.length === 0) {
    throw new TypeError('La contraseña debe ser texto no vacío');
  }
  const { N, r, p } = params;
  const salt = randomBytes(SALT_BYTES);
  const key = await scryptAsync(password.normalize('NFC'), salt, KEY_BYTES, {
    N,
    r,
    p,
    maxmem: maxmemFor(params),
  });
  return [PREFIX, N, r, p, salt.toString('base64'), key.toString('base64')].join('$');
}

/** Lee un hash guardado, o `null` si no tiene el formato esperado. */
function parseHash(stored) {
  if (typeof stored !== 'string') return null;
  const parts = stored.split('$');
  if (parts.length !== 6 || parts[0] !== PREFIX) return null;
  const [N, r, p] = parts.slice(1, 4).map(Number);
  if (![N, r, p].every((n) => Number.isInteger(n) && n > 0)) return null;
  const salt = Buffer.from(parts[4], 'base64');
  const key = Buffer.from(parts[5], 'base64');
  if (salt.length === 0 || key.length === 0) return null;
  return { N, r, p, salt, key };
}

/**
 * `true` si `password` corresponde a `stored`. Compara en tiempo
 * constante. Un hash con formato desconocido nunca coincide.
 */
async function verifyPassword(password, stored) {
  const parsed = parseHash(stored);
  if (!parsed || typeof password !== 'string') return false;
  const { N, r, p, salt, key } = parsed;
  const candidate = await scryptAsync(password.normalize('NFC'), salt, key.length, {
    N,
    r,
    p,
    maxmem: maxmemFor({ N, r }),
  });
  return timingSafeEqual(candidate, key);
}

module.exports = { DEFAULT_PARAMS, hashPassword, parseHash, verifyPassword };
