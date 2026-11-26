// S3-09 · Sesiones en la capa PostgreSQL (HU-31).
//
// Prueba sin base de datos: un pool falso revisa la consulta y convierte
// las filas como lo haría `pg`. Las pruebas contra una base real están en
// test/db (`npm run test:db`). LOG-10 y LOG-11 son pruebas nuevas.

const { createPgStore } = require('../src/data/pg-store');

/** Pool falso: guarda cada consulta y responde con las filas dadas. */
function fakePool(rows) {
  const queries = [];
  class FakePool {
    on() {}
    async query(text, params) {
      queries.push({ text, params });
      return { rows };
    }
    async end() {}
  }
  return { FakePool, queries };
}

const creada = new Date('2026-11-26T18:00:00.000Z');
const vence = new Date('2026-11-26T18:15:00.000Z');

describe('pg-store · sesiones', () => {
  test('LOG-10 · HU-31 · createSession guarda solo el hash y devuelve la sesión', async () => {
    const fila = {
      id: 's1',
      user_id: 'u1',
      token_hash: 'abc123',
      created_at: creada,
      expires_at: vence,
      revoked_at: null,
    };
    const { FakePool, queries } = fakePool([fila]);
    const store = createPgStore({ databaseUrl: 'postgres://prueba', PoolClass: FakePool });

    const sesion = await store.createSession({
      userId: 'u1',
      tokenHash: 'abc123',
      expiresAt: vence.toISOString(),
    });

    expect(queries[0].text).toMatch(/INSERT INTO sessions \(user_id, token_hash, expires_at\)/);
    expect(queries[0].params).toEqual(['u1', 'abc123', vence.toISOString()]);
    expect(sesion).toEqual({
      id: 's1',
      userId: 'u1',
      tokenHash: 'abc123',
      createdAt: creada.toISOString(),
      expiresAt: vence.toISOString(),
      revokedAt: null,
    });
  });

  test('LOG-11 · HU-31 · findSessionByTokenHash y findUserById buscan por su llave', async () => {
    const revocada = new Date('2026-11-26T18:05:00.000Z');
    const sesiones = fakePool([
      { id: 's1', user_id: 'u1', token_hash: 'abc', created_at: creada, expires_at: vence, revoked_at: revocada },
    ]);
    const vacio = fakePool([]);
    const conSesion = createPgStore({ databaseUrl: 'postgres://prueba', PoolClass: sesiones.FakePool });
    const sinFilas = createPgStore({ databaseUrl: 'postgres://prueba', PoolClass: vacio.FakePool });

    const sesion = await conSesion.findSessionByTokenHash('abc');

    expect(sesiones.queries[0].text).toMatch(/FROM sessions WHERE token_hash = \$1/);
    expect(sesiones.queries[0].params).toEqual(['abc']);
    expect(sesion.revokedAt).toBe(revocada.toISOString());
    expect(await sinFilas.findSessionByTokenHash('otro')).toBeNull();
    expect(await sinFilas.findUserById('u9')).toBeNull();
    expect(vacio.queries[1].text).toMatch(/FROM users WHERE id = \$1/);
    expect(vacio.queries[1].params).toEqual(['u9']);
  });
});
