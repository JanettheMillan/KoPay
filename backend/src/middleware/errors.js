'use strict';

const { HttpError } = require('../errors');

/** Cualquier ruta no definida responde 404 en JSON. */
function notFound(_req, _res, next) {
  next(new HttpError(404, 'Ruta no encontrada'));
}

/**
 * Convierte los errores en respuestas `{ error }`. Los inesperados se
 * registran en consola y responden 500 sin mostrar detalles internos.
 */
// eslint-disable-next-line no-unused-vars
function errorHandler(err, _req, res, _next) {
  if (err instanceof HttpError) {
    return res.status(err.status).json({ error: err.message });
  }
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'JSON inválido' });
  }
  if (err.type === 'entity.too.large') {
    return res.status(413).json({ error: 'Los datos enviados son demasiado grandes' });
  }
  console.error(err);
  return res.status(500).json({ error: 'Error interno del servidor' });
}

module.exports = { notFound, errorHandler };
