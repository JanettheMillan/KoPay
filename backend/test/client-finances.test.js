'use strict';

// S5-03 · Consulta financiera autorizada para el contador (HU-39, HU-40,
// HU-41, HU-42). Contrato §3.10. ROL-07 es el caso de
// docs/reglas-roles-contador.md §8 que S4-06 dejó para esta tarjeta.
// FIC-01 a FIC-07 son pruebas nuevas, anotadas en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { hashPassword } = require('../src/services/password.service');
const { MONTH_MESSAGE } = require('../src/services/client-finance.service');

const CLAVE = 'kopay2026';
const sinAcceso = { error: 'No tienes acceso a los datos de esta persona', code: 'FORBIDDEN' };
const NO_EXISTE = '00000000-0000-4000-8000-000000000000';

/** Ana y Beto (user) con datos en octubre y noviembre; Carla y Dani (accountant). */
async function setup() {
  const store = createMemoryStore();
  const api = request(createApp({ store }));
  const cuentas = {};
  const tokens = {};
  for (const [clave, email] of [['ana', 'ana@mail.com'], ['beto', 'beto@mail.com']]) {
    await api.post('/api/auth/register').send({ name: clave, email, password: CLAVE }).expect(201);
    cuentas[clave] = await store.findUserByEmail(email);
  }
  const passwordHash = await hashPassword(CLAVE);
  for (const [clave, email] of [['carla', 'carla@conta.mx'], ['dani', 'dani@conta.mx']]) {
    cuentas[clave] = await store.createUser({ name: clave, email, passwordHash, role: 'accountant' });
  }
  for (const [clave, cuenta] of Object.entries(cuentas)) {
    const res = await api.post('/api/auth/login').send({ email: cuenta.email, password: CLAVE }).expect(200);
    tokens[clave] = `Bearer ${res.body.accessToken}`;
  }
  const como = (quien) => ({
    get: (ruta) => api.get(ruta).set('Authorization', tokens[quien]),
    pedir: (metodo, ruta) => api[metodo](ruta).set('Authorization', tokens[quien]),
  });
  const autorizar = async (quien, accountantEmail) =>
    (await como(quien).pedir('post', '/api/accountants').send({ accountantEmail }).expect(201)).body.grant;

  // Datos de Ana: noviembre y uno de octubre. Beto: noviembre.
  const mov = (quien, body) => como(quien).pedir('post', '/api/movements').send(body).expect(201);
  const ing = (quien, body) => como(quien).pedir('post', '/api/incomes').send(body).expect(201);
  await ing('ana', { name: 'Nómina', amount: 15000, date: '2026-11-01' });
  await mov('ana', { amount: -1820.5, description: 'Súper', category: 'Comida', date: '2026-11-04' });
  await mov('ana', { amount: 350, description: 'Venta', category: 'Otros', date: '2026-11-06' });
  const tarjeta = await mov('ana', { amount: -2000, description: 'Pago tarjeta Oro', category: 'Pago', date: '2026-11-08' });
  await mov('ana', { amount: -320, description: 'Cine', category: 'Entretenimiento', date: '2026-10-14' });
  await ing('beto', { name: 'Honorarios', amount: 9800, date: '2026-11-02' });
  await mov('beto', { amount: -999, description: 'Secreto de Beto', category: 'Otros', date: '2026-11-03' });

  // Un pago lo registra S5-05 desde su tarjeta; aquí se marca en el almacén.
  const pagoId = tarjeta.body.movement.id;
  const listMovements = store.listMovements.bind(store);
  store.listMovements = async (args) =>
    (await listMovements(args)).map((m) => (m.id === pagoId ? { ...m, type: 'payment' } : m));

  return { api, store, cuentas, como, autorizar };
}

const ruta = (id, recurso, mes = '2026-11') => `/api/clients/${id}/${recurso}${mes ? `?month=${mes}` : ''}`;

describe('/api/clients/:userId/summary y /movements', () => {
  test('ROL-07 · HU-40 · el contador ve solo los datos de esa persona y de ese mes', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');

    const lista = await como('carla').get(ruta(cuentas.ana.id, 'movements'));
    expect(lista.status).toBe(200);
    expect(lista.body.movements.map((m) => m.description)).toEqual(['Pago tarjeta Oro', 'Venta', 'Súper']);
    expect(lista.body.incomes.map((i) => i.name)).toEqual(['Nómina']);
    const todos = [...lista.body.movements, ...lista.body.incomes];
    expect(todos.every((r) => r.userId === cuentas.ana.id)).toBe(true);
    expect(JSON.stringify(lista.body)).not.toContain('Secreto de Beto');
    expect(JSON.stringify(lista.body)).not.toContain('Cine');

    const octubre = await como('carla').get(ruta(cuentas.ana.id, 'movements', '2026-10'));
    expect(octubre.body.movements.map((m) => m.description)).toEqual(['Cine']);
    expect(octubre.body.incomes).toEqual([]);
  });

  test('FIC-01 · HU-40 · el resumen separa los pagos y cuadra con Inicio (HU-09)', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');

    const res = await como('carla').get(ruta(cuentas.ana.id, 'summary'));
    expect(res.status).toBe(200);
    // Ingresos 15000 + entrada 350; gastos 1820.50; pago 2000 aparte.
    expect(res.body).toEqual({
      month: '2026-11',
      income: 15350,
      expenses: 1820.5,
      payments: 2000,
      balance: 11529.5,
    });
    const octubre = await como('carla').get(ruta(cuentas.ana.id, 'summary', '2026-10'));
    expect(octubre.body).toEqual({ month: '2026-10', income: 0, expenses: 320, payments: 0, balance: -320 });
  });

  test('FIC-02 · HU-39 · sin permiso, con otro contador o con un id que no existe → 403 igual', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');

    for (const [quien, id] of [
      ['carla', cuentas.beto.id], // Beto no autorizó a Carla
      ['dani', cuentas.ana.id], // Ana autorizó a Carla, no a Dani
      ['carla', NO_EXISTE],
      ['carla', 'no-es-uuid'],
    ]) {
      for (const recurso of ['summary', 'movements']) {
        const res = await como(quien).get(ruta(id, recurso));
        expect(res.status).toBe(403);
        expect(res.body).toEqual(sinAcceso);
      }
    }
  });

  test('FIC-03 · HU-41 · al revocar, la siguiente consulta ya responde 403', async () => {
    const { como, autorizar, cuentas } = await setup();
    const grant = await autorizar('ana', 'carla@conta.mx');
    expect((await como('carla').get(ruta(cuentas.ana.id, 'summary'))).status).toBe(200);

    await como('ana').pedir('delete', `/api/accountants/${grant.id}`).expect(204);
    for (const recurso of ['summary', 'movements']) {
      const res = await como('carla').get(ruta(cuentas.ana.id, recurso));
      expect(res.status).toBe(403);
      expect(res.body).toEqual(sinAcceso);
    }
  });

  test('FIC-04 · HU-40 · el mes es obligatorio y con formato AAAA-MM', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');

    for (const mes of [null, '2026-13', '11-2026', '2026-1']) {
      for (const recurso of ['summary', 'movements']) {
        const res = await como('carla').get(ruta(cuentas.ana.id, recurso, mes));
        expect(res.status).toBe(400);
        expect(res.body).toEqual({
          error: 'Revisa los datos marcados',
          code: 'VALIDATION_FAILED',
          fields: { month: MONTH_MESSAGE },
        });
      }
    }
  });

  test('FIC-05 · HU-42 · escribir sobre el resumen o los movimientos de un cliente → 403 y nada cambia', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');
    const antes = (await como('carla').get(ruta(cuentas.ana.id, 'movements'))).body;

    for (const recurso of ['summary', 'movements']) {
      for (const metodo of ['post', 'put', 'patch', 'delete']) {
        const res = await como('carla').pedir(metodo, ruta(cuentas.ana.id, recurso)).send({ amount: -1 });
        expect(res.status).toBe(403);
        expect(res.body).toEqual(sinAcceso);
      }
    }
    expect((await como('carla').get(ruta(cuentas.ana.id, 'movements'))).body).toEqual(antes);
  });

  test('FIC-06 · HU-37 · una cuenta user no consulta a otra persona ni a sí misma por aquí', async () => {
    const { como, cuentas } = await setup();
    for (const id of [cuentas.ana.id, cuentas.beto.id]) {
      for (const recurso of ['summary', 'movements']) {
        const res = await como('ana').get(ruta(id, recurso));
        expect(res.status).toBe(403);
        expect(res.body).toEqual(sinAcceso);
      }
    }
  });

  test('FIC-07 · HU-34 · sin sesión → 401 antes de revisar el permiso', async () => {
    const { api, cuentas } = await setup();
    for (const recurso of ['summary', 'movements']) {
      const res = await api.get(ruta(cuentas.ana.id, recurso));
      expect(res.status).toBe(401);
      expect(res.body.code).toBe('UNAUTHENTICATED');
    }
  });
});
