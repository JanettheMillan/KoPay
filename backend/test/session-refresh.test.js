'use strict';

// S4-02 · Renovar y cerrar sesión (HU-31, HU-33).
// CON-16 es el caso del contrato (docs/contrato-api-acceso.md §5).
// CON-29 a CON-33 son casos nuevos de esta tarjeta, agregados al contrato.

const request = require('supertest');

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { REFRESH_TOKEN_TTL_SECONDS, hashToken } = require('../src/services/session.service');

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };
const sinSesion = { error: 'Inicia sesión para continuar', code: 'UNAUTHENTICATED' };

async function setup() {
  let ahora = new Date('2026-11-26T18:00:00.000Z');
  const store = createMemoryStore({ now: () => ahora });
  const api = request(createApp({ store, now: () => ahora }));
  await api.post('/api/auth/register').send(ana).expect(201);
  return {
    store,
    login: async () => (await api.post('/api/auth/login').send(ana).expect(200)).body,
    me: (token) => api.get('/api/auth/me').set('Authorization', `Bearer ${token}`),
    refresh: (body) => api.post('/api/auth/refresh').send(body),
    logout: (header) => {
      const req = api.post('/api/auth/logout');
      return header === undefined ? req : req.set('Authorization', header);
    },
    adelantar: (segundos) => {
      ahora = new Date(ahora.getTime() + segundos * 1000);
    },
  };
}

describe('POST /api/auth/logout', () => {
  test('CON-16 · HU-33 · logout responde 204 y después /me con el mismo token da 401', async () => {
    const { login, me, logout } = await setup();
    const { accessToken } = await login();
    expect((await me(accessToken)).status).toBe(200);

    const res = await logout(`Bearer ${accessToken}`);
    expect(res.status).toBe(204);
    expect(res.text).toBe('');

    const after = await me(accessToken);
    expect(after.status).toBe(401);
    expect(after.body).toEqual(sinSesion);
  });

  test('CON-29 · HU-33 · logout sin token, con uno inválido o ya cerrado también responde 204', async () => {
    const { login, logout } = await setup();
    const { accessToken } = await login();
    for (const header of [undefined, '', 'Bearer', 'Bearer no-es-un-token', `Basic ${accessToken}`]) {
      expect((await logout(header)).status).toBe(204);
    }
    expect((await logout(`Bearer ${accessToken}`)).status).toBe(204);
    expect((await logout(`Bearer ${accessToken}`)).status).toBe(204);
  });

  test('CON-30 · HU-33 · cerrar una sesión no cierra las demás de la cuenta', async () => {
    const { login, me, logout } = await setup();
    const telefono = await login();
    const tableta = await login();
    await logout(`Bearer ${telefono.accessToken}`).expect(204);
    expect((await me(telefono.accessToken)).status).toBe(401);
    expect((await me(tableta.accessToken)).status).toBe(200);
  });
});

describe('POST /api/auth/refresh', () => {
  test('CON-31 · HU-31 · renovar responde igual que el login, con tokens nuevos que sirven', async () => {
    const { login, me, refresh, store } = await setup();
    const primera = await login();
    expect(primera.refreshExpiresIn).toBe(REFRESH_TOKEN_TTL_SECONDS);
    // Solo se guarda el hash del refreshToken.
    const fila = await store.findSessionByRefreshHash(hashToken(primera.refreshToken));
    expect(fila.refreshTokenHash).not.toBe(primera.refreshToken);
    expect(JSON.stringify(fila)).not.toContain(primera.refreshToken);

    const res = await refresh({ refreshToken: primera.refreshToken });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      accessToken: expect.any(String),
      tokenType: 'Bearer',
      expiresIn: 900,
      refreshToken: expect.any(String),
      refreshExpiresIn: REFRESH_TOKEN_TTL_SECONDS,
      user: {
        id: expect.any(String),
        name: ana.name,
        email: ana.email,
        role: 'user',
        createdAt: expect.any(String),
      },
    });
    expect(res.body.accessToken).not.toBe(primera.accessToken);
    expect(res.body.refreshToken).not.toBe(primera.refreshToken);
    expect((await me(res.body.accessToken)).status).toBe(200);
  });

  test('CON-32 · HU-34 · un refreshToken sirve una sola vez y la sesión anterior queda cerrada', async () => {
    const { login, me, refresh } = await setup();
    const primera = await login();
    const segunda = (await refresh({ refreshToken: primera.refreshToken })).body;

    const repetido = await refresh({ refreshToken: primera.refreshToken });
    expect(repetido.status).toBe(401);
    expect(repetido.body).toEqual(sinSesion);
    expect((await me(primera.accessToken)).status).toBe(401);
    // La renovación nueva sí sigue funcionando.
    expect((await refresh({ refreshToken: segunda.refreshToken })).status).toBe(200);
  });

  test('CON-33 · HU-31 · refreshToken inválido, vencido o de una sesión cerrada da 401; sin él, 400', async () => {
    const { login, refresh, logout, adelantar } = await setup();

    const falta = await refresh({});
    expect(falta.status).toBe(400);
    expect(falta.body).toEqual({
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: { refreshToken: 'Falta el refreshToken' },
    });
    expect((await refresh({ refreshToken: 42 })).status).toBe(400);
    expect((await refresh({ refreshToken: 'no-existe' })).body).toEqual(sinSesion);

    const cerrada = await login();
    await logout(`Bearer ${cerrada.accessToken}`).expect(204);
    expect((await refresh({ refreshToken: cerrada.refreshToken })).status).toBe(401);

    const vieja = await login();
    adelantar(REFRESH_TOKEN_TTL_SECONDS - 1);
    // El token de acceso ya venció, pero el refreshToken todavía no.
    const aTiempo = await refresh({ refreshToken: vieja.refreshToken });
    expect(aTiempo.status).toBe(200);
    adelantar(REFRESH_TOKEN_TTL_SECONDS);
    expect((await refresh({ refreshToken: aTiempo.body.refreshToken })).status).toBe(401);
  });

  test('CON-34 · HU-34 · dos renovaciones a la vez con el mismo refreshToken: solo una gana', async () => {
    const { login, refresh } = await setup();
    const { refreshToken } = await login();
    const [a, b] = await Promise.all([refresh({ refreshToken }), refresh({ refreshToken })]);
    expect([a.status, b.status].sort()).toEqual([200, 401]);
  });
});
