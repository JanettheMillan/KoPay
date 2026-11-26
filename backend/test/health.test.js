// S3-01 · Ruta de salud y estructura de la API (HU-30 a HU-36).
//
// El plan de pruebas no tiene casos para la API; estos son casos nuevos
// API-01 a API-08, anotados en el PR.

const request = require('supertest');

const { createApp } = require('../src/app');
const { loadConfig } = require('../src/config');
const { start } = require('../src/server');

describe('GET /api/health', () => {
  test('API-01 · HU-30 · responde 200 con el estado del servicio', async () => {
    const res = await request(createApp()).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/application\/json/);
    expect(res.body).toMatchObject({
      status: 'ok',
      service: 'kopay-api',
      data: { kind: 'memory', ok: true },
    });
    expect(typeof res.body.version).toBe('string');
    expect(new Date(res.body.timestamp).toString()).not.toBe('Invalid Date');
  });

  test('API-02 · HU-30 · responde 503 si la capa de datos no responde', async () => {
    const store = {
      kind: 'memory',
      ping: async () => {
        throw new Error('sin conexión');
      },
    };
    const res = await request(createApp({ store })).get('/api/health');

    expect(res.status).toBe(503);
    expect(res.body.status).toBe('error');
    expect(res.body.data.ok).toBe(false);
  });
});

describe('Errores', () => {
  test('API-03 · HU-30 · una ruta inexistente responde 404 en JSON', async () => {
    const res = await request(createApp()).get('/api/no-existe');

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'Ruta no encontrada', code: 'NOT_FOUND' });
  });

  test('API-04 · HU-30 · un JSON mal formado responde 400 sin detalles internos', async () => {
    const res = await request(createApp())
      .post('/api/health')
      .set('Content-Type', 'application/json')
      .send('{"roto":');

    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: 'JSON inválido', code: 'INVALID_JSON' });
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('Configuración', () => {
  test('API-05 · HU-30 · usa el puerto 3000 y desarrollo por defecto', () => {
    expect(loadConfig({})).toMatchObject({ port: 3000, env: 'development' });
    expect(loadConfig({ PORT: '8080', NODE_ENV: 'test' })).toMatchObject({
      port: 8080,
      env: 'test',
    });
  });

  test('API-06 · HU-30 · rechaza un PORT inválido', () => {
    expect(() => loadConfig({ PORT: 'abc' })).toThrow('PORT inválido');
    expect(() => loadConfig({ PORT: '70000' })).toThrow('PORT inválido');
  });
});

describe('Servidor', () => {
  test('API-07 · HU-30 · el servidor inicia y responde en un puerto real', async () => {
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    const server = await start({ port: 0, env: 'test' });
    try {
      const { port } = server.address();
      const res = await fetch(`http://127.0.0.1:${port}/api/health`);
      expect(res.status).toBe(200);
      expect((await res.json()).environment).toBe('test');
    } finally {
      await new Promise((resolve) => server.close(resolve));
      log.mockRestore();
    }
  });

  test('API-08 · HU-30 · si el puerto está ocupado, el arranque falla', async () => {
    const log = jest.spyOn(console, 'log').mockImplementation(() => {});
    const first = await start({ port: 0, env: 'test' });
    try {
      const { port } = first.address();
      await expect(start({ port, env: 'test' })).rejects.toMatchObject({
        code: 'EADDRINUSE',
      });
    } finally {
      await new Promise((resolve) => first.close(resolve));
      log.mockRestore();
    }
  });
});
