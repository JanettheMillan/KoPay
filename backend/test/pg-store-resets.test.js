// S4-19 · Códigos de recuperación en la capa PostgreSQL (HU-32).
//
// Prueba sin base de datos: un pool falso revisa las consultas y la
// transacción. Las pruebas contra una base real están en test/db
// (`npm run test:db`, caso DB-06). REC-10 a REC-13 son pruebas nuevas.

const { createPgStore } = require('../src/data/pg-store');

const creada = new Date('2026-11-26T18:00:00.000Z');
const vence = new Date('2026-11-26T18:15:00.000Z');
const fila = {
  id: 'r1',
  user_id: 'u1',
  code_hash: 'a'.repeat(64),
  created_at: creada,
  expires_at: vence,
  attempts: 0,
  used_at: null,
};

/**
 * Pool falso. `answers` decide las filas de cada consulta según su texto;
 * guarda todas las consultas, también las del cliente de la transacción.
 */
function fakePool(answers = () => []) {
  const queries = [];
  let released = 0;
  const run = async (text, params) => {
    queries.push({ text: text.replace(/\s+/g, ' ').trim(), params });
    return { rows: answers(text) };
  };
  class FakePool {
    on() {}
    query(text, params) {
      return run(text, params);
    }
    async connect() {
      return {
        query: run,
        release: () => {
          released += 1;
        },
      };
    }
    async end() {}
  }
  return { FakePool, queries, released: () => released };
}

const storeWith = (FakePool) => createPgStore({ databaseUrl: 'postgres://prueba', PoolClass: FakePool });

describe('pg-store · códigos de recuperación', () => {
  test('REC-10 · HU-32 · createPasswordReset borra los anteriores y guarda solo el hash', async () => {
    const { FakePool, queries } = fakePool(() => [fila]);

    const reset = await storeWith(FakePool).createPasswordReset({
      userId: 'u1',
      codeHash: 'a'.repeat(64),
      expiresAt: vence.toISOString(),
    });

    expect(queries).toHaveLength(1);
    expect(queries[0].text).toMatch(/WITH previous AS \(DELETE FROM password_resets WHERE user_id = \$1\) INSERT INTO password_resets/);
    expect(queries[0].params).toEqual(['u1', 'a'.repeat(64), vence.toISOString()]);
    expect(reset).toEqual({
      id: 'r1',
      userId: 'u1',
      codeHash: 'a'.repeat(64),
      createdAt: creada.toISOString(),
      expiresAt: vence.toISOString(),
      attempts: 0,
      usedAt: null,
    });
  });

  test('REC-11 · HU-32 · findLatestPasswordReset toma el más reciente, o null', async () => {
    const conFila = fakePool(() => [{ ...fila, attempts: 3 }]);
    const vacio = fakePool(() => []);

    const reset = await storeWith(conFila.FakePool).findLatestPasswordReset('u1');

    expect(conFila.queries[0].text).toMatch(/WHERE user_id = \$1 ORDER BY created_at DESC LIMIT 1/);
    expect(reset.attempts).toBe(3);
    expect(await storeWith(vacio.FakePool).findLatestPasswordReset('u9')).toBeNull();
  });

  test('REC-12 · HU-32 · recordPasswordResetFailure suma solo si quedan intentos', async () => {
    const suma = fakePool(() => [{ attempts: 4 }]);
    const tope = fakePool(() => []);

    expect(await storeWith(suma.FakePool).recordPasswordResetFailure('r1')).toBe(4);
    expect(suma.queries[0].text).toMatch(/SET attempts = attempts \+ 1 WHERE id = \$1 AND used_at IS NULL AND attempts < 5/);
    expect(await storeWith(tope.FakePool).recordPasswordResetFailure('r1')).toBeNull();
  });

  test('REC-13 · HU-32, HU-34 · completePasswordReset cambia hash y revoca sesiones en una transacción', async () => {
    const ok = fakePool((text) => (/SET used_at/.test(text) ? [{ id: 'r1' }] : []));
    const usado = fakePool(() => []);

    const hecho = await storeWith(ok.FakePool).completePasswordReset({
      resetId: 'r1',
      userId: 'u1',
      passwordHash: 'scrypt$nuevo',
    });
    const repetido = await storeWith(usado.FakePool).completePasswordReset({
      resetId: 'r1',
      userId: 'u1',
      passwordHash: 'scrypt$otro',
    });

    expect(hecho).toBe(true);
    expect(ok.queries.map((q) => q.text.split(' ').slice(0, 2).join(' '))).toEqual([
      'BEGIN',
      'UPDATE password_resets',
      'UPDATE users',
      'UPDATE sessions',
      'COMMIT',
    ]);
    expect(ok.queries[2].params).toEqual(['scrypt$nuevo', 'u1']);
    expect(ok.queries[3].text).toMatch(/SET revoked_at = now\(\) WHERE user_id = \$1 AND revoked_at IS NULL/);
    expect(ok.released()).toBe(1);

    // Un código ya usado no cambia nada.
    expect(repetido).toBe(false);
    expect(usado.queries.map((q) => q.text.split(' ')[0])).toEqual(['BEGIN', 'UPDATE', 'ROLLBACK']);
    expect(usado.released()).toBe(1);
  });
});
