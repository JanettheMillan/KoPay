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
});

const NAME_MAX = 80;
const EMAIL_MAX = 254;
const PASSWORD_MIN = 8;
const PASSWORD_MAX = 72;

/** `texto@dominio.ext`, sin espacios ni una segunda arroba. */
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const HAS_LETTER = /\p{L}/u;
const HAS_DIGIT = /\d/;

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

  const email = normalizeEmail(input.email);
  if (email.length > EMAIL_MAX || !EMAIL_PATTERN.test(email)) {
    fields.email = MESSAGES.emailInvalid;
  }

  // La contraseña no se recorta: los espacios cuentan.
  const password = typeof input.password === 'string' ? input.password : '';
  if (length(password) < PASSWORD_MIN) fields.password = MESSAGES.passwordTooShort;
  else if (length(password) > PASSWORD_MAX) fields.password = MESSAGES.passwordTooLong;
  else if (!HAS_LETTER.test(password) || !HAS_DIGIT.test(password)) {
    fields.password = MESSAGES.passwordWeak;
  }

  return { value: { name, email, password }, fields };
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

module.exports = { MESSAGES, normalizeEmail, validateLogin, validateRegistration };
