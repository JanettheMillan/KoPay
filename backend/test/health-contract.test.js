// S3-03 · Contrato de salud y guía de ejecución local (HU-31).
//
// Comprueba que lo que dice backend/README.md coincide con lo que hace
// la API, para que la guía no quede desactualizada. El plan de pruebas
// no tiene casos para la API; estos son casos nuevos SAL-01 a SAL-06,
// anotados en el PR.

const fs = require('node:fs');
const path = require('node:path');
const request = require('supertest');

const { createApp } = require('../src/app');
const { loadConfig } = require('../src/config');
const pkg = require('../package.json');

const readme = fs.readFileSync(path.join(__dirname, '..', 'README.md'), 'utf8');
const ISO_UTC = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;
const CONTRACT_FIELDS = [
  'data',
  'environment',
  'service',
  'status',
  'timestamp',
  'version',
];

describe('Contrato de salud', () => {
  test('SAL-01 · HU-31 · 200 con exactamente los campos y tipos documentados', async () => {
    const res = await request(createApp({ config: loadConfig({}) })).get(
      '/api/health',
    );

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toMatch(/application\/json/);
    expect(Object.keys(res.body).sort()).toEqual(CONTRACT_FIELDS);
    expect(res.body).toEqual({
      status: 'ok',
      service: 'kopay-api',
      version: pkg.version,
      environment: 'development',
      data: { kind: 'memory', ok: true },
      timestamp: expect.stringMatching(ISO_UTC),
    });
  });

  test('SAL-02 · HU-31 · 503 con el mismo cuerpo y status "error"', async () => {
    const store = { kind: 'memory', ping: async () => false };
    const res = await request(createApp({ config: loadConfig({}), store })).get(
      '/api/health',
    );

    expect(res.status).toBe(503);
    expect(Object.keys(res.body).sort()).toEqual(CONTRACT_FIELDS);
    expect(res.body).toMatchObject({ status: 'error', data: { ok: false } });
  });

  test('SAL-03 · HU-31 · la respuesta no incluye secretos', async () => {
    const config = loadConfig({
      NODE_ENV: 'production',
      DATABASE_URL: 'postgres://usuario:clave-secreta@db/kopay',
      JWT_SECRET: 's'.repeat(40),
      CORS_ORIGIN: 'https://kopay.example.com',
      SMTP_HOST: 'smtp.example.com',
      SMTP_PORT: '587',
      SMTP_USER: 'kopay@example.com',
      SMTP_PASS: 'clave-smtp-secreta',
      MAIL_FROM: 'KoPay <kopay@example.com>',
      BANXICO_TOKEN: 'b'.repeat(64),
    });
    const res = await request(createApp({ config })).get('/api/health');
    const texto = JSON.stringify(res.body);

    expect(res.body.environment).toBe('production');
    expect(texto).not.toContain('clave-secreta');
    expect(texto).not.toContain('s'.repeat(40));
  });

  test('SAL-04 · HU-31 · las respuestas de error coinciden con la guía', async () => {
    const app = createApp({ config: loadConfig({}) });

    const notFound = await request(app).get('/api/no-existe');
    expect(notFound.status).toBe(404);
    expect(readme).toContain(JSON.stringify(notFound.body));

    const badJson = await request(app)
      .post('/api/health')
      .set('Content-Type', 'application/json')
      .send('{"roto":');
    expect(badJson.status).toBe(400);
    expect(readme).toContain(JSON.stringify(badJson.body));

    const tooLarge = await request(app)
      .post('/api/health')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({ x: 'a'.repeat(101 * 1024) }));
    expect(tooLarge.status).toBe(413);
    expect(readme).toContain(JSON.stringify(tooLarge.body));
  });
});

describe('Guía de ejecución local', () => {
  test('SAL-05 · HU-31 · cada comando npm de la guía existe en package.json', () => {
    const commands = [...readme.matchAll(/npm (?:run )?([a-z]+)/g)].map(
      (m) => m[1],
    );
    const builtIn = ['ci', 'install'];
    const used = [...new Set(commands)].filter((c) => !builtIn.includes(c));

    expect(used).toEqual(expect.arrayContaining(['start', 'test', 'dev']));
    for (const command of used) {
      expect(pkg.scripts).toHaveProperty(command);
    }
  });

  test('SAL-06 · HU-31 · la guía documenta cada campo y el puerto por defecto', () => {
    for (const field of ['status', 'service', 'version', 'environment', 'data.kind', 'data.ok', 'timestamp']) {
      expect(readme).toContain(`\`${field}\``);
    }
    expect(readme).toContain(`http://localhost:${loadConfig({}).port}/api/health`);
    expect(readme).toContain(`Node.js ${pkg.engines.node.replace('>=', '')}`);
    expect(fs.existsSync(path.join(__dirname, '..', '.env.example'))).toBe(true);
  });
});
