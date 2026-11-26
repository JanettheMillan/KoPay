'use strict';

/**
 * Códigos de error estables del contrato (docs/contrato-api-acceso.md).
 * Flutter decide qué hacer con `code`; `error` es el texto para mostrar.
 */
const ERROR_CODES = Object.freeze({
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  INVALID_JSON: 'INVALID_JSON',
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  UNAUTHENTICATED: 'UNAUTHENTICATED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  EMAIL_TAKEN: 'EMAIL_TAKEN',
  PAYLOAD_TOO_LARGE: 'PAYLOAD_TOO_LARGE',
  TOO_MANY_ATTEMPTS: 'TOO_MANY_ATTEMPTS',
  INTERNAL: 'INTERNAL',
  UNAVAILABLE: 'UNAVAILABLE',
  VERSION_CONFLICT: 'VERSION_CONFLICT',
});

/** Código por defecto para cada estado HTTP. */
const DEFAULT_CODE = {
  400: ERROR_CODES.VALIDATION_FAILED,
  401: ERROR_CODES.UNAUTHENTICATED,
  403: ERROR_CODES.FORBIDDEN,
  404: ERROR_CODES.NOT_FOUND,
  409: ERROR_CODES.EMAIL_TAKEN,
  413: ERROR_CODES.PAYLOAD_TOO_LARGE,
  429: ERROR_CODES.TOO_MANY_ATTEMPTS,
  503: ERROR_CODES.UNAVAILABLE,
};

/**
 * Error con código HTTP; el manejador lo convierte en
 * `{ error, code, fields? }`. `fields` lleva un mensaje por campo
 * inválido, por ejemplo `{ email: 'Correo no válido' }`.
 */
class HttpError extends Error {
  constructor(status, message, { code, fields } = {}) {
    super(message);
    this.status = status;
    this.code = code ?? DEFAULT_CODE[status] ?? ERROR_CODES.INTERNAL;
    if (fields) this.fields = fields;
  }
}

module.exports = { ERROR_CODES, HttpError };
