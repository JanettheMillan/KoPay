'use strict';

const fs = require('node:fs');
const path = require('node:path');
const dotenv = require('dotenv');

/**
 * Configuración de la API por ambiente (S3-02).
 *
 * Se lee una sola vez de las variables de entorno. El resto del código
 * la recibe de aquí y no lee `process.env` directamente.
 *
 * - `development` y `test` funcionan sin `.env`: usan valores locales
 *   que no sirven fuera de la computadora del desarrollador.
 * - `production` exige `DATABASE_URL`, un `JWT_SECRET` real,
 *   `CORS_ORIGIN`, el correo SMTP (S4-19) y `BANXICO_TOKEN` (S5-06); si
 *   falta alguno, el servidor no arranca.
 *
 * Los secretos van en `backend/.env` (nunca se sube) o en las variables
 * del servicio donde se despliegue. La plantilla es `.env.example`.
 */

const ENVIRONMENTS = ['development', 'test', 'production'];

/** Longitud mínima del secreto de tokens en producción. */
const MIN_SECRET_LENGTH = 32;

/** Valor de ejemplo de `.env.example`; nunca es un secreto válido. */
const EXAMPLE_SECRET = 'cambia-esto-por-un-secreto-largo';

/** Variables del correo SMTP, obligatorias en producción (S4-19). */
const SMTP_VARIABLES = ['SMTP_HOST', 'SMTP_PORT', 'SMTP_USER', 'SMTP_PASS', 'MAIL_FROM'];

/** Remitente de los correos de prueba (`jsonTransport`, no se envían). */
const LOCAL_MAIL_FROM = 'KoPay <no-reply@kopay.local>';

/** Valor de ejemplo de `BANXICO_TOKEN` en `.env.example` (S5-06). */
const EXAMPLE_BANXICO_TOKEN = 'pega-aqui-tu-token-de-banxico';

/**
 * Token del SIE de Banxico: 64 caracteres hexadecimales. Cada integrante
 * saca el suyo; nunca se comparte ni se sube.
 */
const BANXICO_TOKEN_PATTERN = /^[0-9a-f]{64}$/i;

/** Valores locales para desarrollo y pruebas, nunca para producción. */
const LOCAL_DEFAULTS = {
  development: {
    databaseUrl: 'postgres://localhost:5432/kopay',
    jwtSecret: 'solo-desarrollo-no-usar-en-produccion',
    corsOrigin: '*',
  },
  test: {
    databaseUrl: 'postgres://localhost:5432/kopay_test',
    jwtSecret: 'solo-pruebas-no-usar-en-produccion',
    corsOrigin: '*',
  },
};

/** Una variable vacía o con solo espacios cuenta como no definida. */
function read(env, name) {
  const value = env[name];
  if (value === undefined || value === null) return undefined;
  const trimmed = String(value).trim();
  return trimmed === '' ? undefined : trimmed;
}

function parsePort(raw) {
  if (raw === undefined) return 3000;
  const port = Number(raw);
  if (!/^\d+$/.test(raw) || port > 65535) {
    throw new Error(`PORT inválido: "${raw}"`);
  }
  return port;
}

/**
 * Arma la configuración a partir de [env]. Lanza un error que nombra
 * las variables que faltan o son inválidas, sin mostrar sus valores.
 */
function loadConfig(env = process.env) {
  const name = read(env, 'NODE_ENV') ?? 'development';
  if (!ENVIRONMENTS.includes(name)) {
    throw new Error(
      `NODE_ENV inválido: "${name}". Usa ${ENVIRONMENTS.join(', ')}.`,
    );
  }

  const port = parsePort(read(env, 'PORT'));
  const local = LOCAL_DEFAULTS[name] ?? {};
  const databaseUrl = read(env, 'DATABASE_URL') ?? local.databaseUrl;
  const jwtSecret = read(env, 'JWT_SECRET') ?? local.jwtSecret;
  const corsOrigin = read(env, 'CORS_ORIGIN') ?? local.corsOrigin;
  const mail = readMail(env, name);
  // Sin valor local: sin token, el tipo de cambio responde 503 (S5-06).
  const banxicoRaw = read(env, 'BANXICO_TOKEN');
  const banxicoToken = banxicoRaw === EXAMPLE_BANXICO_TOKEN ? undefined : banxicoRaw;

  if (name === 'production') {
    const problems = [];
    if (!databaseUrl) problems.push('falta DATABASE_URL');
    if (!jwtSecret) {
      problems.push('falta JWT_SECRET');
    } else if (jwtSecret === EXAMPLE_SECRET) {
      problems.push('JWT_SECRET tiene el valor de ejemplo');
    } else if (jwtSecret.length < MIN_SECRET_LENGTH) {
      problems.push(
        `JWT_SECRET debe tener al menos ${MIN_SECRET_LENGTH} caracteres`,
      );
    }
    if (!corsOrigin) {
      problems.push('falta CORS_ORIGIN');
    } else if (corsOrigin.split(',').some((o) => o.trim() === '*')) {
      // S4-13: en producción no se permite cualquier origen.
      problems.push('CORS_ORIGIN no puede ser * en producción');
    }
    for (const variable of SMTP_VARIABLES) {
      if (read(env, variable) === undefined) problems.push(`falta ${variable}`);
    }
    if (read(env, 'SMTP_PORT') !== undefined && mail.port === undefined) {
      problems.push('SMTP_PORT debe ser un número de 1 a 65535');
    }
    if (!banxicoRaw) {
      problems.push('falta BANXICO_TOKEN');
    } else if (banxicoRaw === EXAMPLE_BANXICO_TOKEN) {
      problems.push('BANXICO_TOKEN tiene el valor de ejemplo');
    } else if (!BANXICO_TOKEN_PATTERN.test(banxicoRaw)) {
      problems.push('BANXICO_TOKEN debe tener 64 caracteres hexadecimales');
    }
    if (problems.length > 0) {
      throw new Error(`Configuración de producción incompleta: ${problems.join('; ')}.`);
    }
  }

  return Object.freeze({
    env: name,
    isProduction: name === 'production',
    port,
    databaseUrl,
    jwtSecret,
    corsOrigin,
    banxicoToken,
    mail,
  });
}

/**
 * Correo de recuperación (S4-19). En `development` y `test` usa
 * `jsonTransport`: no envía nada y no necesita red. En `production`
 * usa SMTP con las variables de [SMTP_VARIABLES].
 */
function readMail(env, name) {
  if (name !== 'production') {
    return Object.freeze({ transport: 'json', from: read(env, 'MAIL_FROM') ?? LOCAL_MAIL_FROM });
  }
  const rawPort = read(env, 'SMTP_PORT');
  const port = rawPort !== undefined && /^\d+$/.test(rawPort) ? Number(rawPort) : undefined;
  return Object.freeze({
    transport: 'smtp',
    host: read(env, 'SMTP_HOST'),
    port: port !== undefined && port >= 1 && port <= 65535 ? port : undefined,
    user: read(env, 'SMTP_USER'),
    pass: read(env, 'SMTP_PASS'),
    from: read(env, 'MAIL_FROM'),
  });
}

/**
 * Carga `backend/.env` (o [file]) en [env] si existe. Las variables que
 * ya estaban definidas, por ejemplo las del servicio de despliegue,
 * tienen prioridad sobre el archivo. Devuelve si se leyó el archivo.
 */
function loadEnvFile({
  file = path.join(__dirname, '..', '..', '.env'),
  env = process.env,
} = {}) {
  if (!fs.existsSync(file)) return false;
  dotenv.config({ path: file, processEnv: env, override: false, quiet: true });
  return true;
}

/** Resumen apto para la consola: los secretos solo dicen si existen. */
function describeConfig(config) {
  return {
    env: config.env,
    port: config.port,
    corsOrigin: config.corsOrigin,
    databaseUrl: config.databaseUrl ? 'definida' : 'sin definir',
    jwtSecret: config.jwtSecret ? 'definido' : 'sin definir',
    mail:
      config.mail?.transport === 'smtp'
        ? `SMTP ${config.mail.host ? 'definido' : 'sin definir'}`
        : 'jsonTransport (sin envío real)',
    banxicoToken: config.banxicoToken ? 'definido' : 'sin definir',
  };
}

module.exports = {
  ENVIRONMENTS,
  EXAMPLE_BANXICO_TOKEN,
  EXAMPLE_SECRET,
  MIN_SECRET_LENGTH,
  SMTP_VARIABLES,
  describeConfig,
  loadConfig,
  loadEnvFile,
};
