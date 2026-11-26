'use strict';

const { ERROR_CODES, HttpError } = require('../errors');
const {
  normalizeEmail,
  validateLogin,
  validateRegistration,
} = require('../validators/auth.validator');
const passwords = require('./password.service');

/** Rol de toda cuenta creada desde la app. Los contadores se crean fuera (S3-14). */
const DEFAULT_ROLE = 'user';

/** Datos públicos de una cuenta: nunca la contraseña ni su hash. */
function publicUser({ id, name, email, role, createdAt }) {
  return { id, name, email, role, createdAt };
}

/** Mensaje igual para correo inexistente y contraseña incorrecta. */
const INVALID_CREDENTIALS_MESSAGE = 'Correo o contraseña incorrectos';

/**
 * Cuentas de usuario (HU-30, HU-31). `passwordService` se puede
 * reemplazar en las pruebas. `sessionService` abre la sesión del login.
 */
function createAuthService({ store, passwordService = passwords, sessionService }) {
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

    /**
     * Inicia sesión (HU-31, S3-09). Devuelve `{ accessToken, tokenType,
     * expiresIn, user }`. Lanza `HttpError` 400 con `fields` si falta un
     * campo y 401 `INVALID_CREDENTIALS`, con el mismo cuerpo, si el correo
     * no existe o la contraseña no coincide.
     */
    async login(body) {
      const { value, fields } = validateLogin(body);
      if (Object.keys(fields).length > 0) {
        throw new HttpError(400, 'Revisa los datos marcados', { fields });
      }
      const user = await this.verifyCredentials(value.email, value.password);
      if (!user) {
        throw new HttpError(401, INVALID_CREDENTIALS_MESSAGE, {
          code: ERROR_CODES.INVALID_CREDENTIALS,
        });
      }
      const session = await sessionService.open(user.id);
      return { ...session, user };
    },

    /**
     * Renueva la sesión con `refreshToken` (S4-02, contrato §3.5). Responde
     * igual que el login, con tokens nuevos; el refreshToken usado deja de
     * servir. Lanza `HttpError` 400 si falta y 401 `UNAUTHENTICATED` si no
     * es válido, venció, ya se usó o la cuenta ya no existe.
     */
    async refresh(body) {
      const token =
        body !== null && typeof body === 'object' ? body.refreshToken : undefined;
      if (typeof token !== 'string' || token.trim() === '') {
        throw new HttpError(400, 'Revisa los datos marcados', {
          fields: { refreshToken: REFRESH_TOKEN_REQUIRED },
        });
      }
      const renewed = await sessionService.refresh(token);
      const user = renewed ? await store.findUserById(renewed.userId) : null;
      if (!user) {
        throw new HttpError(401, UNAUTHENTICATED_MESSAGE, {
          code: ERROR_CODES.UNAUTHENTICATED,
        });
      }
      return { ...renewed.tokens, user: publicUser(user) };
    },

    /**
     * Cuenta de la sesión actual (`GET /api/auth/me`), o `null` si la
     * cuenta ya no existe.
     */
    async currentUser(userId) {
      const user = await store.findUserById(userId);
      return user ? publicUser(user) : null;
    },
  };
}

/** Mensajes de la renovación (contrato §3.5). */
const REFRESH_TOKEN_REQUIRED = 'Falta el refreshToken';
const UNAUTHENTICATED_MESSAGE = 'Inicia sesión para continuar';

function emailTaken() {
  return new HttpError(409, 'Ya existe una cuenta con ese correo', {
    code: ERROR_CODES.EMAIL_TAKEN,
  });
}

module.exports = { DEFAULT_ROLE, INVALID_CREDENTIALS_MESSAGE, createAuthService, publicUser };
