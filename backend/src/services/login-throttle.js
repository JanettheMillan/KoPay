'use strict';

/**
 * Límite de intentos fallidos en el login (S4-13, HU-31, HU-34).
 *
 * Sin límite se podían probar contraseñas sin fin contra una cuenta
 * (revisión de seguridad, docs/revision-seguridad-s4-13.md, hallazgo
 * SEG-H1). No usa librerías: guarda en memoria, por correo normalizado,
 * cuántos intentos fallaron en la ventana actual.
 *
 * - Cada intento se **reserva antes** de comparar la contraseña, así que
 *   muchas peticiones en paralelo no pasan del máximo (mismo arreglo que
 *   REC-15 en la recuperación).
 * - Un login correcto borra el contador de ese correo.
 * - Cuenta igual exista o no el correo: el `429` no revela qué correos
 *   tienen cuenta.
 * - Al pasar la ventana (`windowSeconds`) el contador vuelve a cero.
 *
 * Al estar en memoria, se reinicia si la API se reinicia y vale por
 * instancia. Para la entrega hay una sola instancia en Railway (#189).
 */

const MAX_FAILURES = 10;
const WINDOW_SECONDS = 15 * 60;
/** Tope de correos guardados; al llegar se limpian las ventanas vencidas. */
const MAX_TRACKED = 10_000;

function createLoginThrottle({
  now = () => new Date(),
  maxFailures = MAX_FAILURES,
  windowSeconds = WINDOW_SECONDS,
  maxTracked = MAX_TRACKED,
} = {}) {
  const entries = new Map();

  const nowMs = () => now().getTime();

  function prune() {
    const t = nowMs();
    for (const [key, entry] of entries) {
      if (entry.resetAt <= t) entries.delete(key);
    }
    // Si siguen llenas (muchos correos distintos en la ventana), se
    // descartan las más antiguas para no crecer sin fin.
    while (entries.size >= maxTracked) {
      entries.delete(entries.keys().next().value);
    }
  }

  function current(key) {
    const entry = entries.get(key);
    if (entry && entry.resetAt > nowMs()) return entry;
    entries.delete(key);
    return null;
  }

  return {
    /**
     * Reserva un intento para [key]. Devuelve `true` si se puede comparar
     * la contraseña, o `false` si ya se llegó al máximo en la ventana.
     */
    claim(key) {
      let entry = current(key);
      if (!entry) {
        if (entries.size >= maxTracked) prune();
        entry = { count: 0, resetAt: nowMs() + windowSeconds * 1000 };
        entries.set(key, entry);
      }
      if (entry.count >= maxFailures) return false;
      entry.count += 1;
      return true;
    },

    /** Login correcto: [key] vuelve a cero. */
    succeed(key) {
      entries.delete(key);
    },

    /** Segundos que faltan para que [key] pueda intentar de nuevo (0 si ya puede). */
    retryAfter(key) {
      const entry = current(key);
      if (!entry || entry.count < maxFailures) return 0;
      return Math.max(1, Math.ceil((entry.resetAt - nowMs()) / 1000));
    },

    /** Cantidad de correos con contador (para las pruebas). */
    get size() {
      return entries.size;
    },
  };
}

module.exports = { MAX_FAILURES, MAX_TRACKED, WINDOW_SECONDS, createLoginThrottle };
