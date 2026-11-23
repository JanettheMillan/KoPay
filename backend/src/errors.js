'use strict';

/** Error con código HTTP; el manejador lo convierte en `{ error }`. */
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

module.exports = { HttpError };
