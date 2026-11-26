// S4-04 · Middleware de roles para usuario y contador (HU-34, HU-37, HU-42).
//
// Casos ROL-01 y ROL-11 de docs/reglas-roles-contador.md (sección 8) y
// casos nuevos RBAC-01 a RBAC-09, anotados en el PR.
//
// Todavía no hay sesión (S4-01) ni rutas financieras (S4-03, S5-xx): la
// prueba simula la sesión con un encabezado y monta rutas de ejemplo con
// los mismos guardias que usarán esas tarjetas.

const express = require('express');
const request = require('supertest');

const { errorHandler, notFound } = require('../src/middleware/errors');
const {
  MESSAGES,
  PERMISSIONS,
  ROLES,
  ROLE_PERMISSIONS,
  can,
  createRbac,
} = require('../src/middleware/rbac');

const ANA = '3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f'; // user
const LUIS = '9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c5d'; // accountant
const BORRADA = '00000000-0000-4000-8000-000000000000';

function buildApp({ roles, getUserRole } = {}) {
  const db = {
    roles: new Map(roles ?? [
      [ANA, ROLES.USER],
      [LUIS, ROLES.ACCOUNTANT],
    ]),
    movements: [{ id: 1, owner: ANA, amount: -50 }],
    roleReads: 0,
  };
  const rbac = createRbac({
    getUserRole:
      getUserRole ??
      (async (id) => {
        db.roleReads += 1;
        return db.roles.get(id) ?? null;
      }),
  });

  const app = express();
  app.use(express.json());
  // Sustituto de S4-01: la sesión llega en un encabezado de prueba. El
  // rol que mande la app se ignora a propósito.
  app.use((req, _res, next) => {
    const id = req.get('x-test-user');
    if (id) req.auth = { userId: id, role: req.get('x-test-role') };
    next();
  });

  const finances = express.Router();
  finances.use(rbac.ownFinances());
  finances.get('/', (req, res) =>
    res.json({ movements: db.movements.filter((m) => m.owner === req.user.id) }),
  );
  finances.post('/', (req, res) => {
    const movement = { id: db.movements.length + 1, owner: req.user.id, ...req.body };
    db.movements.push(movement);
    res.status(201).json({ movement });
  });
  app.use('/api/movements', finances);

  app.get('/api/accountants', rbac.manageAccountants(), (_req, res) =>
    res.json({ grants: [] }),
  );

  const clients = express.Router();
  clients.use(rbac.readClients());
  clients.get('/', (_req, res) => res.json({ clients: [] }));
  clients.get('/:userId/movements', (req, res) =>
    res.json({ movements: db.movements.filter((m) => m.owner === req.params.userId) }),
  );
  // Rutas de escritura puestas a propósito: readOnly debe bloquearlas.
  const write = (_req, res) => {
    db.movements.length = 0;
    res.status(200).json({ ok: true });
  };
  clients.post('/:userId/movements', write);
  clients.put('/:userId/movements', write);
  clients.delete('/:userId/movements', write);
  app.use('/api/clients', clients);

  app.use(notFound);
  app.use(errorHandler);
  return { app, db };
}

const as = (id) => ({ 'x-test-user': id });

describe('Rol user', () => {
  test('RBAC-01 · HU-37 · una cuenta user usa sus finanzas y sus contadores', async () => {
    const { app } = buildApp();

    const list = await request(app).get('/api/movements').set(as(ANA));
    expect(list.status).toBe(200);
    expect(list.body.movements).toHaveLength(1);

    const created = await request(app)
      .post('/api/movements')
      .set(as(ANA))
      .send({ amount: -20 });
    expect(created.status).toBe(201);

    expect((await request(app).get('/api/accountants').set(as(ANA))).status).toBe(200);
  });

  test('RBAC-02 · HU-37 · una cuenta user no entra a /api/clients', async () => {
    const { app } = buildApp();
    const res = await request(app).get('/api/clients').set(as(ANA));

    expect(res.status).toBe(403);
    expect(res.body).toEqual({ error: MESSAGES.clientForbidden, code: 'FORBIDDEN' });
  });
});

describe('Rol accountant', () => {
  test('ROL-01 · HU-37 · una cuenta accountant recibe 403 en las rutas financieras', async () => {
    const { app, db } = buildApp();

    const read = await request(app).get('/api/movements').set(as(LUIS));
    const write = await request(app)
      .post('/api/movements')
      .set(as(LUIS))
      .send({ amount: -999, owner: ANA });
    const grants = await request(app).get('/api/accountants').set(as(LUIS));

    for (const res of [read, write, grants]) {
      expect(res.status).toBe(403);
      expect(res.body).toEqual({ error: MESSAGES.forbidden, code: 'FORBIDDEN' });
    }
    expect(db.movements).toHaveLength(1);
  });

  test('RBAC-03 · HU-37 · una cuenta accountant puede leer bajo /api/clients', async () => {
    const { app } = buildApp();

    expect((await request(app).get('/api/clients').set(as(LUIS))).status).toBe(200);
    const res = await request(app).get(`/api/clients/${ANA}/movements`).set(as(LUIS));
    expect(res.status).toBe(200);
  });

  test('ROL-11 · HU-42 · el contador no puede escribir sobre datos de un cliente', async () => {
    const { app, db } = buildApp();

    for (const method of ['post', 'put', 'delete']) {
      const res = await request(app)
        [method](`/api/clients/${ANA}/movements`)
        .set(as(LUIS))
        .send({ amount: -1 });
      expect(res.status).toBe(403);
      expect(res.body).toEqual({ error: MESSAGES.clientForbidden, code: 'FORBIDDEN' });
    }
    // Los datos no cambiaron.
    expect(db.movements).toEqual([{ id: 1, owner: ANA, amount: -50 }]);
  });
});

describe('Sesión y origen del rol', () => {
  test('RBAC-04 · HU-34 · sin sesión responde 401 antes de revisar el rol', async () => {
    const { app, db } = buildApp();

    for (const path of ['/api/movements', '/api/accountants', '/api/clients']) {
      const res = await request(app).get(path);
      expect(res.status).toBe(401);
      expect(res.body).toEqual({ error: MESSAGES.unauthenticated, code: 'UNAUTHENTICATED' });
    }
    expect(db.roleReads).toBe(0);
  });

  test('RBAC-05 · HU-34 · se ignora el rol que manda la app', async () => {
    const { app } = buildApp();

    const res = await request(app)
      .get('/api/movements')
      .set({ ...as(LUIS), 'x-test-role': 'user' });
    expect(res.status).toBe(403);

    const res2 = await request(app)
      .get('/api/clients')
      .set({ ...as(ANA), 'x-test-role': 'accountant' });
    expect(res2.status).toBe(403);
  });

  test('RBAC-06 · HU-34 · el rol se lee de la base en cada petición', async () => {
    const { app, db } = buildApp();

    await request(app).get('/api/movements').set(as(ANA));
    await request(app).get('/api/movements').set(as(ANA));
    expect(db.roleReads).toBe(2);

    // Si el rol cambia en la base, la siguiente petición ya lo usa.
    db.roles.set(ANA, ROLES.ACCOUNTANT);
    expect((await request(app).get('/api/movements').set(as(ANA))).status).toBe(403);
  });

  test('RBAC-07 · HU-34 · una cuenta borrada o con rol desconocido no pasa', async () => {
    const { app } = buildApp({
      roles: [
        [ANA, ROLES.USER],
        ['raro', 'admin'],
      ],
    });

    const borrada = await request(app).get('/api/movements').set(as(BORRADA));
    expect(borrada.status).toBe(401);

    for (const path of ['/api/movements', '/api/accountants', '/api/clients']) {
      expect((await request(app).get(path).set(as('raro'))).status).toBe(403);
    }
  });

  test('RBAC-08 · HU-34 · si la base no responde, 503 sin detalles internos', async () => {
    const { app } = buildApp({
      getUserRole: async () => {
        throw new Error('connect ECONNREFUSED 10.0.0.5:5432');
      },
    });
    const res = await request(app).get('/api/movements').set(as(ANA));

    expect(res.status).toBe(503);
    expect(res.body).toEqual({ error: MESSAGES.unavailable, code: 'UNAVAILABLE' });
    expect(JSON.stringify(res.body)).not.toContain('5432');
  });
});

describe('Tabla de permisos', () => {
  test('RBAC-09 · HU-37 · cada rol tiene únicamente sus operaciones', () => {
    expect(ROLE_PERMISSIONS).toEqual({
      user: [PERMISSIONS.OWN_FINANCES, PERMISSIONS.MANAGE_ACCOUNTANTS],
      accountant: [PERMISSIONS.READ_CLIENTS],
    });
    expect(can('user', PERMISSIONS.READ_CLIENTS)).toBe(false);
    expect(can('accountant', PERMISSIONS.OWN_FINANCES)).toBe(false);
    expect(can('accountant', PERMISSIONS.MANAGE_ACCOUNTANTS)).toBe(false);
    expect(can(undefined, PERMISSIONS.OWN_FINANCES)).toBe(false);
    expect(Object.isFrozen(ROLE_PERMISSIONS.user)).toBe(true);
    expect(() => createRbac({}).requirePermission).toThrow('getUserRole');
    expect(() =>
      createRbac({ getUserRole: async () => 'user' }).requirePermission('todo'),
    ).toThrow('Permiso desconocido');
  });
});
