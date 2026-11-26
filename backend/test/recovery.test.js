// S4-19 · Recuperación segura de acceso (HU-32).
//
// CON-17 a CON-26 y CON-28 son los casos de docs/contrato-api-acceso.md
// (sección 5). REC-01 a REC-08 son pruebas nuevas de esta tarjeta,
// anotadas en el PR. El correo se reemplaza por uno falso que guarda el
// código: no se usa la red.

const request = require('supertest');

const { loadConfig } = require('../src/config');
const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { createMailer } = require('../src/services/mail.service');
const {
  RECOVER_MESSAGE,
  createRecoveryService,
  generateCode,
} = require('../src/services/recovery.service');
const { MESSAGES } = require('../src/validators/auth.validator');

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };
const codigoInvalido = {
  error: 'Revisa los datos marcados',
  code: 'VALIDATION_FAILED',
  fields: { code: MESSAGES.codeInvalid },
};

/** Correo falso: guarda cada envío para leer el código en la prueba. */
function fakeMailer() {
  const sent = [];
  return {
    sent,
    async sendRecoveryCode(message) {
      sent.push(message);
    },
    /** Último código enviado a `to`. */
    lastCode(to = 'ana@mail.com') {
      return [...sent].reverse().find((m) => m.to === to)?.code;
    },
  };
}

/** Espera a que corran las tareas pendientes (el envío no se espera). */
const flush = () => new Promise((resolve) => setImmediate(resolve));

async function setup() {
  let ahora = new Date('2026-11-26T18:00:00.000Z');
  const clock = () => ahora;
  const store = createMemoryStore({ now: clock });
  const mailer = fakeMailer();
  const app = createApp({ config: loadConfig({ NODE_ENV: 'test' }), store, now: clock, mailer });
  const api = request(app);
  await api.post('/api/auth/register').send(ana).expect(201);

  const recover = async (email = 'ana@mail.com') => {
    const res = await api.post('/api/auth/recover').send({ email });
    await flush();
    return res;
  };
  return {
    api,
    store,
    mailer,
    recover,
    reset: (body) => api.post('/api/auth/reset').send({ email: 'ana@mail.com', password: 'nueva2026', ...body }),
    login: (password) => api.post('/api/auth/login').send({ email: 'ana@mail.com', password }),
    me: (token) => api.get('/api/auth/me').set('Authorization', `Bearer ${token}`),
    adelantar: (minutos) => {
      ahora = new Date(ahora.getTime() + minutos * 60_000);
    },
  };
}

/** Un código distinto de `code`, también de 6 dígitos. */
const otro = (code) => String((Number(code) + 1) % 1_000_000).padStart(6, '0');

describe('POST /api/auth/recover', () => {
  test('CON-17 · HU-32 · con cuenta y sin cuenta responde lo mismo; solo se envía a la que existe', async () => {
    const { mailer, recover } = await setup();

    const existe = await recover('ana@mail.com');
    const noExiste = await recover('nadie@mail.com');

    expect(existe.status).toBe(200);
    expect(noExiste.status).toBe(200);
    expect(existe.body).toEqual({ message: RECOVER_MESSAGE });
    expect(noExiste.body).toEqual(existe.body);
    expect(mailer.sent).toHaveLength(1);
    expect(mailer.sent[0]).toMatchObject({ to: 'ana@mail.com', name: 'Ana López', minutes: 15 });
    expect(mailer.sent[0].code).toMatch(/^\d{6}$/);
  });

  test('CON-18 · HU-32 · sin correo o con un correo mal formado → 400 con fields.email', async () => {
    const { mailer, recover } = await setup();

    for (const email of [null, '', 'ana@mail', 'ana mail.com']) {
      const res = await recover(email);
      expect(res.status).toBe(400);
      expect(res.body).toEqual({
        error: 'Revisa los datos marcados',
        code: 'VALIDATION_FAILED',
        fields: { email: MESSAGES.emailInvalid },
      });
    }
    expect(mailer.sent).toHaveLength(0);
  });

  test('REC-01 · HU-32 · el correo se normaliza igual que en el registro', async () => {
    const { mailer, recover } = await setup();

    const res = await recover('  ANA@Mail.com ');

    expect(res.status).toBe(200);
    expect(mailer.lastCode('ana@mail.com')).toMatch(/^\d{6}$/);
  });

  test('REC-02 · HU-32 · si el correo falla, la respuesta es la misma y no se registra el código', async () => {
    const store = createMemoryStore();
    const errores = jest.spyOn(console, 'error').mockImplementation(() => {});
    const mailer = {
      async sendRecoveryCode() {
        throw new Error('SMTP caído para ana@mail.com con código 123456');
      },
    };
    const api = request(createApp({ config: loadConfig({ NODE_ENV: 'test' }), store, mailer }));
    await api.post('/api/auth/register').send(ana).expect(201);

    const res = await api.post('/api/auth/recover').send({ email: 'ana@mail.com' });
    await flush();
    const registrado = errores.mock.calls.flat().join(' ');
    errores.mockRestore();

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ message: RECOVER_MESSAGE });
    expect(registrado).toBe('No se pudo enviar el correo de recuperación.');
  });
});

describe('POST /api/auth/reset', () => {
  test('CON-19 · HU-32 · con el código correcto cambia la contraseña: la nueva entra y la anterior no', async () => {
    const { mailer, recover, reset, login } = await setup();
    await recover();

    const res = await reset({ code: mailer.lastCode() });

    expect(res.status).toBe(204);
    expect(res.text).toBe('');
    expect((await login('nueva2026')).status).toBe(200);
    const anterior = await login('kopay2026');
    expect(anterior.status).toBe(401);
    expect(anterior.body.code).toBe('INVALID_CREDENTIALS');
  });

  test('CON-20 · HU-32, HU-34 · un token abierto antes del cambio ya no sirve', async () => {
    const { mailer, recover, reset, login, me } = await setup();
    const t1 = (await login('kopay2026')).body.accessToken;
    const t2 = (await login('kopay2026')).body.accessToken;
    expect((await me(t1)).status).toBe(200);
    await recover();

    await reset({ code: mailer.lastCode() }).expect(204);

    for (const token of [t1, t2]) {
      const res = await me(token);
      expect(res.status).toBe(401);
      expect(res.body.code).toBe('UNAUTHENTICATED');
    }
    // Una sesión nueva, con la contraseña nueva, sí funciona.
    const t3 = (await login('nueva2026')).body.accessToken;
    expect((await me(t3)).status).toBe(200);
  });

  test('CON-21 · HU-32 · el mismo código dos veces → el segundo 400', async () => {
    const { mailer, recover, reset, login } = await setup();
    await recover();
    const code = mailer.lastCode();

    await reset({ code }).expect(204);
    const segunda = await reset({ code, password: 'otra2026' });

    expect(segunda.status).toBe(400);
    expect(segunda.body).toEqual(codigoInvalido);
    expect((await login('nueva2026')).status).toBe(200);
  });

  test('CON-22 · HU-32 · el código vence a los 15 minutos', async () => {
    const { mailer, recover, reset, adelantar, login } = await setup();
    await recover();
    const code = mailer.lastCode();

    adelantar(15);
    const vencido = await reset({ code });

    expect(vencido.status).toBe(400);
    expect(vencido.body).toEqual(codigoInvalido);
    expect((await login('kopay2026')).status).toBe(200);
  });

  test('REC-03 · HU-32 · un minuto antes de vencer todavía sirve', async () => {
    const { mailer, recover, reset, adelantar } = await setup();
    await recover();

    adelantar(14);
    expect((await reset({ code: mailer.lastCode() })).status).toBe(204);
  });

  test('CON-23 · HU-32 · 5 códigos incorrectos → el sexto intento es 429 aunque sea el correcto', async () => {
    const { mailer, recover, reset, login } = await setup();
    await recover();
    const code = mailer.lastCode();

    for (let i = 0; i < 5; i += 1) {
      const res = await reset({ code: otro(code) });
      expect(res.status).toBe(400);
      expect(res.body).toEqual(codigoInvalido);
    }
    const sexto = await reset({ code });

    expect(sexto.status).toBe(429);
    expect(sexto.body).toEqual({
      error: 'Demasiados intentos. Pide un código nuevo.',
      code: 'TOO_MANY_ATTEMPTS',
    });
    expect((await login('kopay2026')).status).toBe(200);
    expect((await login('nueva2026')).status).toBe(401);
  });

  test('REC-04 · HU-32 · después del 429, un código nuevo vuelve a funcionar', async () => {
    const { mailer, recover, reset, adelantar } = await setup();
    await recover();
    const viejo = mailer.lastCode();
    for (let i = 0; i < 5; i += 1) await reset({ code: otro(viejo) });
    expect((await reset({ code: viejo })).status).toBe(429);

    adelantar(1);
    await recover();

    expect((await reset({ code: mailer.lastCode() })).status).toBe(204);
  });

  test('CON-24 · HU-32 · pedir dos códigos invalida el primero', async () => {
    const { mailer, recover, reset, adelantar } = await setup();
    await recover();
    const primero = mailer.lastCode();
    adelantar(1);
    await recover();
    const segundo = mailer.lastCode();

    // Si por azar salen iguales, el primero sí serviría: se omite esa comparación.
    if (primero !== segundo) {
      const res = await reset({ code: primero });
      expect(res.status).toBe(400);
      expect(res.body).toEqual(codigoInvalido);
    }
    expect((await reset({ code: segundo })).status).toBe(204);
  });

  test('CON-28 · HU-32 · un correo por minuto por cuenta; el segundo pedido responde igual', async () => {
    const { mailer, recover, reset, adelantar } = await setup();

    const primero = await recover();
    const code = mailer.lastCode();
    adelantar(59 / 60); // 59 segundos después
    const segundo = await recover();

    expect(segundo.status).toBe(200);
    expect(segundo.body).toEqual(primero.body);
    expect(mailer.sent).toHaveLength(1);

    adelantar(1 / 60); // ya pasó el minuto
    await recover();
    expect(mailer.sent).toHaveLength(2);

    // Si sale el mismo código por azar, el primero seguiría sirviendo.
    if (mailer.lastCode() !== code) {
      expect((await reset({ code })).status).toBe(400);
    }
    expect((await reset({ code: mailer.lastCode() })).status).toBe(204);
  });

  test('REC-14 · HU-32 · dentro del minuto, el código enviado sigue sirviendo', async () => {
    const { mailer, recover, reset, adelantar } = await setup();
    await recover();
    const code = mailer.lastCode();

    adelantar(0.5);
    await recover();

    expect(mailer.sent).toHaveLength(1);
    expect((await reset({ code })).status).toBe(204);
  });

  test('CON-25 · HU-32 · correo sin cuenta responde como un código incorrecto; campos inválidos → fields', async () => {
    const { reset } = await setup();

    const sinCuenta = await reset({ email: 'nadie@mail.com', code: '123456' });
    const campos = await reset({ code: '12a4', password: 'abc1234' });

    expect(sinCuenta.status).toBe(400);
    expect(sinCuenta.body).toEqual(codigoInvalido);
    expect(campos.status).toBe(400);
    expect(campos.body.fields).toEqual({
      code: MESSAGES.codeRequired,
      password: MESSAGES.passwordTooShort,
    });
  });

  test('REC-05 · HU-32 · sin pedir código, cualquier código es inválido', async () => {
    const { reset } = await setup();

    const res = await reset({ code: '000000' });

    expect(res.status).toBe(400);
    expect(res.body).toEqual(codigoInvalido);
  });

  test('REC-06 · HU-32 · si solo fallan las reglas de los campos, el intento no cuenta', async () => {
    const { mailer, recover, reset, store } = await setup();
    await recover();
    const code = mailer.lastCode();

    for (let i = 0; i < 6; i += 1) {
      expect((await reset({ code, password: 'corta' })).status).toBe(400);
    }
    const user = await store.findUserByEmail('ana@mail.com');
    expect((await store.findLatestPasswordReset(user.id)).attempts).toBe(0);
    expect((await reset({ code })).status).toBe(204);
  });

  test('CON-26 · HU-32 · el código y la contraseña no salen en respuestas y la base solo guarda hashes', async () => {
    const { mailer, recover, reset, store } = await setup();
    const pedido = await recover();
    const code = mailer.lastCode();
    const cambio = await reset({ code });

    const user = await store.findUserByEmail('ana@mail.com');
    const guardado = await store.findLatestPasswordReset(user.id);

    for (const res of [pedido, cambio]) {
      expect(JSON.stringify(res.body)).not.toContain(code);
      expect(res.text).not.toMatch(/nueva2026/);
    }
    expect(guardado.codeHash).toMatch(/^[0-9a-f]{64}$/);
    expect(guardado.codeHash).not.toContain(code);
    expect(guardado.usedAt).not.toBeNull();
    expect(user.passwordHash).toMatch(/^scrypt\$/);
    expect(user.passwordHash).not.toContain('nueva2026');
  });

  test('REC-07 · HU-32 · el código de una cuenta no sirve para otra', async () => {
    const { api, mailer, recover, reset } = await setup();
    await api.post('/api/auth/register').send({ ...ana, email: 'beto@mail.com' }).expect(201);
    await recover('ana@mail.com');
    await recover('beto@mail.com'); // otra cuenta: el límite es por cuenta
    const deAna = mailer.lastCode('ana@mail.com');
    const deBeto = mailer.lastCode('beto@mail.com');

    // El hash lleva el id de la cuenta: el código de Ana no abre la de Beto.
    if (deAna !== deBeto) {
      const res = await reset({ email: 'beto@mail.com', code: deAna });
      expect(res.status).toBe(400);
      expect(res.body).toEqual(codigoInvalido);
    }
    expect((await reset({ email: 'beto@mail.com', code: deBeto })).status).toBe(204);
    // La cuenta de Ana no cambió.
    expect((await reset({ email: 'ana@mail.com', code: deAna })).status).toBe(204);
  });
});

describe('Código y correo', () => {
  test('REC-08 · HU-32 · los códigos son de 6 dígitos con ceros a la izquierda', () => {
    const codigos = Array.from({ length: 2000 }, generateCode);

    expect(codigos.every((c) => /^\d{6}$/.test(c))).toBe(true);
    // Con 2000 códigos al azar casi seguro hay más de 1900 distintos.
    expect(new Set(codigos).size).toBeGreaterThan(1900);
  });

  test('CON-26 · HU-32 · en development el código sale en la consola; en production no', async () => {
    const enviados = [];
    const transporter = { sendMail: async (m) => enviados.push(m) };
    const logs = [];
    const logger = { log: (t) => logs.push(t) };
    const prodConfig = {
      isProduction: true,
      mail: { transport: 'smtp', from: 'KoPay <kopay@example.com>' },
    };

    await createMailer({ config: loadConfig({ NODE_ENV: 'development' }), logger, transporter })
      .sendRecoveryCode({ to: 'ana@mail.com', name: 'Ana', code: '048213', minutes: 15 });
    await createMailer({ config: prodConfig, logger, transporter })
      .sendRecoveryCode({ to: 'ana@mail.com', name: 'Ana', code: '731906', minutes: 15 });

    expect(logs).toHaveLength(1);
    expect(logs[0]).toContain('048213');
    expect(logs.join(' ')).not.toContain('731906');
    expect(enviados[1]).toMatchObject({ from: 'KoPay <kopay@example.com>', to: 'ana@mail.com' });
    expect(enviados[1].text).toContain('731906');
    expect(enviados[1].text).toContain('15 minutos');
  });

  test('REC-09 · HU-32 · en development y test el correo usa jsonTransport y no sale a la red', async () => {
    const logger = { log: jest.fn() };
    const mailer = createMailer({ config: loadConfig({ NODE_ENV: 'test' }), logger });

    await expect(
      mailer.sendRecoveryCode({ to: 'ana@mail.com', name: 'Ana', code: '000123', minutes: 15 }),
    ).resolves.toBeUndefined();
    expect(logger.log).toHaveBeenCalledWith(expect.stringContaining('000123'));
  });
  test('REC-15 · HU-32 · intentos en paralelo no pasan del límite de 5', async () => {
    const store = createMemoryStore();
    let code = null;
    const service = createRecoveryService({
      store,
      secret: 'secreto-de-prueba-para-rec-15-0123456789',
      mailer: { sendRecoveryCode: async (m) => { code = m.code; } },
      logger: { error() {} },
    });
    await store.createUser({ name: 'Ana', email: 'ana@mail.com', passwordHash: 'x'.repeat(30), role: 'user' });
    await service.recover({ email: 'ana@mail.com' });
    await flush();

    // Las 40 peticiones leen el código vigente al mismo tiempo, antes de
    // que alguna sume su intento: así se ve si el límite se puede saltar.
    const TOTAL = 40;
    const read = store.findLatestPasswordReset.bind(store);
    let waiting = 0;
    let release;
    const barrier = new Promise((r) => { release = r; });
    store.findLatestPasswordReset = async (id) => {
      const reset = await read(id);
      waiting += 1;
      if (waiting === TOTAL) release();
      await barrier;
      return reset;
    };

    const otros = [...Array(TOTAL - 1)].map((_, i) =>
      String((Number(code) + i + 1) % 1_000_000).padStart(6, '0'),
    );
    const results = await Promise.allSettled(
      [...otros, code].map((c) =>
        service.reset({ email: 'ana@mail.com', code: c, password: 'nueva2026' }),
      ),
    );
    const status = results.map((r) => (r.status === 'fulfilled' ? 204 : r.reason.status));

    expect(status.filter((s) => s === 400)).toHaveLength(5);
    expect(status.filter((s) => s === 429)).toHaveLength(TOTAL - 5);
    expect(status).not.toContain(204);
  });
});
