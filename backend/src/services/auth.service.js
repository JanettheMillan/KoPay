'use strict';

const { ERROR_CODES, HttpError } = require('../errors');
const { validateRegistration } = require('../validators/auth.validator');

/** Rol de toda cuenta creada desde la app. Los contadores se crean fuera (S3-14). */
const DEFAULT_ROLE = 'user';

/** Datos públicos de una cuenta: nunca la contraseña ni su hash. */
function publicUser({ id, name, email, role, createdAt }) {
  return { id, name, email, role, createdAt };
}

/** Cuentas de usuario (HU-30). El login (S3-09) se agrega aquí. */
function createAuthService({ store }) {
  return {
    /**
     * Crea una cuenta con rol `user` y devuelve sus datos públicos.
     * Lanza `HttpError` 400 con `fields` si los datos no son válidos y
     * 409 si el correo ya tiene cuenta. No abre sesión.
     */
    async register(body) {
      const { value, fields } = validateRegistration(body);
      if (Object.keys(fields).length > 0) {
        throw new HttpError(400, 'Revisa los datos marcados', { fields });
      }

      // S3-08 cambia `password` por su hash antes de guardarla.
      const user = await store.createUser({ ...value, role: DEFAULT_ROLE });
      if (!user) {
        throw new HttpError(409, 'Ya existe una cuenta con ese correo', {
          code: ERROR_CODES.EMAIL_TAKEN,
        });
      }
      return publicUser(user);
    },
  };
}

module.exports = { DEFAULT_ROLE, createAuthService, publicUser };
