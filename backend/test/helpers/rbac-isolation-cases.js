// S4-17 · Casos de roles y aislamiento entre cuentas. Se definen una vez
// y se ejecutan con el almacén en memoria (rbac-isolation.test.js) y con
// PostgreSQL (db/rbac-isolation.test.js).
//
// Recorren la app completa: registro, login y token reales. FUT-22 y
// FUT-30 son casos de docs/plan-de-pruebas.md; AIS-01 a AIS-05 son
// pruebas nuevas de esta tarjeta, descritas en docs/pruebas-s4-17.md.

const request = require('supertest');

const { hashPassword } = require('../../src/services/password.service');

const CLAVE = 'kopay2026';

const SIN_SESION = { error: 'Inicia sesión para continuar', code: 'UNAUTHENTICATED' };
const SIN_PERMISO = { error: 'No tienes permiso para esta operación', code: 'FORBIDDEN' };
const SIN_ACCESO = { error: 'No tienes acceso a los datos de esta persona', code: 'FORBIDDEN' };

/**
 * Ana autoriza a Carla y Beto autoriza a Dani. Así Dani es un contador
 * real, con un cliente, pero sin permiso sobre Ana. Los contadores se
 * crean directo en el almacén, como el script de semilla.
 */
async function prepararCuentas({ app, store }) {
  const api = request(app);
  const passwordHash = await hashPassword(CLAVE);
  const cuentas = {};

  for (const [clave, name, email] of [
    ['ana', 'Ana López', 'ana@mail.com'],
    ['beto', 'Beto Ruiz', 'beto@mail.com'],
  ]) {
    await api.post('/api/auth/register').send({ name, email, password: CLAVE }).expect(201);
    cuentas[clave] = await store.findUserByEmail(email);
  }
  for (const [clave, name, email] of [
    ['carla', 'Carla Contadora', 'carla@conta.mx'],
    ['dani', 'Dani Contador', 'dani@conta.mx'],
  ]) {
    cuentas[clave] = await store.createUser({ name, email, passwordHash, role: 'accountant' });
  }

  const tokens = {};
  for (const [clave, cuenta] of Object.entries(cuentas)) {
    const res = await api
      .post('/api/auth/login')
      .send({ email: cuenta.email, password: CLAVE })
      .expect(200);
    tokens[clave] = `Bearer ${res.body.accessToken}`;
  }

  /** Petición de `quien`; con `null` va sin sesión. */
  const pedir = (quien, metodo, ruta, body) => {
    const peticion = api[metodo](ruta);
    if (quien) peticion.set('Authorization', tokens[quien]);
    return body ? peticion.send(body) : peticion;
  };

  const autorizar = async (quien, contador) =>
    (
      await pedir(quien, 'post', '/api/accountants', {
        accountantEmail: cuentas[contador].email,
      }).expect(201)
    ).body.grant;

  const permisos = {
    ana: await autorizar('ana', 'carla'),
    beto: await autorizar('beto', 'dani'),
  };

  return { cuentas, permisos, pedir, autorizar };
}

const ACTORES = [
  ['sin sesión', null],
  ['la usuaria dueña (Ana)', 'ana'],
  ['otro usuario (Beto)', 'beto'],
  ['la contadora con permiso (Carla)', 'carla'],
  ['el contador sin permiso (Dani)', 'dani'],
];

/** Estado esperado por actor, en el mismo orden que ACTORES. */
const MATRIZ = [
  ['GET /api/accountants', 'get', () => '/api/accountants', [401, 200, 200, 403, 403]],
  [
    'DELETE del permiso de Ana, sin ser Ana',
    'delete',
    ({ permisos }) => `/api/accountants/${permisos.ana.id}`,
    [401, null, 404, 403, 403],
  ],
  ['GET /api/clients', 'get', () => '/api/clients', [401, 403, 403, 200, 200]],
  [
    'GET /api/clients/:ana',
    'get',
    ({ cuentas }) => `/api/clients/${cuentas.ana.id}`,
    [401, 403, 403, 200, 403],
  ],
  ...['post', 'put', 'patch', 'delete'].map((metodo) => [
    `${metodo.toUpperCase()} /api/clients/:ana`,
    metodo,
    ({ cuentas }) => `/api/clients/${cuentas.ana.id}`,
    [401, 403, 403, 403, 403],
  ]),
];

const CELDAS = MATRIZ.flatMap(([nombre, metodo, ruta, estados]) =>
  ACTORES.map(([actor, clave], i) => [nombre, actor, estados[i], metodo, ruta, clave]).filter(
    // `null`: Ana sí puede revocar su permiso; eso lo cubre FUT-30.
    (celda) => celda[2] !== null,
  ),
);

/** [crearContexto] devuelve `{ app, store }` con la base vacía. */
function definirCasosDeAislamiento(crearContexto) {
  let ctx;
  beforeEach(async () => {
    ctx = await prepararCuentas(await crearContexto());
  });

  test.each(CELDAS)(
    'AIS-01 · HU-34 · HU-37 · %s por %s → %i',
    async (_nombre, _actor, estado, metodo, ruta, quien) => {
      const res = await ctx.pedir(quien, metodo, ruta(ctx));

      expect(res.status).toBe(estado);
      if (estado === 401) expect(res.body).toEqual(SIN_SESION);
      if (estado === 403) expect([SIN_PERMISO, SIN_ACCESO]).toContainEqual(res.body);
      // Ninguna petición de la matriz cambia el permiso de Ana.
      const { body } = await ctx.pedir('ana', 'get', '/api/accountants').expect(200);
      expect(body.grants).toEqual([ctx.permisos.ana]);
    },
  );

  test('AIS-02 · HU-39 · cada contador ve solo a su cliente y sin datos privados', async () => {
    for (const [contador, persona] of [
      ['carla', 'ana'],
      ['dani', 'beto'],
    ]) {
      const res = await ctx.pedir(contador, 'get', '/api/clients').expect(200);

      const { id, name, email } = ctx.cuentas[persona];
      expect(res.body).toEqual({
        clients: [{ id, name, email, grantedAt: ctx.permisos[persona].grantedAt }],
      });
    }
  });

  test('AIS-03 · HU-34 · cada persona ve solo sus propios permisos', async () => {
    for (const persona of ['ana', 'beto']) {
      const res = await ctx.pedir(persona, 'get', '/api/accountants').expect(200);

      expect(res.body).toEqual({ grants: [ctx.permisos[persona]] });
    }
  });

  test('AIS-04 · HU-34 · el userId del cuerpo o de la consulta no abre datos ajenos', async () => {
    const ajeno = ctx.cuentas.beto.id;

    const lista = await ctx
      .pedir('ana', 'get', `/api/accountants?userId=${ajeno}`, { userId: ajeno })
      .expect(200);
    expect(lista.body).toEqual({ grants: [ctx.permisos.ana] });

    await ctx
      .pedir('dani', 'get', `/api/clients/${ctx.cuentas.ana.id}?userId=${ajeno}`, {
        userId: ajeno,
      })
      .expect(403, SIN_ACCESO);
  });

  test('FUT-22 · HU-38 · solo la relación vigente permite consultar', async () => {
    const ruta = `/api/clients/${ctx.cuentas.ana.id}`;
    await ctx.pedir('carla', 'get', ruta).expect(200);

    await ctx.pedir('ana', 'delete', `/api/accountants/${ctx.permisos.ana.id}`).expect(204);
    await ctx.pedir('carla', 'get', ruta).expect(403, SIN_ACCESO);

    const nuevo = await ctx.autorizar('ana', 'carla');
    expect(nuevo.id).not.toBe(ctx.permisos.ana.id);
    await ctx.pedir('carla', 'get', ruta).expect(200);
  });

  test('FUT-30 · HU-41 · revocar bloquea la siguiente petición con la misma sesión', async () => {
    await ctx.pedir('ana', 'delete', `/api/accountants/${ctx.permisos.ana.id}`).expect(204);

    await ctx
      .pedir('carla', 'get', `/api/clients/${ctx.cuentas.ana.id}`)
      .expect(403, SIN_ACCESO);
    // La sesión sigue viva: lo que se retiró es el permiso, no el login.
    await ctx.pedir('carla', 'get', '/api/auth/me').expect(200);
    const lista = await ctx.pedir('carla', 'get', '/api/clients').expect(200);
    expect(lista.body).toEqual({ clients: [] });
  });

  test('AIS-05 · HU-41 · revocar una pareja no afecta a las demás', async () => {
    await ctx.autorizar('ana', 'dani');

    await ctx.pedir('ana', 'delete', `/api/accountants/${ctx.permisos.ana.id}`).expect(204);

    const deAna = `/api/clients/${ctx.cuentas.ana.id}`;
    await ctx.pedir('carla', 'get', deAna).expect(403, SIN_ACCESO);
    await ctx.pedir('dani', 'get', deAna).expect(200);
    await ctx.pedir('dani', 'get', `/api/clients/${ctx.cuentas.beto.id}`).expect(200);
  });
}

module.exports = { definirCasosDeAislamiento };
