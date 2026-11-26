'use strict';

const { ERROR_CODES, HttpError } = require('../errors');

/** Cualquier ruta no definida responde 404 en JSON. */
function notFound(_req, _res, next) {
  next(new HttpError(404, 'Ruta no encontrada'));
}

/** Cuerpo de error del contrato: `{ error, code, fields? }`. */
function body(error, code, fields) {
  return fields ? { error, code, fields } : { error, code };
}

/**
 * Convierte los errores en respuestas `{ error, code }`. Los inesperados
 * se registran en consola y responden 500 sin mostrar detalles internos.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, _req, res, _next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json(body(err.message, err.code, err.fields));
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json(body('JSON inválido', ERROR_CODES.INVALID_JSON));
  }
  if (err.type === 'entity.too.large') {
    return res
      .status(413)
      .json(body('Los datos enviados son demasiado grandes', ERROR_CODES.PAYLOAD_TOO_LARGE));
  }
  console.error(err);
  return res.status(500).json(body('Error interno del servidor', ERROR_CODES.INTERNAL));
}

module.exports = { notFound, errorHandler };
