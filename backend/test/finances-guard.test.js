'use strict';

// S4-03 · Proteger rutas financieras por identidad (HU-34).
// Casos nuevos FIN-01 a FIN-07. Criterio de la tarjeta: cada petición
// identifica al usuario y evita consultar recursos ajenos.
//
// Las rutas reales de movimientos, ingresos, tarjetas y deudas llegan en
// S5-01 a S5-05. Aquí se registra un recurso de prueba en memoria detrás
// de la misma protección, como lo harán esas tarjetas.

const { randomUUID } = require('node:crypto');
const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { OWNER_FIELDS, ensureOwned } = require('../src/middleware/owner');
const { FINANCE_RESOURCES } = require('../src/routes/finances.routes');
const { hashPassword } = require('../src/services/password.service');

const CLAVE = 'kopay2026';
const noEncontrado = { error: 'No encontramos ese registro', code: 'NOT_FOUND' };

/** Recurso de prueba: lo que hará S5-01 con `movements`. */
function fakeMovements() {
  const rows = new Map();
  return (router) => {
    router.post('/', (req, res) => {
      const row = { id: randomUUID(), userId: req.ownerId, description: req.body.description };
      rows.set(row.id, row);
      res.status(201).json({ movement: row, bodyOwnerFields: OWNER_FIELDS.filter((f) => f in req.body) });
    });
    router.get('/', (req, res) => {
      const own = [...rows.values()].filter((r) => r.userId === req.ownerId);
      res.status(200).json({ movements: own, queryOwnerFields: OWNER_FIELDS.filter((f) => f in req.query) });
    });
    router.get('/:id', (req, res) => {
      res.status(200).json({ movement: ensureOwned(rows.get(req.params.id), req.ownerId) });
    });
    router.delete('/:id', (req, res) => {
      ensureOwned(rows.get(req.params.id), req.ownerId);
      rows.delete(req.params.id);
      res.status(204).end();
    });
  };
}

async function setup() {
  const store = createMemoryStore();
  const api = request(createApp({ store, financeRegistrars: { movements: fakeMovements() } }));
  const cuentas = {};
  for (const [clave, email] of [['ana', 'ana@mail.com'], ['beto', 'beto@mail.com']]) {
    await api.post('/api/auth/register').send({ name: clave, email, password: CLAVE }).expect(201);
    cuentas[clave] = await store.findUserByEmail(email);
  }
  cuentas.carla = await store.createUser({
    name: 'Carla Contadora',
    email: 'carla@conta.mx',
    passwordHash: await hashPassword(CLAVE),
    role: 'accountant',
  });
  const tokens = {};
  for (const [clave, user] of Object.entries(cuentas)) {
    const res = await api.post('/api/auth/login').send({ email: user.email, password: CLAVE }).expect(200);
    tokens[clave] = `Bearer ${res.body.accessToken}`;
  }
  return { api, cuentas, tokens };
}

describe('Protección de las rutas financieras', () => {
  test('FIN-01 · HU-34 · sin sesión, cada recurso financiero responde 401', async () => {
    const { api } = await setup();
    for (const resource of FINANCE_RESOURCES) {
      const res = await api.get(`/api/${resource}`);
      expect(res.status).toBe(401);
      expect(res.body.code).toBe('UNAUTHENTICATED');
      expect((await api.get(`/api/${resource}`).set('Authorization', 'Bearer x.y.z')).status).toBe(401);
    }
  });

  test('FIN-02 · HU-37 · HU-42 · el contador no tiene finanzas propias: 403 en lectura y escritura', async () => {
    const { api, tokens } = await setup();
    for (const resource of FINANCE_RESOURCES) {
      const get = await api.get(`/api/${resource}`).set('Authorization', tokens.carla);
      expect(get.status).toBe(403);
      expect(get.body.code).toBe('FORBIDDEN');
      const post = await api.post(`/api/${resource}`).set('Authorization', tokens.carla).send({});
      expect(post.status).toBe(403);
    }
  });

  test('FIN-03 · HU-34 · un recurso sin rutas todavía responde 404 a una cuenta user, no 500', async () => {
    const { api, tokens } = await setup();
    for (const resource of ['incomes', 'cards', 'debts']) {
      const res = await api.get(`/api/${resource}`).set('Authorization', tokens.ana);
      expect(res.status).toBe(404);
      expect(res.body.code).toBe('NOT_FOUND');
    }
  });

  test('FIN-04 · HU-34 · el dueño sale de la sesión: userId en el cuerpo o la consulta se ignora', async () => {
    const { api, cuentas, tokens } = await setup();
    const creado = await api
      .post('/api/movements')
      .set('Authorization', tokens.ana)
      .send({ description: 'Café', userId: cuentas.beto.id, user_id: cuentas.beto.id, ownerId: cuentas.beto.id });
    expect(creado.status).toBe(201);
    expect(creado.body.movement.userId).toBe(cuentas.ana.id);
    expect(creado.body.bodyOwnerFields).toEqual([]);

    const lista = await api
      .get(`/api/movements?userId=${cuentas.beto.id}&user_id=${cuentas.beto.id}`)
      .set('Authorization', tokens.ana);
    expect(lista.body.queryOwnerFields).toEqual([]);
    expect(lista.body.movements.map((m) => m.description)).toEqual(['Café']);

    // Beto, aunque pida los de Ana por la consulta, solo ve los suyos.
    const deBeto = await api.get(`/api/movements?userId=${cuentas.ana.id}`).set('Authorization', tokens.beto);
    expect(deBeto.body.movements).toEqual([]);
  });

  test('FIN-05 · HU-34 · DB-04 · pedir el registro de otra cuenta responde 404, igual que uno inexistente', async () => {
    const { api, tokens } = await setup();
    const { movement } = (
      await api.post('/api/movements').set('Authorization', tokens.ana).send({ description: 'Renta' })
    ).body;

    const ajeno = await api.get(`/api/movements/${movement.id}`).set('Authorization', tokens.beto);
    const inexistente = await api.get(`/api/movements/${randomUUID()}`).set('Authorization', tokens.beto);
    expect(ajeno.status).toBe(404);
    expect(ajeno.body).toEqual(noEncontrado);
    expect(inexistente.body).toEqual(ajeno.body);

    expect((await api.get(`/api/movements/${movement.id}`).set('Authorization', tokens.ana)).status).toBe(200);
  });

  test('FIN-06 · HU-34 · nadie borra un registro ajeno; la fila sigue intacta', async () => {
    const { api, tokens } = await setup();
    const { movement } = (
      await api.post('/api/movements').set('Authorization', tokens.ana).send({ description: 'Luz' })
    ).body;
    expect((await api.delete(`/api/movements/${movement.id}`).set('Authorization', tokens.beto)).status).toBe(404);
    const sigue = await api.get(`/api/movements/${movement.id}`).set('Authorization', tokens.ana);
    expect(sigue.body.movement.description).toBe('Luz');
  });
});

describe('ensureOwned', () => {
  test('FIN-07 · HU-34 · devuelve el registro propio y lanza 404 si falta, es ajeno o no hay dueño', () => {
    const row = { id: '1', userId: 'ana' };
    expect(ensureOwned(row, 'ana')).toBe(row);
    for (const [record, owner] of [[row, 'beto'], [null, 'ana'], [undefined, 'ana'], [row, undefined]]) {
      expect(() => ensureOwned(record, owner)).toThrow(expect.objectContaining({ status: 404 }));
    }
    expect(ensureOwned({ owner: 'ana' }, 'ana', { ownerOf: (r) => r.owner })).toEqual({ owner: 'ana' });
  });
});
