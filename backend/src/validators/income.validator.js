'use strict';

/**
 * Reglas de un ingreso en la API (S5-02, HU-02). Son las mismas que aplica
 * la app en `lib/utils/validators.dart` (`checkIncome`) y
 * `add_income_sheet.dart`; la API es la que decide. La fecha y el mes se
 * leen igual que en los movimientos (S5-01).
 */

const { MAX_AMOUNT, MESSAGES: MOVEMENT_MESSAGES, parseDate } = require('./movement.validator');

const MESSAGES = Object.freeze({
  amountRequired: MOVEMENT_MESSAGES.amountRequired,
  amountInvalid: MOVEMENT_MESSAGES.amountInvalid,
  amountNotPositive: 'El monto debe ser mayor que cero',
  amountTooLarge: MOVEMENT_MESSAGES.amountTooLarge,
  amountDecimals: MOVEMENT_MESSAGES.amountDecimals,
  nameRequired: 'Escribe el nombre del ingreso',
  nameTooLong: 'El nombre puede tener hasta 60 caracteres',
  dateInvalid: MOVEMENT_MESSAGES.dateInvalid,
  noteTooLong: MOVEMENT_MESSAGES.noteTooLong,
  versionInvalid: MOVEMENT_MESSAGES.versionInvalid,
});

const NAME_MAX = 60;
const NOTE_MAX = 140;

const length = (text) => [...text].length;

function checkAmount(value) {
  if (value === undefined || value === null || value === '') return MESSAGES.amountRequired;
  if (typeof value !== 'number' || !Number.isFinite(value)) return MESSAGES.amountInvalid;
  if (value <= 0) return MESSAGES.amountNotPositive;
  if (value > MAX_AMOUNT) return MESSAGES.amountTooLarge;
  // Dos decimales como máximo, comparando en centavos (D-06).
  if (Math.abs(Math.round(value * 100) - value * 100) > 1e-6) return MESSAGES.amountDecimals;
  return null;
}

/**
 * Revisa todos los campos a la vez. Devuelve `{ value, fields }`. Los
 * campos que no son de un ingreso (`id`, `userId`, `category`…) no se
 * copian: el dueño sale de la sesión (S4-03).
 */
function validateIncome(body) {
  const input = body !== null && typeof body === 'object' && !Array.isArray(body) ? body : {};
  const fields = {};

  const amountError = checkAmount(input.amount);
  if (amountError) fields.amount = amountError;

  const name = typeof input.name === 'string' ? input.name.trim() : '';
  if (name === '') fields.name = MESSAGES.nameRequired;
  else if (length(name) > NAME_MAX) fields.name = MESSAGES.nameTooLong;

  const date = parseDate(input.date);
  if (!date) fields.date = MESSAGES.dateInvalid;

  let note = null;
  if (input.note !== undefined && input.note !== null) {
    note = typeof input.note === 'string' ? input.note.trim() : '';
    if (length(note) > NOTE_MAX) fields.note = MESSAGES.noteTooLong;
    if (note === '') note = null;
  }

  let version;
  if (input.version !== undefined) {
    if (!Number.isInteger(input.version) || input.version < 1) fields.version = MESSAGES.versionInvalid;
    else version = input.version;
  }

  return { value: { name, amount: input.amount, date, note, version }, fields };
}

module.exports = { MESSAGES, validateIncome };
