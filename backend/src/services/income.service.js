'use strict';

const { ERROR_CODES, HttpError } = require('../errors');
const { ensureOwned } = require('../middleware/owner');
const { validateIncome } = require('../validators/income.validator');
const { parseMonth } = require('../validators/movement.validator');

const CONFLICT_MESSAGE = 'El ingreso cambió en otro dispositivo. Vuelve a cargarlo.';

function invalid(fields) {
  return new HttpError(400, 'Revisa los datos marcados', { fields });
}

function conflict() {
  return new HttpError(409, CONFLICT_MESSAGE, { code: ERROR_CODES.VERSION_CONFLICT });
}

/**
 * Ingresos de la cuenta (S5-02, HU-02, HU-09). Sigue el patrón de S5-01:
 * cada método recibe primero `ownerId`, que viene de la sesión (S4-03), y
 * nunca se usa un dueño que mande la app.
 */
function createIncomeService({ store }) {
  async function owned(ownerId, id) {
    return ensureOwned(await store.findIncomeById(id), ownerId);
  }

  return {
    /** Ingresos de la cuenta, del más reciente al más antiguo; `?month=AAAA-MM` filtra. */
    async list(ownerId, query = {}) {
      let range = {};
      if (query.month !== undefined) {
        range = parseMonth(query.month);
        if (!range) throw invalid({ month: 'Escribe el mes como AAAA-MM' });
      }
      return store.listIncomes({ userId: ownerId, ...range });
    },

    /** Un ingreso propio; `404` si no existe o es de otra cuenta. */
    async get(ownerId, id) {
      return owned(ownerId, id);
    },

    /** Registra un ingreso (HU-02). */
    async create(ownerId, body) {
      const { value, fields } = validateIncome(body);
      if (Object.keys(fields).length > 0) throw invalid(fields);
      return store.createIncome({ userId: ownerId, ...value });
    },

    /**
     * Cambia un ingreso propio. Si llega `version` y ya no es la guardada,
     * responde `409 VERSION_CONFLICT` sin cambiar nada (HU-36).
     */
    async update(ownerId, id, body) {
      const current = await owned(ownerId, id);
      const { value, fields } = validateIncome(body);
      if (Object.keys(fields).length > 0) throw invalid(fields);
      if (value.version !== undefined && value.version !== current.version) throw conflict();
      const updated = await store.updateIncome({
        id,
        userId: ownerId,
        expectedVersion: current.version,
        ...value,
      });
      // Otra petición lo cambió entre la lectura y la escritura.
      if (!updated) throw conflict();
      return updated;
    },

    /** Borra un ingreso propio. */
    async remove(ownerId, id) {
      await owned(ownerId, id);
      await store.deleteIncome({ id, userId: ownerId });
    },
  };
}

module.exports = { CONFLICT_MESSAGE, createIncomeService };
