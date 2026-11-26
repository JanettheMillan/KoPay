// S4-05 · Conceder y revocar el acceso del contador (HU-38, HU-41).
//
// ROL-03, ROL-04, ROL-09, ROL-10 y ROL-12 son los casos de
// docs/reglas-roles-contador.md (sección 8) asignados a S4-05. ROL-09 se
// cubre aquí en la parte de S4-05 (el permiso deja de valer); S4-06 lo
// completa con la consulta del contador. ACC-01 a ACC-10 son pruebas
// nuevas de esta tarjeta, anotadas en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { createAccountantAccessService } = require('../src/services/accountant-access.service');
const { hashPassword } = require('../src/services/password.service');

const sinSesion = { error: 'Inicia sesión para continuar', code: 'UNAUTHENTICATED' };
const noEsContador = { error: 'No hay un contador con ese correo', code: 'NOT_FOUND' };
const permisoNoEncontrado = { error: 'No encontramos ese permiso', code: 'NOT_FOUND' };
const sinPermiso = { error: 'No tienes permiso para esta operación', code: 'FORBIDDEN' };

const CLAVE = 'kopay2026';

/**
 * App en memoria con dos personas usuarias (Ana y Beto) y dos contadores
 * (Carla y Dani). Los contadores se crean directo en el almacén, como el
 * script de semilla (S3-14 §1): la API no permite crearlos.
 */
async function setup() {
  let ahora = new Date('2026-11-26T18:00:00.000Z');
  const store = createMemoryStore({ now: () => ahora });
  const app = createApp({ store, now: () => ahora });
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
  for (const clave of Object.keys(cuentas)) {
    const res = await api
      .post('/api/auth/login')
      .send({ email: cuentas[clave].email, password: CLAVE })
      .expect(200);
    tokens[clave] = `Bearer ${res.body.accessToken}`;
  }

  const como = (quien) => ({
    listar: () => api.get('/api/accountants').set('Authorization', tokens[quien]),
    autorizar: (body) => api.post('/api/accountants').set('Authorization', tokens[quien]).send(body),
    revocar: (id) => api.delete(`/api/accountants/${id}`).set('Authorization', tokens[quien]),
  });

  return {
    api,
    store,
    cuentas,
    como,
    acceso: createAccountantAccessService({ store }),
    adelantar: (segundos) => {
      ahora = new Date(ahora.getTime() + segundos * 1000);
    },
  };
}

describe('POST /api/accountants · autorizar contador (HU-38)', () => {
  test('ACC-01 · HU-38 · autorizar a un contador → 201 con el permiso, y Ana lo ve en su lista', async () => {
    const { como, cuentas } = await setup();

    const res = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' });

    expect(res.status).toBe(201);
    expect(res.body).toEqual({
      grant: {
        id: expect.stringMatching(/^[0-9a-f-]{36}$/),
        accountant: { id: cuentas.carla.id, name: 'Carla Contadora', email: 'carla@conta.mx' },
        grantedAt: '2026-11-26T18:00:00.000Z',
      },
    });
    expect(JSON.stringify(res.body)).not.toMatch(/password|scrypt|role/i);

    const lista = await como('ana').listar();
    expect(lista.status).toBe(200);
    expect(lista.body).toEqual({ grants: [res.body.grant] });
  });

  test('ROL-03 · HU-38 · un correo que no es de contador, o que no existe → 404 y no se crea permiso', async () => {
    const { como, store, cuentas } = await setup();

    const deUsuario = await como('ana').autorizar({ accountantEmail: 'beto@mail.com' });
    const noExiste = await como('ana').autorizar({ accountantEmail: 'nadie@conta.mx' });

    expect(deUsuario.status).toBe(404);
    expect(deUsuario.body).toEqual(noEsContador);
    // Mismo cuerpo: no se puede averiguar qué correos tienen cuenta.
    expect(noExiste.status).toBe(404);
    expect(noExiste.body).toEqual(deUsuario.body);
    expect(await store.listGrantsByUser(cuentas.ana.id)).toEqual([]);
  });

  test('ROL-04 · HU-38 · autorizar dos veces al mismo contador → un solo permiso; la segunda es 200', async () => {
    const { como, store, cuentas } = await setup();

    const primera = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' });
    const segunda = await como('ana').autorizar({ accountantEmail: '  CARLA@Conta.MX ' });

    expect(primera.status).toBe(201);
    expect(segunda.status).toBe(200);
    expect(segunda.body).toEqual(primera.body);
    expect(await store.listGrantsByUser(cuentas.ana.id)).toHaveLength(1);
  });

  test('ACC-02 · HU-38 · correo vacío o mal escrito → 400 VALIDATION_FAILED con fields.accountantEmail', async () => {
    const { como } = await setup();
    const esperado = {
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: { accountantEmail: 'Escribe un correo válido' },
    };

    for (const body of [{}, { accountantEmail: '' }, { accountantEmail: 'carla' }, { accountantEmail: 42 }, []]) {
      const res = await como('ana').autorizar(body);
      expect(res.status).toBe(400);
      expect(res.body).toEqual(esperado);
    }
  });

  test('ACC-03 · HU-38 · se puede autorizar a varios contadores, y un contador puede tener varios clientes', async () => {
    const { como, acceso, cuentas } = await setup();

    await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);
    await como('ana').autorizar({ accountantEmail: 'dani@conta.mx' }).expect(201);
    await como('beto').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);

    const lista = await como('ana').listar();
    expect(lista.body.grants.map((g) => g.accountant.email)).toEqual([
      'carla@conta.mx',
      'dani@conta.mx',
    ]);
    expect(await acceso.hasAccess({ userId: cuentas.beto.id, accountantId: cuentas.carla.id })).toBe(true);
    expect(await acceso.hasAccess({ userId: cuentas.beto.id, accountantId: cuentas.dani.id })).toBe(false);
  });

  test('ACC-04 · HU-34 · el cuerpo no decide la cuenta: un userId ajeno se ignora', async () => {
    const { como, acceso, cuentas } = await setup();

    await como('ana')
      .autorizar({ accountantEmail: 'carla@conta.mx', userId: cuentas.beto.id })
      .expect(201);

    expect(await acceso.hasAccess({ userId: cuentas.ana.id, accountantId: cuentas.carla.id })).toBe(true);
    expect(await acceso.hasAccess({ userId: cuentas.beto.id, accountantId: cuentas.carla.id })).toBe(false);
    expect((await como('beto').listar()).body).toEqual({ grants: [] });
  });
});

describe('DELETE /api/accountants/:grantId · revocar (HU-41)', () => {
  test('ROL-09 · HU-41 · al revocar, el permiso deja de valer en la siguiente consulta y sale de la lista', async () => {
    const { como, acceso, cuentas } = await setup();
    const { body } = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);
    const pareja = { userId: cuentas.ana.id, accountantId: cuentas.carla.id };
    expect(await acceso.hasAccess(pareja)).toBe(true);

    const res = await como('ana').revocar(body.grant.id);

    expect(res.status).toBe(204);
    expect(res.text).toBe('');
    // Efecto inmediato, sin caché (reglas §4.2).
    expect(await acceso.hasAccess(pareja)).toBe(false);
    expect((await como('ana').listar()).body).toEqual({ grants: [] });
  });

  test('ROL-10 · HU-41 · revocar y volver a autorizar → permiso nuevo; el revocado conserva su revokedAt', async () => {
    const { como, store, cuentas, adelantar } = await setup();
    const primero = (await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' })).body.grant;
    adelantar(60);
    await como('ana').revocar(primero.id).expect(204);
    adelantar(60);

    const res = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' });

    expect(res.status).toBe(201);
    expect(res.body.grant.id).not.toBe(primero.id);
    expect(res.body.grant.grantedAt).toBe('2026-11-26T18:02:00.000Z');
    const historial = await store.listGrantsByUser(cuentas.ana.id);
    expect(historial).toHaveLength(2);
    expect(historial.find((g) => g.id === primero.id).revokedAt).toBe('2026-11-26T18:01:00.000Z');
    expect(historial.find((g) => g.id === res.body.grant.id).revokedAt).toBeNull();
  });

  test('ROL-12 · HU-41 · una persona intenta revocar el permiso de otra → 404 y el permiso sigue vigente', async () => {
    const { como, acceso, cuentas } = await setup();
    const { body } = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);

    const res = await como('beto').revocar(body.grant.id);

    expect(res.status).toBe(404);
    expect(res.body).toEqual(permisoNoEncontrado);
    expect(await acceso.hasAccess({ userId: cuentas.ana.id, accountantId: cuentas.carla.id })).toBe(true);
    expect((await como('ana').listar()).body.grants).toHaveLength(1);
  });

  test('ACC-05 · HU-41 · revocar dos veces, un id inexistente o mal formado → 404 con el mismo cuerpo', async () => {
    const { como } = await setup();
    const { body } = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);
    await como('ana').revocar(body.grant.id).expect(204);

    for (const id of [body.grant.id, '00000000-0000-4000-8000-000000000000', 'abc', '1']) {
      const res = await como('ana').revocar(id);
      expect(res.status).toBe(404);
      expect(res.body).toEqual(permisoNoEncontrado);
    }
  });

  test('ACC-06 · HU-41 · revocar un permiso no toca los de otros contadores ni los de otras personas', async () => {
    const { como, acceso, cuentas } = await setup();
    const carla = (await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' })).body.grant;
    await como('ana').autorizar({ accountantEmail: 'dani@conta.mx' }).expect(201);
    await como('beto').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);

    await como('ana').revocar(carla.id).expect(204);

    expect(await acceso.hasAccess({ userId: cuentas.ana.id, accountantId: cuentas.carla.id })).toBe(false);
    expect(await acceso.hasAccess({ userId: cuentas.ana.id, accountantId: cuentas.dani.id })).toBe(true);
    expect(await acceso.hasAccess({ userId: cuentas.beto.id, accountantId: cuentas.carla.id })).toBe(true);
  });
});

describe('/api/accountants · sesión y rol', () => {
  test('ACC-07 · HU-34 · sin sesión o con un token inválido → 401 en las tres rutas', async () => {
    const { api } = await setup();
    const id = '00000000-0000-4000-8000-000000000000';

    for (const auth of [undefined, 'Bearer token-falso']) {
      for (const req of [
        () => api.get('/api/accountants'),
        () => api.post('/api/accountants').send({ accountantEmail: 'carla@conta.mx' }),
        () => api.delete(`/api/accountants/${id}`),
      ]) {
        const r = req();
        const res = await (auth ? r.set('Authorization', auth) : r);
        expect(res.status).toBe(401);
        expect(res.body).toEqual(sinSesion);
      }
    }
  });

  test('ACC-08 · HU-38 · un contador no puede autorizarse a sí mismo ni administrar permisos → 403', async () => {
    const { como, store, cuentas } = await setup();

    const autorizar = await como('carla').autorizar({ accountantEmail: 'carla@conta.mx' });
    const listar = await como('carla').listar();

    expect(autorizar.status).toBe(403);
    expect(autorizar.body).toEqual(sinPermiso);
    expect(listar.status).toBe(403);
    expect(await store.listGrantsByUser(cuentas.carla.id)).toEqual([]);
  });

  test('ACC-09 · HU-41 · el contador no puede revocar un permiso que le dieron → 403 y sigue vigente', async () => {
    const { como, acceso, cuentas } = await setup();
    const { body } = await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);

    const res = await como('carla').revocar(body.grant.id);

    expect(res.status).toBe(403);
    expect(await acceso.hasAccess({ userId: cuentas.ana.id, accountantId: cuentas.carla.id })).toBe(true);
  });

  test('ACC-10 · HU-41 · si la cuenta del contador ya no existe, su permiso no aparece en la lista', async () => {
    const { como, store } = await setup();
    await como('ana').autorizar({ accountantEmail: 'carla@conta.mx' }).expect(201);
    const findUserById = store.findUserById;
    store.findUserById = async (id) => {
      const user = await findUserById(id);
      return user?.email === 'carla@conta.mx' ? null : user;
    };

    const res = await como('ana').listar();

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ grants: [] });
  });
});
