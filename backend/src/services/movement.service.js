'use strict';

const { ERROR_CODES, HttpError } = require('../errors');
const { ensureOwned } = require('../middleware/owner');
const { MESSAGES, parseMonth, validateMovement } = require('../validators/movement.validator');

const CONFLICT_MESSAGE = 'El movimiento cambió en otro dispositivo. Vuelve a cargarlo.';

function invalid(fields) {
  return new HttpError(400, 'Revisa los datos marcados', { fields });
}

function conflict() {
  return new HttpError(409, CONFLICT_MESSAGE, { code: ERROR_CODES.VERSION_CONFLICT });
}

/**
 * Movimientos de la cuenta (S5-01, HU-01, HU-05, HU-06, HU-07, HU-08).
 * Cada método recibe primero `ownerId`, que viene de la sesión (S4-03):
 * nunca se usa un dueño que mande la app.
 *
 * Los pagos (`type = payment`) se leen aquí, pero se crean, cambian y
 * borran desde su tarjeta o deuda (S5-05), para que el saldo no quede
 * desfasado (S2-15).
 */
function createMovementService({ store }) {
  async function owned(ownerId, id) {
    return ensureOwned(await store.findMovementById(id), ownerId);
  }

  return {
    /** Movimientos de la cuenta, del más reciente al más antiguo; `?month=AAAA-MM` filtra. */
    async list(ownerId, query = {}) {
      let range = {};
      if (query.month !== undefined) {
        range = parseMonth(query.month);
        if (!range) throw invalid({ month: 'Escribe el mes como AAAA-MM' });
      }
      return store.listMovements({ userId: ownerId, ...range });
    },

    /** Un movimiento propio; `404` si no existe o es de otra cuenta. */
    async get(ownerId, id) {
      return owned(ownerId, id);
    },

    /** Crea un movimiento normal (gasto o entrada). */
    async create(ownerId, body) {
      const { value, fields } = validateMovement(body);
      if (Object.keys(fields).length > 0) throw invalid(fields);
      return store.createMovement({ userId: ownerId, ...value });
    },

    /**
     * Cambia un movimiento propio. Si llega `version` y ya no es la
     * guardada, responde `409 VERSION_CONFLICT` sin cambiar nada (HU-36).
     */
    async update(ownerId, id, body) {
      const current = await owned(ownerId, id);
      if (current.type === 'payment') throw invalid({ type: MESSAGES.paymentNotHere });
      const { value, fields } = validateMovement(body);
      if (Object.keys(fields).length > 0) throw invalid(fields);
      if (value.version !== undefined && value.version !== current.version) throw conflict();
      const updated = await store.updateMovement({
        id,
        userId: ownerId,
        expectedVersion: current.version,
        ...value,
      });
      // Otra petición lo cambió entre la lectura y la escritura.
      if (!updated) throw conflict();
      return updated;
    },

    /** Borra un movimiento propio (HU-06). */
    async remove(ownerId, id) {
      const current = await owned(ownerId, id);
      if (current.type === 'payment') throw invalid({ type: MESSAGES.paymentNotHere });
      await store.deleteMovement({ id, userId: ownerId });
    },
  };
}

module.exports = { CONFLICT_MESSAGE, createMovementService };
