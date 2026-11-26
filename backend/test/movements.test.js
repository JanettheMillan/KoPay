'use strict';

// S5-01 · API CRUD de movimientos (HU-01, HU-03, HU-04, HU-05, HU-06,
// HU-08, HU-34). Contrato §3.12. Casos nuevos MOV-01 a MOV-10; MOV-05 es
// DB-04 (aislamiento) con la ruta real.

const { randomUUID } = require('node:crypto');
const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { hashPassword } = require('../src/services/password.service');
const { MESSAGES } = require('../src/validators/movement.validator');

const CLAVE = 'kopay2026';
const cafe = { amount: -50, description: 'Café', category: 'Comida', date: '2026-11-26' };

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
    list: (q = '') => api.get(`/api/movements${q}`).set('Authorization', tokens[who]),
    get: (id) => api.get(`/api/movements/${id}`).set('Authorization', tokens[who]),
    create: (body) => api.post('/api/movements').set('Authorization', tokens[who]).send(body),
    update: (id, body) => api.put(`/api/movements/${id}`).set('Authorization', tokens[who]).send(body),
    remove: (id) => api.delete(`/api/movements/${id}`).set('Authorization', tokens[who]),
  });
  return { store, api, as, tokens };
}

describe('/api/movements', () => {
  test('MOV-01 · HU-01 · crear un gasto válido responde 201 con versión 1 y dueño de la sesión', async () => {
    const { as, store } = await setup();
    const res = await as('ana').create({ ...cafe, note: '  Con pan  ' });
    expect(res.status).toBe(201);
    expect(res.body.movement).toMatchObject({
      amount: -50,
      description: 'Café',
      category: 'Comida',
      date: '2026-11-26T00:00:00.000Z',
      note: 'Con pan',
      type: 'regular',
      cardId: null,
      debtId: null,
      version: 1,
    });
    const saved = await store.findMovementById(res.body.movement.id);
    expect(saved.userId).toBe((await store.findUserByEmail('ana@mail.com')).id);
  });

  test('MOV-02 · HU-04 · datos incompletos o inválidos: 400 con todos los campos a la vez', async () => {
    const { as } = await setup();
    const res = await as('ana').create({ amount: 0, description: '  ', category: '', date: '2026-02-30' });
    expect(res.status).toBe(400);
    expect(res.body).toEqual({
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: {
        amount: MESSAGES.amountZero,
        description: MESSAGES.descriptionRequired,
        category: MESSAGES.categoryRequired,
        date: MESSAGES.dateInvalid,
      },
    });
    for (const [amount, message] of [
      [undefined, MESSAGES.amountRequired],
      ['150', MESSAGES.amountInvalid],
      [10.123, MESSAGES.amountDecimals],
      [1e10, MESSAGES.amountTooLarge],
    ]) {
      const bad = await as('ana').create({ ...cafe, amount });
      expect(bad.body.fields.amount).toBe(message);
    }
    expect((await as('ana').create({ ...cafe, description: 'x'.repeat(61) })).body.fields.description).toBe(
      MESSAGES.descriptionTooLong,
    );
    expect((await as('ana').list()).body.movements).toEqual([]);
  });

  test('MOV-03 · HU-03 · una entrada positiva y un monto con centavos se guardan exactos', async () => {
    const { as } = await setup();
    const entrada = await as('ana').create({ ...cafe, amount: 1350.5, description: 'Venta' });
    expect(entrada.body.movement.amount).toBe(1350.5);
    // 0.1 + 0.2 llega como 0.30000000000000004: es ruido del punto
    // flotante, no un tercer decimal. Se guarda en centavos (D-06).
    const centavos = await as('ana').create({ ...cafe, amount: 0.1 + 0.2 });
    expect(centavos.status).toBe(201);
    expect(centavos.body.movement.amount).toBe(0.3);
    expect((await as('ana').create({ ...cafe, amount: -0.3 })).body.movement.amount).toBe(-0.3);
  });

  test('MOV-04 · HU-07 · HU-08 · lista del más reciente al más antiguo y filtra por mes', async () => {
    const { as } = await setup();
    await as('ana').create({ ...cafe, description: 'Octubre', date: '2026-10-31' });
    await as('ana').create({ ...cafe, description: 'Nov 3', date: '2026-11-03' });
    await as('ana').create({ ...cafe, description: 'Nov 20', date: '2026-11-20T15:30:00Z' });

    const all = (await as('ana').list()).body.movements.map((m) => m.description);
    expect(all).toEqual(['Nov 20', 'Nov 3', 'Octubre']);
    const nov = (await as('ana').list('?month=2026-11')).body.movements.map((m) => m.description);
    expect(nov).toEqual(['Nov 20', 'Nov 3']);
    expect((await as('ana').list('?month=2026-13')).body.fields.month).toEqual(expect.any(String));
  });

  test('MOV-05 · HU-34 · DB-04 · otra cuenta no ve, no cambia ni borra un movimiento ajeno', async () => {
    const { as } = await setup();
    const { movement } = (await as('ana').create(cafe)).body;

    expect((await as('beto').list()).body.movements).toEqual([]);
    const ajeno = await as('beto').get(movement.id);
    const inexistente = await as('beto').get(randomUUID());
    expect(ajeno.status).toBe(404);
    expect(ajeno.body).toEqual(inexistente.body);
    expect((await as('beto').update(movement.id, { ...cafe, amount: -1 })).status).toBe(404);
    expect((await as('beto').remove(movement.id)).status).toBe(404);

    const sigue = await as('ana').get(movement.id);
    expect(sigue.body.movement).toMatchObject({ amount: -50, version: 1 });
  });

  test('MOV-06 · HU-05 · editar cambia los datos y sube la versión', async () => {
    const { as } = await setup();
    const { movement } = (await as('ana').create(cafe)).body;
    const res = await as('ana').update(movement.id, {
      amount: -80,
      description: 'Desayuno',
      category: 'Comida',
      date: '2026-11-27',
      version: 1,
    });
    expect(res.status).toBe(200);
    expect(res.body.movement).toMatchObject({ amount: -80, description: 'Desayuno', version: 2 });
    expect((await as('ana').get(movement.id)).body.movement.version).toBe(2);
  });

  test('MOV-07 · HU-36 · una versión vieja responde 409 VERSION_CONFLICT y no cambia nada', async () => {
    const { as } = await setup();
    const { movement } = (await as('ana').create(cafe)).body;
    await as('ana').update(movement.id, { ...cafe, amount: -60, version: 1 }).expect(200);

    const viejo = await as('ana').update(movement.id, { ...cafe, amount: -99, version: 1 });
    expect(viejo.status).toBe(409);
    expect(viejo.body.code).toBe('VERSION_CONFLICT');
    expect((await as('ana').get(movement.id)).body.movement).toMatchObject({ amount: -60, version: 2 });
  });

  test('MOV-08 · HU-06 · borrar responde 204 y el movimiento ya no existe', async () => {
    const { as } = await setup();
    const { movement } = (await as('ana').create(cafe)).body;
    expect((await as('ana').remove(movement.id)).status).toBe(204);
    expect((await as('ana').get(movement.id)).status).toBe(404);
    expect((await as('ana').remove(movement.id)).status).toBe(404);
  });

  test('MOV-09 · HU-16 · los pagos no se crean, cambian ni borran por esta ruta', async () => {
    const { as, store } = await setup();
    const pago = await as('ana').create({ ...cafe, type: 'payment', cardId: randomUUID() });
    expect(pago.status).toBe(400);
    expect(pago.body.fields.type).toBe(MESSAGES.paymentNotHere);

    // Un pago guardado (como lo hará S5-05) se lee, pero no se toca aquí.
    const ana = await store.findUserByEmail('ana@mail.com');
    const creado = await store.createMovement({ userId: ana.id, ...cafe, date: new Date('2026-11-26') });
    const guardado = await store.findMovementById(creado.id);
    Object.assign(guardado, { type: 'payment' });
    store.findMovementById = async (id) => (id === creado.id ? { ...guardado } : null);
    expect((await as('ana').update(creado.id, cafe)).body.fields.type).toBe(MESSAGES.paymentNotHere);
    expect((await as('ana').remove(creado.id)).body.fields.type).toBe(MESSAGES.paymentNotHere);
  });

  test('MOV-10 · HU-34 · HU-42 · userId del cuerpo se ignora y el contador recibe 403', async () => {
    const { as, store } = await setup();
    const beto = await store.findUserByEmail('beto@mail.com');
    const { movement } = (await as('ana').create({ ...cafe, userId: beto.id, user_id: beto.id })).body;
    expect((await store.findMovementById(movement.id)).userId).not.toBe(beto.id);
    expect((await as('beto').list()).body.movements).toEqual([]);

    expect((await as('carla').list()).status).toBe(403);
    expect((await as('carla').create(cafe)).status).toBe(403);
  });
});
