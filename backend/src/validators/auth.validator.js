'use strict';

/**
 * Reglas del registro (docs/contrato-api-acceso.md, sección 3.1).
 * Flutter aplica las mismas antes de enviar (S3-10), pero la API decide.
 */
const MESSAGES = Object.freeze({
  nameRequired: 'Escribe tu nombre',
  nameTooLong: 'El nombre puede tener hasta 80 caracteres',
  emailInvalid: 'Escribe un correo válido',
  passwordTooShort: 'La contraseña debe tener al menos 8 caracteres',
  passwordTooLong: 'La contraseña puede tener hasta 72 caracteres',
  passwordWeak: 'La contraseña debe tener al menos una letra y un número',
  loginEmailRequired: 'Escribe tu correo',
  loginPasswordRequired: 'Escribe tu contraseña',
  codeRequired: 'Escribe el código de 6 dígitos',
  codeInvalid: 'El código no es válido o ya venció',
});

const NAME_MAX = 80;
const EMAIL_MAX = 254;
const PASSWORD_MIN = 8;
const PASSWORD_MAX = 72;

/** `texto@dominio.ext`, sin espacios ni una segunda arroba. */
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const HAS_LETTER = /\p{L}/u;
const HAS_DIGIT = /\d/;
/** Código de recuperación: exactamente 6 dígitos (S4-19). */
const CODE_PATTERN = /^\d{6}$/;

/** Correo sin espacios al inicio o al final y en minúsculas. */
function normalizeEmail(email) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

/** Longitud en caracteres, contando un emoji como uno solo. */
function length(text) {
  return [...text].length;
}

/**
 * Revisa todos los campos a la vez. Devuelve `{ value, fields }`:
 * `value` trae los datos limpios y `fields` un mensaje por cada campo
 * inválido (vacío si todo está bien). Los campos que no son de la tabla,
 * como `role`, no se copian.
 */
function validateRegistration(body) {
  const input = body !== null && typeof body === 'object' && !Array.isArray(body) ? body : {};
  const fields = {};

  const name = typeof input.name === 'string' ? input.name.trim() : '';
  if (name === '') fields.name = MESSAGES.nameRequired;
  else if (length(name) > NAME_MAX) fields.name = MESSAGES.nameTooLong;

  const email = checkEmail(input.email, fields);
  const password = checkPassword(input.password, fields);

  return { value: { name, email, password }, fields };
}

/** Correo normalizado; anota el error en [fields] si no es válido. */
function checkEmail(raw, fields) {
  const email = normalizeEmail(raw);
  if (email.length > EMAIL_MAX || !EMAIL_PATTERN.test(email)) {
    fields.email = MESSAGES.emailInvalid;
  }
  return email;
}

/**
 * Contraseña con las reglas del registro; anota el error en [fields].
 * La contraseña no se recorta: los espacios cuentan.
 */
function checkPassword(raw, fields) {
  const password = typeof raw === 'string' ? raw : '';
  if (length(password) < PASSWORD_MIN) fields.password = MESSAGES.passwordTooShort;
  else if (length(password) > PASSWORD_MAX) fields.password = MESSAGES.passwordTooLong;
  else if (!HAS_LETTER.test(password) || !HAS_DIGIT.test(password)) {
    fields.password = MESSAGES.passwordWeak;
  }
  return password;
}

/** Pedir código de recuperación (sección 3.7): solo `email`. */
function validateRecover(body) {
  const fields = {};
  const email = checkEmail(asObject(body).email, fields);
  return { value: { email }, fields };
}

/**
 * Cambiar la contraseña con el código (sección 3.8): `email`, `code` de
 * exactamente 6 dígitos y `password` con las reglas del registro.
 */
function validateReset(body) {
  const input = asObject(body);
  const fields = {};
  const email = checkEmail(input.email, fields);
  const code = typeof input.code === 'string' ? input.code.trim() : '';
  if (!CODE_PATTERN.test(code)) fields.code = MESSAGES.codeRequired;
  const password = checkPassword(input.password, fields);
  return { value: { email, code, password }, fields };
}

function asObject(body) {
  return body !== null && typeof body === 'object' && !Array.isArray(body) ? body : {};
}

/**
 * Revisa el login (sección 3.2): `email` y `password` son obligatorios,
 * sin las reglas de longitud del registro. Devuelve `{ value, fields }`.
 */
function validateLogin(body) {
  const input = body !== null && typeof body === 'object' && !Array.isArray(body) ? body : {};
  const fields = {};

  const email = normalizeEmail(input.email);
  if (email === '') fields.email = MESSAGES.loginEmailRequired;

  const password = typeof input.password === 'string' ? input.password : '';
  if (password === '') fields.password = MESSAGES.loginPasswordRequired;

  return { value: { email, password }, fields };
}

module.exports = {
  MESSAGES,
  normalizeEmail,
  validateLogin,
  validateRecover,
  validateRegistration,
  validateReset,
};
