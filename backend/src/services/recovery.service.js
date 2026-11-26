'use strict';

const { createHmac, randomInt, timingSafeEqual } = require('node:crypto');

const { ERROR_CODES, HttpError } = require('../errors');
const { MESSAGES, validateRecover, validateReset } = require('../validators/auth.validator');
const passwords = require('./password.service');

/** Vigencia del código, en minutos (contrato, sección 3.7). */
const CODE_TTL_MINUTES = 15;
/** Intentos fallidos que admite un código (contrato, sección 3.8). */
const MAX_ATTEMPTS = 5;
/** Un correo de recuperación por minuto por cuenta (CON-28). */
const RESEND_INTERVAL_SECONDS = 60;

/** Respuesta de `recover`, igual exista o no la cuenta. */
const RECOVER_MESSAGE = 'Si el correo tiene una cuenta, te enviamos un código. Vence en 15 minutos.';
const TOO_MANY_MESSAGE = 'Demasiados intentos. Pide un código nuevo.';

/** Código de 6 dígitos al azar; los ceros a la izquierda cuentan. */
function generateCode() {
  return String(randomInt(0, 1_000_000)).padStart(6, '0');
}

/**
 * Recuperación de acceso (HU-32, S4-19): código de 6 dígitos por correo,
 * vence en 15 minutos, sirve una vez y admite 5 intentos.
 *
 * El código se guarda como HMAC-SHA256 con [secret] y el `id` de la
 * cuenta: aunque alguien lea la base, no puede probar el millón de
 * códigos sin el secreto del servidor.
 */
function createRecoveryService({
  store,
  mailer,
  secret,
  passwordService = passwords,
  now = () => new Date(),
  logger = console,
}) {
  // En producción `JWT_SECRET` es obligatorio (S3-02). Sin secreto no se
  // puede guardar ni comprobar un código: falla al usarse, no al crearse.
  const hashCode = (userId, code) => {
    if (!secret) throw new Error('La recuperación de acceso necesita un secreto.');
    return createHmac('sha256', secret).update(`${userId}:${code}`).digest('hex');
  };

  const sameHash = (a, b) =>
    a.length === b.length && timingSafeEqual(Buffer.from(a), Buffer.from(b));

  /** `true` si a esa cuenta se le envió un código hace menos de un minuto. */
  const sentRecently = async (userId) => {
    const latest = await store.findLatestPasswordReset(userId);
    if (!latest) return false;
    return now().getTime() - new Date(latest.createdAt).getTime() < RESEND_INTERVAL_SECONDS * 1000;
  };

  const invalidCode = () =>
    new HttpError(400, 'Revisa los datos marcados', {
      fields: { code: MESSAGES.codeInvalid },
    });

  return {
    /**
     * `POST /api/auth/recover`. Si la cuenta existe guarda el hash de un
     * código nuevo (borra los anteriores) y lo envía por correo sin
     * esperar el envío. Devuelve el mismo mensaje exista o no.
     */
    async recover(body) {
      const { value, fields } = validateRecover(body);
      if (Object.keys(fields).length > 0) {
        throw new HttpError(400, 'Revisa los datos marcados', { fields });
      }

      const user = await store.findUserByEmail(value.email);
      if (user && (await sentRecently(user.id))) {
        // Un correo por minuto por cuenta (CON-28). Misma respuesta, para
        // no revelar que la cuenta existe; el código anterior sigue valiendo.
        return { message: RECOVER_MESSAGE };
      }
      if (user) {
        const code = generateCode();
        const expiresAt = new Date(now().getTime() + CODE_TTL_MINUTES * 60_000);
        await store.createPasswordReset({
          userId: user.id,
          codeHash: hashCode(user.id, code),
          expiresAt: expiresAt.toISOString(),
        });
        // La respuesta no espera el correo, para tardar lo mismo que sin
        // cuenta. Una falla se registra sin el correo ni el código.
        Promise.resolve()
          .then(() =>
            mailer.sendRecoveryCode({
              to: user.email,
              name: user.name,
              code,
              minutes: CODE_TTL_MINUTES,
            }),
          )
          .catch(() => logger.error('No se pudo enviar el correo de recuperación.'));
      }
      return { message: RECOVER_MESSAGE };
    },

    /**
     * `POST /api/auth/reset`. Cambia la contraseña con el código, lo marca
     * usado y cierra todas las sesiones. Lanza `HttpError` 400 si un campo
     * no es válido o el código no sirve (misma respuesta en todos los
     * casos) y 429 si el código ya tuvo 5 intentos fallidos.
     */
    async reset(body) {
      const { value, fields } = validateReset(body);
      if (Object.keys(fields).length > 0) {
        throw new HttpError(400, 'Revisa los datos marcados', { fields });
      }

      const user = await store.findUserByEmail(value.email);
      if (!user) throw invalidCode();
      const reset = await store.findLatestPasswordReset(user.id);
      if (!reset || reset.usedAt !== null) throw invalidCode();
      if (new Date(reset.expiresAt).getTime() <= now().getTime()) throw invalidCode();
      if (reset.attempts >= MAX_ATTEMPTS) {
        throw new HttpError(429, TOO_MANY_MESSAGE, { code: ERROR_CODES.TOO_MANY_ATTEMPTS });
      }

      if (!sameHash(hashCode(user.id, value.code), reset.codeHash)) {
        await store.recordPasswordResetFailure(reset.id);
        throw invalidCode();
      }

      const passwordHash = await passwordService.hashPassword(value.password);
      const done = await store.completePasswordReset({
        resetId: reset.id,
        userId: user.id,
        passwordHash,
      });
      // Otra petición usó el mismo código mientras tanto.
      if (!done) throw invalidCode();
    },
  };
}

module.exports = {
  CODE_TTL_MINUTES,
  MAX_ATTEMPTS,
  RESEND_INTERVAL_SECONDS,
  RECOVER_MESSAGE,
  TOO_MANY_MESSAGE,
  createRecoveryService,
  generateCode,
};
