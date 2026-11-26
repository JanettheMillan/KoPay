// S3-13 · Contrato de errores de la API (HU-30, HU-31).
//
// Casos CON-01 a CON-04 de docs/contrato-api-acceso.md. Los casos de
// registro e inicio de sesión (CON-05 en adelante) los agrega la
// tarjeta que crea cada ruta.

const fs = require('node:fs');
const path = require('node:path');
const request = require('supertest');

const { createApp } = require('../src/app');
const { ERROR_CODES, HttpError } = require('../src/errors');
const { errorHandler } = require('../src/middleware/errors');

/** Respuesta falsa para llamar al manejador sin Express. */
function fakeRes() {
  return {
    statusCode: 0,
    payload: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.payload = body;
      return this;
    },
  };
}

function handle(err) {
  const res = fakeRes();
  errorHandler(err, {}, res, () => {});
  return res;
}

describe('CON-01 · HU-30 · todos los errores tienen { error, code }', () => {
  test('ruta inexistente → 404 NOT_FOUND', async () => {
    const res = await request(createApp()).get('/api/auth/no-existe');

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: 'Ruta no encontrada', code: 'NOT_FOUND' });
  });

  test('JSON mal formado → 400 INVALID_JSON', async () => {
    const res = await request(createApp())
      .post('/api/auth/login')
      .set('Content-Type', 'application/json')
      .send('{"email":');

    expect(res.status).toBe(400);
    expect(res.body).toEqual({ error: 'JSON inválido', code: 'INVALID_JSON' });
  });

  test('cuerpo de más de 100 kB → 413 PAYLOAD_TOO_LARGE', async () => {
    const res = await request(createApp())
      .post('/api/auth/register')
      .set('Content-Type', 'application/json')
      .send(JSON.stringify({ name: 'x'.repeat(110 * 1024) }));

    expect(res.status).toBe(413);
    expect(res.body.code).toBe('PAYLOAD_TOO_LARGE');
    expect(typeof res.body.error).toBe('string');
  });

  test('error inesperado → 500 INTERNAL sin detalles internos', () => {
    const log = jest.spyOn(console, 'error').mockImplementation(() => {});
    const res = handle(new Error('conexión a postgres://usuario:clave@db rota'));
    log.mockRestore();

    expect(res.statusCode).toBe(500);
    expect(res.payload).toEqual({ error: 'Error interno del servidor', code: 'INTERNAL' });
    expect(JSON.stringify(res.payload)).not.toContain('clave');
  });
});

describe('Errores propios de las rutas', () => {
  test('CON-02 · HU-30 · fields solo aparece cuando se envía', () => {
    const conCampos = handle(
      new HttpError(400, 'Revisa los datos marcados', {
        fields: { email: 'Escribe un correo válido' },
      }),
    );
    const sinCampos = handle(
      new HttpError(401, 'Correo o contraseña incorrectos', {
        code: ERROR_CODES.INVALID_CREDENTIALS,
      }),
    );

    expect(conCampos.statusCode).toBe(400);
    expect(conCampos.payload).toEqual({
      error: 'Revisa los datos marcados',
      code: 'VALIDATION_FAILED',
      fields: { email: 'Escribe un correo válido' },
    });
    expect(sinCampos.statusCode).toBe(401);
    expect(sinCampos.payload).toEqual({
      error: 'Correo o contraseña incorrectos',
      code: 'INVALID_CREDENTIALS',
    });
  });

  test('CON-03 · HU-30 · sin code se usa el del estado HTTP', () => {
    const porEstado = {
      400: 'VALIDATION_FAILED',
      401: 'UNAUTHENTICATED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'EMAIL_TAKEN',
      413: 'PAYLOAD_TOO_LARGE',
      429: 'TOO_MANY_ATTEMPTS',
      503: 'UNAVAILABLE',
      418: 'INTERNAL',
    };
    for (const [status, code] of Object.entries(porEstado)) {
      expect(new HttpError(Number(status), 'x').code).toBe(code);
    }
  });

  test('CON-04 · HU-30 · la tabla de códigos del documento coincide con Node', () => {
    const doc = fs.readFileSync(
      path.join(__dirname, '..', '..', 'docs', 'contrato-api-acceso.md'),
      'utf8',
    );
    const seccion = doc.split('### Códigos')[1].split('\n## ')[0];
    const enDoc = [...seccion.matchAll(/^\| \d{3} \| `([A-Z_]+)` \|/gm)].map((m) => m[1]);

    expect(enDoc.length).toBeGreaterThan(0);
    expect([...enDoc].sort()).toEqual(Object.values(ERROR_CODES).sort());
  });
});
