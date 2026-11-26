'use strict';

const nodemailer = require('nodemailer');

/**
 * Envío de correos (S4-19). `nodemailer` está autorizado solo para la
 * recuperación de acceso.
 *
 * - `development` y `test`: `jsonTransport`. No sale ningún correo real ni
 *   se usa la red; el código se muestra en la consola para poder probar.
 * - `production`: SMTP con `config.mail` (SMTP_HOST, SMTP_PORT, SMTP_USER,
 *   SMTP_PASS y MAIL_FROM). El código nunca se muestra en la consola.
 */
function createTransport(mail) {
  if (mail.transport !== 'smtp') return nodemailer.createTransport({ jsonTransport: true });
  return nodemailer.createTransport({
    host: mail.host,
    port: mail.port,
    // 465 usa TLS directo; 587 empieza en claro y sube a TLS (STARTTLS).
    secure: mail.port === 465,
    requireTLS: mail.port !== 465,
    auth: { user: mail.user, pass: mail.pass },
    // Sin archivos ni URLs externas en los mensajes.
    disableFileAccess: true,
    disableUrlAccess: true,
  });
}

/** `config.mail`, o `jsonTransport` si la configuración no lo trae. */
function mailOf(config) {
  return config.mail ?? { transport: 'json', from: 'KoPay <no-reply@kopay.local>' };
}

/** Texto del correo. No incluye la contraseña ni enlaces con datos. */
function recoveryText({ name, code, minutes }) {
  return [
    `Hola, ${name}:`,
    '',
    `Tu código para recuperar el acceso a KoPay es: ${code}`,
    '',
    `Vence en ${minutes} minutos y sirve una sola vez.`,
    'Si no lo pediste, ignora este correo: tu contraseña no cambia.',
  ].join('\n');
}

/**
 * Crea el servicio de correo. `transporter` y `logger` se pueden
 * reemplazar en las pruebas.
 */
function createMailer({
  config,
  logger = console,
  transporter = createTransport(mailOf(config)),
}) {
  const { from } = mailOf(config);
  const showCode = !config.isProduction;

  return {
    /** Envía el código de recuperación a `to`. */
    async sendRecoveryCode({ to, name, code, minutes }) {
      await transporter.sendMail({
        from,
        to,
        subject: 'Tu código para recuperar el acceso a KoPay',
        text: recoveryText({ name, code, minutes }),
        disableFileAccess: true,
        disableUrlAccess: true,
      });
      if (showCode) {
        logger.log(`[correo de prueba, no se envió] Código de recuperación para ${to}: ${code}`);
      }
    },
  };
}

module.exports = { createMailer, recoveryText };
