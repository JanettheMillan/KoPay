'use strict';

// S5-02 · API CRUD de ingresos (HU-02, HU-09, HU-34, HU-36). Contrato
// §3.13. Casos nuevos INC-01 a INC-09; INC-05 es DB-04 (aislamiento) con
// la ruta real. Sigue el patrón de S5-01 (test/movements.test.js).

const { randomUUID } = require('node:crypto');
const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { hashPassword } = require('../src/services/password.service');
const { MESSAGES } = require('../src/validators/income.validator');

const CLAVE = 'kopay2026';
const nomina = { name: 'Nómina', amount: 12500, date: '2026-11-15' };

async function setup() {
  const store = createMemoryStore();
  const api = request(createApp({ store }));
  const tokens = {};
  for (const [clave, email] of [['ana', 'ana@mail.com'], ['beto', 'beto@mail.com']]) {
    await api.post('/api/auth/register').send({ name: clave, email, password: CLAVE }).expect(201);
  }
  await store.createUser({
    name: 'Carla',
    email: 'carla@conta.mx',
    passwordHash: await hashPassword(CLAVE),
    role: 'accountant',
  });
  for (const [clave, email] of [['ana', 'ana@mail.com'], ['beto', 'beto@mail.com'], ['carla', 'carla@conta.mx']]) {
    const res = await api.post('/api/auth/login').send({ email, password: CLAVE }).expect(200);
    tokens[clave] = `Bearer ${res.body.accessToken}`;
  }
  const as = (who) => ({
    list: (q = '') => api.get(`/api/incomes${q}`).set('Authorization', tokens[who]),
    get: (id) => api.get(`/api/incomes/${id}`).set('Authorization', tokens[who]),
    create: (body) => api.post('/api/incomes').set('Authorization', tokens[who]).send(body),
    update: (id, body) => api.put(`/api/incomes/${id}`).set('Authorization', tokens[who]).send(body),
    remove: (id) => api.delete(`/api/incomes/${id}`).set('Authorization', tokens[who]),
  });
  return { store, api, as, tokens };
}

describe('/api/incomes', () => {
  test('INC-01 · HU-02 · registrar un ingreso válido responde 201 con versión 1 y dueño de la sesión', async () => {
    const { as, store } = await setup();
    const res = await as('ana').create({ ...nomina, name: '  Nómina  ', note: '  Quincena  ' });
    expect(res.status).toBe(201);
    expect(res.body.income).toMatchObject({
      name: 'Nómina',
      amount: 12500,
      date: '2026-11-15T00:00:00.000Z',
      note: 'Quincena',
      version: 1,
    });
    expect(res.body.income).not.toHaveProperty('category');
    const saved = await store.findIncomeById(res.body.income.id);
    expect(saved.userId).toBe((await store.findUserByEmail('ana@mail.com')).id);
  });

  test('INC-02 · HU-02 · datos incompletos o inválidos: 400 con todos los campos a la vez', async () => {
    const { as } = await setup();
    const res = await as('ana').create({ amount: 0, name: '  ', date: '2026-02-30', note: 'x'.repeat(141) });
    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: {
        amount: MESSAGES.amountNotPositive,
        name: MESSAGES.nameRequired,
        date: MESSAGES.dateInvalid,
        note: MESSAGES.noteTooLong,
      },
    });
    for (const [amount, message] of [
      [undefined, MESSAGES.amountRequired],
      ['12500', MESSAGES.amountInvalid],
      [-100, MESSAGES.amountNotPositive],
      [10.123, MESSAGES.amountDecimals],
      [1e10, MESSAGES.amountTooLarge],
    ]) {
      const bad = await as('ana').create({ ...nomina, amount });
      expect(bad.body.fields.amount).toBe(message);
    }
    expect((await as('ana').create({ ...nomina, name: 'x'.repeat(61) })).body.fields.name).toBe(MESSAGES.nameTooLong);
    expect((await as('ana').list()).body.incomes).toEqual([]);
  });

  test('INC-03 · HU-02 · un monto con centavos se guarda exacto', async () => {
    const { as } = await setup();
    expect((await as('ana').create({ ...nomina, amount: 1350.5 })).body.income.amount).toBe(1350.5);
    // 0.1 + 0.2 es ruido del punto flotante, no un tercer decimal (D-06).
    const centavos = await as('ana').create({ ...nomina, amount: 0.1 + 0.2 });
    expect(centavos.status).toBe(201);
    expect(centavos.body.income.amount).toBe(0.3);
    expect((await as('ana').create({ ...nomina, amount: 999999999.99 })).status).toBe(201);
  });

  test('INC-04 · HU-09 · lista del más reciente al más antiguo y filtra por mes', async () => {
    const { as } = await setup();
    await as('ana').create({ ...nomina, name: 'Octubre', date: '2026-10-31' });
    await as('ana').create({ ...nomina, name: 'Quincena 1', date: '2026-11-15' });
    await as('ana').create({ ...nomina, name: 'Quincena 2', date: '2026-11-30T18:00:00Z' });

    expect((await as('ana').list()).body.incomes.map((i) => i.name)).toEqual(['Quincena 2', 'Quincena 1', 'Octubre']);
    expect((await as('ana').list('?month=2026-11')).body.incomes.map((i) => i.name)).toEqual([
      'Quincena 2',
      'Quincena 1',
    ]);
    expect((await as('ana').list('?month=11-2026')).body.fields.month).toEqual(expect.any(String));
  });

  test('INC-05 · HU-34 · DB-04 · otra cuenta no ve, no cambia ni borra un ingreso ajeno', async () => {
    const { as } = await setup();
    const { income } = (await as('ana').create(nomina)).body;

    expect((await as('beto').list()).body.incomes).toEqual([]);
    const ajeno = await as('beto').get(income.id);
    const inexistente = await as('beto').get(randomUUID());
    expect(ajeno.status).toBe(404);
    expect(ajeno.body).toEqual(inexistente.body);
    expect((await as('beto').update(income.id, { ...nomina, amount: 1 })).status).toBe(404);
    expect((await as('beto').remove(income.id)).status).toBe(404);

    expect((await as('ana').get(income.id)).body.income).toMatchObject({ amount: 12500, version: 1 });
  });

  test('INC-06 · HU-02 · HU-09 · editar cambia los datos, sube la versión y mueve el ingreso de mes', async () => {
    const { as } = await setup();
    const { income } = (await as('ana').create(nomina)).body;
    const res = await as('ana').update(income.id, { name: 'Bono', amount: 3000, date: '2026-12-01', version: 1 });
    expect(res.status).toBe(200);
    expect(res.body.income).toMatchObject({ name: 'Bono', amount: 3000, note: null, version: 2 });

    // La consulta del mes se actualiza: ya no está en noviembre, sí en diciembre.
    expect((await as('ana').list('?month=2026-11')).body.incomes).toEqual([]);
    expect((await as('ana').list('?month=2026-12')).body.incomes.map((i) => i.name)).toEqual(['Bono']);
  });

  test('INC-07 · HU-36 · una versión vieja responde 409 VERSION_CONFLICT y no cambia nada', async () => {
    const { as } = await setup();
    const { income } = (await as('ana').create(nomina)).body;
    await as('ana').update(income.id, { ...nomina, amount: 13000, version: 1 }).expect(200);

    const viejo = await as('ana').update(income.id, { ...nomina, amount: 1, version: 1 });
    expect(viejo.status).toBe(409);
    expect(viejo.body.code).toBe('VERSION_CONFLICT');
    expect((await as('ana').get(income.id)).body.income).toMatchObject({ amount: 13000, version: 2 });
    expect((await as('ana').update(income.id, { ...nomina, version: 0 })).body.fields.version).toBe(
      MESSAGES.versionInvalid,
    );
  });

  test('INC-08 · HU-09 · borrar responde 204 y el ingreso sale de la consulta del mes', async () => {
    const { as } = await setup();
    const { income } = (await as('ana').create(nomina)).body;
    expect((await as('ana').remove(income.id)).status).toBe(204);
    expect((await as('ana').get(income.id)).status).toBe(404);
    expect((await as('ana').list('?month=2026-11')).body.incomes).toEqual([]);
    expect((await as('ana').remove(income.id)).status).toBe(404);
  });

  test('INC-09 · HU-34 · HU-42 · userId del cuerpo se ignora y el contador recibe 403', async () => {
    const { as, store } = await setup();
    const beto = await store.findUserByEmail('beto@mail.com');
    const { income } = (await as('ana').create({ ...nomina, userId: beto.id, user_id: beto.id })).body;
    expect((await store.findIncomeById(income.id)).userId).not.toBe(beto.id);
    expect((await as('beto').list()).body.incomes).toEqual([]);

    expect((await as('carla').list()).status).toBe(403);
    expect((await as('carla').create(nomina)).status).toBe(403);
  });
});
