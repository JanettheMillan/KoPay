'use strict';

const { HttpError } = require('../errors');
const { parseMonth } = require('../validators/movement.validator');

const MONTH_MESSAGE = 'Escribe el mes como AAAA-MM';

/** Suma en centavos para no arrastrar errores del punto flotante (D-06). */
const cents = (amount) => Math.round(amount * 100);
const fromCents = (value) => value / 100;

/**
 * Consultas del contador sobre las finanzas de una persona que lo
 * autorizó (S5-03, HU-39, HU-40, HU-42). Solo lectura.
 *
 * `clientId` es siempre `req.client.id`, que dejó el guardia de S4-06
 * después de comprobar el permiso vigente; nunca un id del cuerpo o de la
 * consulta. El mes es obligatorio (`?month=AAAA-MM`, UTC), igual que en
 * `/api/movements` e `/api/incomes`.
 */
function createClientFinanceService({ store }) {
  function range(query = {}) {
    const month = parseMonth(query.month);
    if (!month) throw new HttpError(400, 'Revisa los datos marcados', { fields: { month: MONTH_MESSAGE } });
    return month;
  }

  async function read(clientId, query) {
    const { from, to } = range(query);
    const [movements, incomes] = await Promise.all([
      store.listMovements({ userId: clientId, from, to }),
      store.listIncomes({ userId: clientId, from, to }),
    ]);
    return { movements, incomes };
  }

  return {
    /** Movimientos e ingresos del mes, del más reciente al más antiguo. */
    async movements(clientId, query) {
      return read(clientId, query);
    },

    /**
     * Totales del mes, con la misma regla que Inicio (HU-09, #193):
     * ingresos = ingresos + entradas positivas; gastos = movimientos
     * negativos que no son pagos; pagos aparte, para no contarlos dos
     * veces; balance = ingresos − gastos − pagos.
     */
    async summary(clientId, query) {
      const { movements, incomes } = await read(clientId, query);
      let income = incomes.reduce((sum, i) => sum + cents(i.amount), 0);
      let expenses = 0;
      let payments = 0;
      for (const m of movements) {
        if (m.type === 'payment') payments += Math.abs(cents(m.amount));
        else if (m.amount < 0) expenses += Math.abs(cents(m.amount));
        else income += cents(m.amount);
      }
      return {
        month: query.month,
        balance: fromCents(income - expenses - payments),
        income: fromCents(income),
        expenses: fromCents(expenses),
        payments: fromCents(payments),
      };
    },
  };
}

module.exports = { MONTH_MESSAGE, createClientFinanceService };
