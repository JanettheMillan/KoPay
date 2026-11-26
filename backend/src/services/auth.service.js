'use strict';

const { ERROR_CODES, HttpError } = require('../errors');
const { normalizeEmail, validateRegistration } = require('../validators/auth.validator');
const passwords = require('./password.service');

/** Rol de toda cuenta creada desde la app. Los contadores se crean fuera (S3-14). */
const DEFAULT_ROLE = 'user';

/** Datos públicos de una cuenta: nunca la contraseña ni su hash. */
function publicUser({ id, name, email, role, createdAt }) {
  return { id, name, email, role, createdAt };
}

/**
 * Cuentas de usuario (HU-30, HU-31). `passwordService` se puede
 * reemplazar en las pruebas.
 */
function createAuthService({ store, passwordService = passwords }) {
  // Hash de relleno para comparar cuando el correo no existe, así las
  // dos respuestas tardan lo mismo (contrato, sección 3.2). Se calcula
  // una sola vez, la primera vez que se necesita.
  let dummyHash;
  const getDummyHash = () => {
    dummyHash ??= passwordService.hashPassword('kopay-relleno-0');
    return dummyHash;
  };

  return {
    /**
     * Crea una cuenta con rol `user` y devuelve sus datos públicos.
     * Guarda solo el hash de la contraseña (S3-08), nunca el texto.
     * Lanza `HttpError` 400 con `fields` si los datos no son válidos y
     * 409 si el correo ya tiene cuenta. No abre sesión.
     */
    async register(body) {
      const { value, fields } = validateRegistration(body);
      if (Object.keys(fields).length > 0) {
        throw new HttpError(400, 'Revisa los datos marcados', { fields });
      }

      const { password, ...rest } = value;
      // Revisa el correo antes de calcular el hash, que es lo más lento.
      if (await store.findUserByEmail(rest.email)) throw emailTaken();
      const passwordHash = await passwordService.hashPassword(password);
      const user = await store.createUser({ ...rest, passwordHash, role: DEFAULT_ROLE });
      // Otra petición pudo registrar el mismo correo mientras tanto.
      if (!user) throw emailTaken();
      return publicUser(user);
    },

    /**
     * Revisa correo y contraseña al entrar (HU-31). Devuelve los datos
     * públicos de la cuenta o `null` si no coinciden, sin decir cuál de
     * los dos falló. El login (S3-09) arma la respuesta con esto.
     */
    async verifyCredentials(email, password) {
      const user = await store.findUserByEmail(normalizeEmail(email));
      const hash = user ? user.passwordHash : await getDummyHash();
      const ok = await passwordService.verifyPassword(
        typeof password === 'string' ? password : '',
        hash,
      );
      return user && ok ? publicUser(user) : null;
    },
  };
}

function emailTaken() {
  return new HttpError(409, 'Ya existe una cuenta con ese correo', {
    code: ERROR_CODES.EMAIL_TAKEN,
  });
}

module.exports = { DEFAULT_ROLE, createAuthService, publicUser };
