// S4-06 · Consultas autorizadas del contador (HU-39, HU-40, HU-42).
//
// ROL-06, ROL-08, ROL-09 y ROL-11 son casos de docs/reglas-roles-contador.md
// (sección 8) asignados a S4-06. ROL-09 completa aquí la parte del contador
// (S4-05 cubrió la de la persona usuaria). ROL-07 (resumen y movimientos del
// mes) lo automatiza S5-03, que crea esas consultas sobre este guardia.
// CLI-01 a CLI-07 son pruebas nuevas de esta tarjeta, anotadas en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { hashPassword } = require('../src/services/password.service');

const sinSesion = { error: 'Inicia sesión para continuar', code: 'UNAUTHENTICATED' };
const sinAcceso = { error: 'No tienes acceso a los datos de esta persona', code: 'FORBIDDEN' };
const NO_EXISTE = '00000000-0000-4000-8000-000000000000';
const CLAVE = 'kopay2026';

/**
 * App en memoria con tres personas usuarias (Ana, Beto y Eva) y dos
 * contadores (Carla y Dani), creados directo en el almacén como el script
 * de semilla (reglas §1).
 */
async function setup() {
  let ahora = new Date('2026-11-26T18:00:00.000Z');
  const store = createMemoryStore({ now: () => ahora });
  const api = request(createApp({ store, now: () => ahora }));
  const passwordHash = await hashPassword(CLAVE);

  const cuentas = {};
  for (const [clave, name, email] of [
    ['ana', 'Ana López', 'ana@mail.com'],
    ['beto', 'Beto Ruiz', 'beto@mail.com'],
    ['eva', 'Eva Sol', 'eva@mail.com'],
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

  /** Peticiones con la sesión de `quien`. */
  const como = (quien) => ({
    get: (ruta) => api.get(ruta).set('Authorization', tokens[quien]),
    pedir: (metodo, ruta) => api[metodo](ruta).set('Authorization', tokens[quien]),
  });

  /** La persona `quien` autoriza al contador con ese correo (S4-05). */
  const autorizar = async (quien, accountantEmail) =>
    (await como(quien).pedir('post', '/api/accountants').send({ accountantEmail }).expect(201))
      .body.grant;

  return {
    api,
    store,
    cuentas,
    como,
    autorizar,
    revocar: (quien, grantId) =>
      como(quien).pedir('delete', `/api/accountants/${grantId}`).expect(204),
    adelantar: (segundos) => {
      ahora = new Date(ahora.getTime() + segundos * 1000);
    },
  };
}

describe('GET /api/clients · lista de clientes (HU-39)', () => {
  test('ROL-06 · HU-39 · el contador A solo ve a quienes lo autorizaron y siguen vigentes', async () => {
    const { como, autorizar, revocar, cuentas, adelantar } = await setup();
    await autorizar('ana', 'carla@conta.mx');
    adelantar(60);
    await autorizar('beto', 'carla@conta.mx');
    const deEva = await autorizar('eva', 'carla@conta.mx');
    await autorizar('eva', 'dani@conta.mx');
    await revocar('eva', deEva.id);

    const res = await como('carla').get('/api/clients');

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      clients: [
        { id: cuentas.ana.id, name: 'Ana López', email: 'ana@mail.com', grantedAt: '2026-11-26T18:00:00.000Z' },
        { id: cuentas.beto.id, name: 'Beto Ruiz', email: 'beto@mail.com', grantedAt: '2026-11-26T18:01:00.000Z' },
      ],
    });
    const deDani = await como('dani').get('/api/clients');
    expect(deDani.body.clients.map((c) => c.email)).toEqual(['eva@mail.com']);
  });

  test('CLI-01 · HU-39 · sin clientes → 200 con lista vacía, y la lista no trae datos privados', async () => {
    const { como, autorizar } = await setup();

    const vacia = await como('carla').get('/api/clients');
    await autorizar('ana', 'carla@conta.mx');
    const conAna = await como('carla').get('/api/clients');

    expect(vacia.status).toBe(200);
    expect(vacia.body).toEqual({ clients: [] });
    expect(JSON.stringify(conAna.body)).not.toMatch(/password|scrypt|role|token/i);
  });
});

describe('/api/clients/:userId · permiso vigente (HU-40)', () => {
  test('CLI-02 · HU-40 · con permiso vigente → 200 con los datos de la persona', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');

    const res = await como('carla').get(`/api/clients/${cuentas.ana.id}`);

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      client: {
        id: cuentas.ana.id,
        name: 'Ana López',
        email: 'ana@mail.com',
        grantedAt: '2026-11-26T18:00:00.000Z',
      },
    });
  });

  test('ROL-08 · HU-34 · un :userId sin permiso, inexistente o mal formado → 403 con el mismo cuerpo', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');
    // Beto autorizó a otro contador, no a Carla.
    await autorizar('beto', 'dani@conta.mx');

    for (const id of [cuentas.beto.id, NO_EXISTE, 'abc', cuentas.carla.id, cuentas.dani.id]) {
      const res = await como('carla').get(`/api/clients/${id}`);
      expect(res.status).toBe(403);
      expect(res.body).toEqual(sinAcceso);
    }
  });

  test('ROL-09 · HU-41 · al revocar, la siguiente consulta del contador es 403 y la persona sale de su lista', async () => {
    const { como, autorizar, revocar, cuentas } = await setup();
    const grant = await autorizar('ana', 'carla@conta.mx');
    await como('carla').get(`/api/clients/${cuentas.ana.id}`).expect(200);

    await revocar('ana', grant.id);

    const res = await como('carla').get(`/api/clients/${cuentas.ana.id}`);
    expect(res.status).toBe(403);
    expect(res.body).toEqual(sinAcceso);
    expect((await como('carla').get('/api/clients')).body).toEqual({ clients: [] });
  });

  test('CLI-03 · HU-41 · el permiso se consulta en cada petición: volver a autorizar devuelve el acceso', async () => {
    const { como, autorizar, revocar, cuentas, adelantar } = await setup();
    const primero = await autorizar('ana', 'carla@conta.mx');
    await revocar('ana', primero.id);
    await como('carla').get(`/api/clients/${cuentas.ana.id}`).expect(403);
    adelantar(120);

    await autorizar('ana', 'carla@conta.mx');

    const res = await como('carla').get(`/api/clients/${cuentas.ana.id}`);
    expect(res.status).toBe(200);
    expect(res.body.client.grantedAt).toBe('2026-11-26T18:02:00.000Z');
  });

  test('CLI-04 · HU-34 · el identificador que cuenta es el de la URL, no el de la consulta ni el cuerpo', async () => {
    const { como, autorizar, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');

    const res = await como('carla').get(`/api/clients/${cuentas.beto.id}?userId=${cuentas.ana.id}`);
    const propio = await como('carla').get(`/api/clients/${cuentas.ana.id}?userId=${cuentas.beto.id}`);

    expect(res.status).toBe(403);
    expect(propio.status).toBe(200);
    expect(propio.body.client.id).toBe(cuentas.ana.id);
  });

  test('CLI-05 · HU-41 · si la cuenta de la persona ya no existe → 403 y no aparece en la lista', async () => {
    const { como, autorizar, store, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');
    const findUserById = store.findUserById;
    store.findUserById = async (id) => (id === cuentas.ana.id ? null : findUserById(id));

    const detalle = await como('carla').get(`/api/clients/${cuentas.ana.id}`);
    const lista = await como('carla').get('/api/clients');

    expect(detalle.status).toBe(403);
    expect(detalle.body).toEqual(sinAcceso);
    expect(lista.body).toEqual({ clients: [] });
  });
});

describe('/api/clients · sesión, rol y solo lectura (HU-42)', () => {
  test('ROL-11 · HU-42 · POST, PUT, PATCH o DELETE sobre datos de un cliente → 403 y nada cambia', async () => {
    const { como, autorizar, store, cuentas } = await setup();
    await autorizar('ana', 'carla@conta.mx');
    const antes = { user: await store.findUserById(cuentas.ana.id), grants: await store.listGrantsByUser(cuentas.ana.id) };

    for (const ruta of [
      '/api/clients',
      `/api/clients/${cuentas.ana.id}`,
      `/api/clients/${cuentas.ana.id}/movements`,
      `/api/clients/${cuentas.ana.id}/incomes/1`,
    ]) {
      for (const metodo of ['post', 'put', 'patch', 'delete']) {
        const res = await como('carla').pedir(metodo, ruta).send({ amount: 1, name: 'Hack' });
        expect(res.status).toBe(403);
        expect(res.body).toEqual(sinAcceso);
      }
    }

    expect(await store.findUserById(cuentas.ana.id)).toEqual(antes.user);
    expect(await store.listGrantsByUser(cuentas.ana.id)).toEqual(antes.grants);
  });

  test('CLI-06 · HU-37 · una cuenta user no entra a /api/clients, ni con su propio id', async () => {
    const { como, cuentas } = await setup();

    for (const ruta of ['/api/clients', `/api/clients/${cuentas.ana.id}`, `/api/clients/${cuentas.beto.id}`]) {
      const res = await como('ana').get(ruta);
      expect(res.status).toBe(403);
      expect(res.body).toEqual(sinAcceso);
    }
  });

  test('CLI-07 · HU-34 · sin sesión o con token inválido → 401 antes de revisar rol o permiso', async () => {
    const { api, cuentas } = await setup();

    for (const ruta of ['/api/clients', `/api/clients/${cuentas.ana.id}`, `/api/clients/${NO_EXISTE}`]) {
      for (const auth of [undefined, 'Bearer token-falso']) {
        const req = api.get(ruta);
        const res = await (auth ? req.set('Authorization', auth) : req);
        expect(res.status).toBe(401);
        expect(res.body).toEqual(sinSesion);
      }
    }
  });
});
