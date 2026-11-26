'use strict';

/**
 * Reglas de un movimiento en la API (S5-01, HU-01, HU-04, HU-05).
 * Son las mismas que aplica la app en `lib/utils/validators.dart` y
 * `add_movement_sheet.dart`; la API es la que decide.
 */

const MESSAGES = Object.freeze({
  amountRequired: 'Escribe un monto',
  amountInvalid: 'Escribe un monto válido, por ejemplo 150.50',
  amountZero: 'El monto no puede ser cero',
  amountTooLarge: 'El monto es demasiado grande',
  amountDecimals: 'Usa máximo dos decimales',
  descriptionRequired: 'Escribe una descripción',
  descriptionTooLong: 'La descripción puede tener hasta 60 caracteres',
  categoryRequired: 'Elige una categoría',
  categoryTooLong: 'La categoría puede tener hasta 30 caracteres',
  dateInvalid: 'Escribe una fecha válida (AAAA-MM-DD)',
  noteTooLong: 'La nota puede tener hasta 140 caracteres',
  versionInvalid: 'La versión debe ser un número entero mayor que cero',
  paymentNotHere: 'Los pagos se registran desde su tarjeta o deuda',
});

const MAX_AMOUNT = 999999999.99;
const DESCRIPTION_MAX = 60;
const CATEGORY_MAX = 30;
const NOTE_MAX = 140;

/** `AAAA-MM-DD` o fecha y hora ISO 8601. */
const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,6})?)?(?:Z|[+-]\d{2}:?\d{2})?)?$/;
const MONTH_PATTERN = /^(\d{4})-(\d{2})$/;

const length = (text) => [...text].length;

/**
 * Fecha real o `null`. Rechaza fechas imposibles como `2026-02-30`, igual
 * que la app desde D-03. Una fecha sin hora se guarda a las 00:00 UTC.
 */
function parseDate(value) {
  if (typeof value !== 'string') return null;
  const match = DATE_PATTERN.exec(value.trim());
  if (!match) return null;
  const [, y, m, d, hh = '0', mm = '0', ss = '0'] = match;
  const year = Number(y);
  const month = Number(m);
  const day = Number(d);
  if (month < 1 || month > 12) return null;
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (day < 1 || day > daysInMonth) return null;
  if (Number(hh) > 23 || Number(mm) > 59 || Number(ss) > 59) return null;
  const parsed = new Date(match[4] === undefined ? `${y}-${m}-${d}T00:00:00Z` : value.trim());
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/** Primer y último instante (UTC) de `AAAA-MM`, o `null`. */
function parseMonth(value) {
  const match = MONTH_PATTERN.exec(typeof value === 'string' ? value : '');
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  if (month < 1 || month > 12) return null;
  return {
    from: new Date(Date.UTC(year, month - 1, 1)),
    to: new Date(Date.UTC(year, month, 1)),
  };
}

function checkAmount(value) {
  if (value === undefined || value === null || value === '') return MESSAGES.amountRequired;
  if (typeof value !== 'number' || !Number.isFinite(value)) return MESSAGES.amountInvalid;
  if (value === 0) return MESSAGES.amountZero;
  if (Math.abs(value) > MAX_AMOUNT) return MESSAGES.amountTooLarge;
  // Dos decimales como máximo, comparando en centavos (D-06).
  if (Math.abs(Math.round(value * 100) - value * 100) > 1e-6) return MESSAGES.amountDecimals;
  return null;
}

/**
 * Revisa todos los campos a la vez. Devuelve `{ value, fields }`. Los
 * campos que no son de un movimiento (`id`, `userId`, `type`, `cardId`…)
 * no se copian: el dueño sale de la sesión y los pagos van por S5-05.
 */
function validateMovement(body) {
  const input = body !== null && typeof body === 'object' && !Array.isArray(body) ? body : {};
  const fields = {};

  const amountError = checkAmount(input.amount);
  if (amountError) fields.amount = amountError;

  const description = typeof input.description === 'string' ? input.description.trim() : '';
  if (description === '') fields.description = MESSAGES.descriptionRequired;
  else if (length(description) > DESCRIPTION_MAX) fields.description = MESSAGES.descriptionTooLong;

  const category = typeof input.category === 'string' ? input.category.trim() : '';
  if (category === '') fields.category = MESSAGES.categoryRequired;
  else if (length(category) > CATEGORY_MAX) fields.category = MESSAGES.categoryTooLong;

  const date = parseDate(input.date);
  if (!date) fields.date = MESSAGES.dateInvalid;

  let note = null;
  if (input.note !== undefined && input.note !== null) {
    note = typeof input.note === 'string' ? input.note.trim() : '';
    if (length(note) > NOTE_MAX) fields.note = MESSAGES.noteTooLong;
    if (note === '') note = null;
  }

  if (input.type !== undefined && input.type !== 'regular') {
    fields.type = MESSAGES.paymentNotHere;
  }

  let version;
  if (input.version !== undefined) {
    if (!Number.isInteger(input.version) || input.version < 1) fields.version = MESSAGES.versionInvalid;
    else version = input.version;
  }

  return {
    value: { amount: input.amount, description, category, date, note, version },
    fields,
  };
}

module.exports = { MAX_AMOUNT, MESSAGES, parseDate, parseMonth, validateMovement };
