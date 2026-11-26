// S5-06 · Tipo de cambio FIX USD/MXN de Banxico (HU-35).
//
// FUT-07, FUT-10, FUT-17 y FUT-20 son casos de docs/plan-de-pruebas.md.
// FX-01 a FX-10 son pruebas nuevas de esta tarjeta, anotadas en el PR.
// Ninguna prueba usa la red: `fetch` se simula.

const request = require('supertest');

const { createApp } = require('../src/app');
const { loadConfig, describeConfig, EXAMPLE_BANXICO_TOKEN } = require('../src/config');
const { createMemoryStore } = require('../src/data/store');
const {
  BANXICO_URL,
  createExchangeRateService,
  parseBanxico,
} = require('../src/services/exchange-rate.service');

const TOKEN = 'a1b2c3d4'.repeat(8);
const noDisponible = {
  error: 'El tipo de cambio no está disponible. Inténtalo más tarde.',
  code: 'UNAVAILABLE',
};
const sinSesion = { error: 'Inicia sesión para continuar', code: 'UNAUTHENTICATED' };

/** Cuerpo como el de Banxico para la serie FIX. */
function banxico(datos) {
  return { bmx: { series: [{ idSerie: 'SF43718', titulo: 'Tipo de cambio FIX', datos }] } };
}

/** `fetch` falso: responde lo que diga `responder` y guarda cada llamada. */
function fakeFetch(responder) {
  const calls = [];
  const fn = async (url, options) => {
    calls.push({ url, options });
    return responder(calls.length, options);
  };
  return { fn, calls };
}

const ok = (body) => ({ ok: true, status: 200, json: async () => body });
const status = (code) => ({ ok: false, status: code, json: async () => ({}) });

/** App con sesión de Ana y un servicio de tipo de cambio con `fetch` falso. */
async function setup({ responder = () => ok(banxico([{ fecha: '25/11/2026', dato: '17.2345' }])), token = TOKEN, timeoutMs } = {}) {
  const ahora = new Date('2026-11-26T18:00:00.000Z');
  const now = () => ahora;
  const logs = [];
  const fetch = fakeFetch(responder);
  const exchangeRateService = createExchangeRateService({
    token,
    fetchImpl: fetch.fn,
    now,
    logger: { error: (m) => logs.push(m) },
    ...(timeoutMs ? { timeoutMs } : {}),
  });
  const api = request(createApp({ store: createMemoryStore({ now }), now, exchangeRateService }));
  await api
    .post('/api/auth/register')
    .send({ name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' })
    .expect(201);
  const login = await api
    .post('/api/auth/login')
    .send({ email: 'ana@mail.com', password: 'kopay2026' })
    .expect(200);
  const auth = `Bearer ${login.body.accessToken}`;
  return {
    api,
    fetch,
    logs,
    consultar: () => api.get('/api/exchange-rates').set('Authorization', auth),
  };
}

describe('GET /api/exchange-rates · respuesta (HU-35)', () => {
  test('FX-01 · HU-35 · con sesión → 200 con base, quote, rate, date y source', async () => {
    const { consultar, fetch } = await setup();

    const res = await consultar();

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      base: 'USD',
      quote: 'MXN',
      rate: 17.2345,
      date: '2026-11-25',
      source: 'Banxico FIX',
    });
    expect(fetch.calls).toHaveLength(1);
    expect(fetch.calls[0].url).toBe(BANXICO_URL);
    expect(fetch.calls[0].url).toMatch(/series\/SF43718\/datos\/oportuno$/);
    // El token va en el encabezado, nunca en la URL.
    expect(fetch.calls[0].options.headers['Bmx-Token']).toBe(TOKEN);
    expect(fetch.calls[0].url).not.toContain(TOKEN);
  });

  test('FX-02 · HU-35 · en fin de semana o festivo usa el último dato publicado', async () => {
    // Banxico devuelve el del viernes; si la serie trae un día sin dato
    // ("N/E"), se toma el último válido.
    const { consultar } = await setup({
      responder: () =>
        ok(banxico([
          { fecha: '27/11/2026', dato: '17.1100' },
          { fecha: '30/11/2026', dato: 'N/E' },
        ])),
    });

    const res = await consultar();

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ rate: 17.11, date: '2026-11-27' });
  });

  test('FX-03 · HU-35 · sin sesión o con token de sesión inválido → 401 y no consulta a Banxico', async () => {
    const { api, fetch } = await setup();

    const sin = await api.get('/api/exchange-rates');
    const falso = await api.get('/api/exchange-rates').set('Authorization', 'Bearer falso');

    expect(sin.status).toBe(401);
    expect(sin.body).toEqual(sinSesion);
    expect(falso.status).toBe(401);
    expect(fetch.calls).toHaveLength(0);
  });
});

describe('Caché de una hora', () => {
  test('FX-04 · HU-35 · dentro de la hora responde desde la caché; después vuelve a consultar', async () => {
    // Directo al servicio: la sesión de 15 minutos vencería antes de la hora.
    let ahora = new Date('2026-11-26T18:00:00.000Z');
    let valor = '17.2345';
    const fetch = fakeFetch(() => ok(banxico([{ fecha: '25/11/2026', dato: valor }])));
    const service = createExchangeRateService({
      token: TOKEN,
      fetchImpl: fetch.fn,
      now: () => ahora,
      logger: { error() {} },
    });
    const adelantar = (minutos) => {
      ahora = new Date(ahora.getTime() + minutos * 60_000);
    };

    await service.getUsdMxn();
    valor = '18.0000';
    adelantar(59);
    const enCache = await service.getUsdMxn();
    adelantar(2);
    const nueva = await service.getUsdMxn();

    expect(enCache.rate).toBe(17.2345);
    expect(nueva.rate).toBe(18);
    expect(fetch.calls).toHaveLength(2);
  });

  test('FX-05 · HU-35 · varias peticiones a la vez hacen una sola consulta a Banxico', async () => {
    let soltar;
    const espera = new Promise((resolve) => {
      soltar = resolve;
    });
    const fetch = fakeFetch(async () => {
      await espera;
      return ok(banxico([{ fecha: '25/11/2026', dato: '17.2345' }]));
    });
    const service = createExchangeRateService({ token: TOKEN, fetchImpl: fetch.fn, logger: { error() {} } });

    const juntas = Promise.all([service.getUsdMxn(), service.getUsdMxn(), service.getUsdMxn()]);
    soltar();
    const respuestas = await juntas;

    expect(fetch.calls).toHaveLength(1);
    expect(respuestas.map((r) => r.rate)).toEqual([17.2345, 17.2345, 17.2345]);
  });

  test('FX-06 · HU-35 · un fallo no se guarda en caché: la siguiente consulta lo vuelve a intentar', async () => {
    const { consultar, fetch } = await setup({
      responder: (n) => (n === 1 ? status(500) : ok(banxico([{ fecha: '25/11/2026', dato: '17.2345' }]))),
    });

    await consultar().expect(503);
    const res = await consultar();

    expect(res.status).toBe(200);
    expect(fetch.calls).toHaveLength(2);
  });
});

describe('Fallos de Banxico → 503 sin detalles', () => {
  test('FX-07 · HU-35 · token inválido, límite de consultas o caída → 503 UNAVAILABLE', async () => {
    for (const code of [400, 401, 403, 429, 500, 503]) {
      const { consultar } = await setup({ responder: () => status(code) });
      const res = await consultar();
      expect(res.status).toBe(503);
      expect(res.body).toEqual(noDisponible);
    }
  });

  test('FX-08 · HU-35 · si Banxico no responde en 5 s → 503', async () => {
    // fetch falso que solo termina cuando se cancela por tiempo.
    const responder = (_n, { signal }) =>
      new Promise((_resolve, reject) => {
        signal.addEventListener('abort', () => reject(signal.reason));
      });
    const { consultar, logs } = await setup({ responder, timeoutMs: 50 });

    const res = await consultar();

    expect(res.status).toBe(503);
    expect(res.body).toEqual(noDisponible);
    expect(logs).toEqual(['Tipo de cambio no disponible: sin respuesta en 0.05 s']);
  });

  test('FX-09 · HU-35 · error de red o respuesta que no es JSON → 503', async () => {
    const red = await setup({
      responder: () => {
        throw new TypeError('fetch failed');
      },
    });
    const html = await setup({
      responder: () => ({ ok: true, status: 200, json: async () => JSON.parse('<html>') }),
    });

    expect((await red.consultar()).body).toEqual(noDisponible);
    expect((await html.consultar()).body).toEqual(noDisponible);
  });

  test('FX-10 · HU-35 · el token nunca sale en la respuesta ni en la consola', async () => {
    for (const responder of [() => status(401), () => { throw new Error(`falló con ${TOKEN}`); }, () => ok({})]) {
      const { consultar, logs } = await setup({ responder });
      const res = await consultar();
      expect(res.status).toBe(503);
      expect(JSON.stringify(res.body)).not.toContain(TOKEN);
      expect(logs.join('\n')).not.toContain(TOKEN);
      expect(logs).toHaveLength(1);
    }
  });

  test('FUT-20 · HU-35 · en desarrollo sin BANXICO_TOKEN → 503 y no consulta a Banxico', async () => {
    const { consultar, fetch, logs } = await setup({ token: '' });

    const res = await consultar();

    expect(res.status).toBe(503);
    expect(res.body).toEqual(noDisponible);
    expect(fetch.calls).toHaveLength(0);
    expect(logs).toEqual(['Tipo de cambio no disponible: sin BANXICO_TOKEN']);
  });
});

describe('Adaptador de la respuesta de Banxico', () => {
  test('FUT-07 · HU-35 · una respuesta válida se convierte al modelo acordado', () => {
    expect(parseBanxico(banxico([{ fecha: '25/11/2026', dato: '17.2345' }]))).toEqual({
      date: '2026-11-25',
      rate: 17.2345,
    });
    expect(parseBanxico(banxico([{ fecha: '02/01/2027', dato: '1,017.50' }]))).toEqual({
      date: '2027-01-02',
      rate: 1017.5,
    });
  });

  test('FUT-17 · HU-35 · una respuesta incompleta o con datos inválidos no inventa un valor', async () => {
    for (const body of [
      {},
      { bmx: {} },
      { bmx: { series: [] } },
      { bmx: { series: [{ idSerie: 'SF60653', datos: [{ fecha: '25/11/2026', dato: '17.2' }] }] } },
      banxico([]),
      banxico([{ fecha: '25/11/2026' }]),
      banxico([{ dato: '17.2345' }]),
      banxico([{ fecha: '31/02/2026', dato: '17.2345' }]),
      banxico([{ fecha: '25/11/2026', dato: 'N/E' }]),
      banxico([{ fecha: '25/11/2026', dato: '-1' }]),
      banxico([{ fecha: '25/11/2026', dato: '0' }]),
    ]) {
      expect(parseBanxico(body)).toBeNull();
    }
    const { consultar } = await setup({ responder: () => ok(banxico([{ fecha: '25/11/2026', dato: 'N/E' }])) });
    expect((await consultar()).body).toEqual(noDisponible);
  });
});

describe('Configuración de BANXICO_TOKEN', () => {
  const PROD = {
    NODE_ENV: 'production',
    DATABASE_URL: 'postgres://usuario:clave@db.example.com:5432/kopay',
    JWT_SECRET: 'x'.repeat(48),
    CORS_ORIGIN: 'https://kopay.example.com',
    BANXICO_TOKEN: TOKEN,
    // Correo de recuperación, obligatorio en producción desde S4-19.
    SMTP_HOST: 'smtp.example.com',
    SMTP_PORT: '587',
    SMTP_USER: 'kopay@example.com',
    SMTP_PASS: 'clave-smtp-secreta',
    MAIL_FROM: 'KoPay <kopay@example.com>',
  };

  test('FUT-10 · HU-35 · producción exige BANXICO_TOKEN válido y no muestra su valor', () => {
    const { BANXICO_TOKEN, ...sinToken } = PROD;
    expect(() => loadConfig(sinToken)).toThrow('falta BANXICO_TOKEN');
    expect(() => loadConfig({ ...PROD, BANXICO_TOKEN: '  ' })).toThrow('falta BANXICO_TOKEN');
    expect(() => loadConfig({ ...PROD, BANXICO_TOKEN: EXAMPLE_BANXICO_TOKEN })).toThrow('valor de ejemplo');

    let message = '';
    try {
      loadConfig({ ...PROD, BANXICO_TOKEN: 'token-corto-secreto' });
    } catch (err) {
      message = err.message;
    }
    expect(message).toContain('BANXICO_TOKEN debe tener 64 caracteres hexadecimales');
    expect(message).not.toContain('token-corto-secreto');

    const config = loadConfig(PROD);
    expect(config.banxicoToken).toBe(TOKEN);
    expect(describeConfig(config).banxicoToken).toBe('definido');
    expect(JSON.stringify(describeConfig(config))).not.toContain(TOKEN);
  });

  test('FUT-20 · HU-35 · en desarrollo y pruebas es opcional, y el valor de ejemplo cuenta como no definido', () => {
    expect(loadConfig({}).banxicoToken).toBeUndefined();
    expect(loadConfig({ NODE_ENV: 'test', BANXICO_TOKEN: EXAMPLE_BANXICO_TOKEN }).banxicoToken).toBeUndefined();
    expect(loadConfig({ BANXICO_TOKEN: TOKEN }).banxicoToken).toBe(TOKEN);
    expect(describeConfig(loadConfig({})).banxicoToken).toBe('sin definir');
  });
});
