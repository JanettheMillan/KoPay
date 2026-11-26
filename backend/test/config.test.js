// S3-02 · Ambientes y secretos de la API (HU-30, HU-35).
//
// El plan de pruebas no tiene casos para la configuración de la API;
// estos son casos nuevos ENV-01 a ENV-12, anotados en el PR, y ENV-13 a
// ENV-16 del correo de recuperación (S4-19).

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {
  EXAMPLE_SECRET,
  SMTP_VARIABLES,
  describeConfig,
  loadConfig,
  loadEnvFile,
} = require('../src/config');

const SECRET = 'x'.repeat(48);
const PROD = {
  NODE_ENV: 'production',
  DATABASE_URL: 'postgres://usuario:clave@db.example.com:5432/kopay',
  JWT_SECRET: SECRET,
  CORS_ORIGIN: 'https://kopay.example.com',
  // Correo de recuperación (S4-19).
  SMTP_HOST: 'smtp.example.com',
  SMTP_PORT: '587',
  SMTP_USER: 'kopay@example.com',
  SMTP_PASS: 'clave-smtp-secreta',
  MAIL_FROM: 'KoPay <kopay@example.com>',
  // Token de mentira con el formato de Banxico (S5-06).
  BANXICO_TOKEN: 'b'.repeat(64),
};

describe('Ambientes', () => {
  test('ENV-01 · HU-30 · desarrollo arranca sin .env con valores locales', () => {
    const config = loadConfig({});

    expect(config.env).toBe('development');
    expect(config.isProduction).toBe(false);
    expect(config.databaseUrl).toMatch(/localhost/);
    expect(config.jwtSecret).toMatch(/no-usar-en-produccion/);
  });

  test('ENV-02 · HU-30 · pruebas usan su propia base, distinta de desarrollo', () => {
    const dev = loadConfig({ NODE_ENV: 'development' });
    const test = loadConfig({ NODE_ENV: 'test' });

    expect(test.env).toBe('test');
    expect(test.databaseUrl).not.toBe(dev.databaseUrl);
    expect(test.jwtSecret).not.toBe(dev.jwtSecret);
  });

  test('ENV-03 · HU-30 · producción usa solo sus variables, sin valores locales', () => {
    const config = loadConfig(PROD);

    expect(config).toMatchObject({
      env: 'production',
      isProduction: true,
      databaseUrl: PROD.DATABASE_URL,
      jwtSecret: SECRET,
      corsOrigin: PROD.CORS_ORIGIN,
    });
  });

  test('ENV-04 · HU-30 · un NODE_ENV desconocido se rechaza', () => {
    expect(() => loadConfig({ NODE_ENV: 'staging' })).toThrow('NODE_ENV inválido');
  });

  test('ENV-05 · HU-30 · una variable vacía cuenta como no definida', () => {
    // Observación de la revisión de S3-01: PORT="" abría un puerto al azar.
    expect(loadConfig({ PORT: '' }).port).toBe(3000);
    expect(loadConfig({ PORT: '  ', NODE_ENV: '' })).toMatchObject({
      port: 3000,
      env: 'development',
    });
    expect(() => loadConfig({ PORT: '3.5' })).toThrow('PORT inválido');
  });
});

describe('Secretos en producción', () => {
  test('ENV-06 · HU-30 · sin DATABASE_URL ni JWT_SECRET no arranca y dice qué falta', () => {
    const { DATABASE_URL, JWT_SECRET, ...sinSecretos } = PROD;

    expect(() => loadConfig(sinSecretos)).toThrow(
      /falta DATABASE_URL; falta JWT_SECRET/,
    );
    expect(() => loadConfig({ ...PROD, JWT_SECRET: '' })).toThrow('falta JWT_SECRET');
  });

  test('ENV-07 · HU-30 · rechaza el secreto de ejemplo y uno corto', () => {
    expect(() => loadConfig({ ...PROD, JWT_SECRET: EXAMPLE_SECRET })).toThrow(
      'valor de ejemplo',
    );
    expect(() => loadConfig({ ...PROD, JWT_SECRET: 'corto' })).toThrow(
      'al menos 32 caracteres',
    );
  });

  test('ENV-08 · HU-30 · el error no muestra los valores de los secretos', () => {
    const corto = 'secreto-corto-123';
    let message = '';
    try {
      loadConfig({ ...PROD, JWT_SECRET: corto });
    } catch (err) {
      message = err.message;
    }
    expect(message).not.toBe('');
    expect(message).not.toContain(corto);
    expect(message).not.toContain(PROD.DATABASE_URL);
  });

  test('ENV-09 · HU-30 · el resumen de consola oculta los secretos', () => {
    const resumen = describeConfig(loadConfig(PROD));
    const texto = JSON.stringify(resumen);

    expect(resumen).toMatchObject({
      env: 'production',
      databaseUrl: 'definida',
      jwtSecret: 'definido',
    });
    expect(texto).not.toContain(SECRET);
    expect(texto).not.toContain('clave');
  });
});

describe('Archivo .env', () => {
  let dir;
  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kopay-env-'));
  });
  afterEach(() => fs.rmSync(dir, { recursive: true, force: true }));

  test('ENV-10 · HU-30 · lee el .env y las variables del sistema tienen prioridad', () => {
    const file = path.join(dir, '.env');
    fs.writeFileSync(file, 'PORT=4000\nJWT_SECRET=del-archivo\nCORS_ORIGIN=*\n');
    const env = { PORT: '5000' };

    expect(loadEnvFile({ file, env })).toBe(true);
    expect(env.PORT).toBe('5000');
    expect(env.JWT_SECRET).toBe('del-archivo');
    expect(loadConfig(env).port).toBe(5000);
  });

  test('ENV-11 · HU-30 · sin .env no falla y no cambia nada', () => {
    const env = {};
    expect(loadEnvFile({ file: path.join(dir, 'no-existe'), env })).toBe(false);
    expect(env).toEqual({});
  });

  test('ENV-12 · HU-30 · git ignora .env y .env.production, pero no .env.example', () => {
    const backend = path.join(__dirname, '..');
    const ignored = (name) => {
      try {
        execFileSync('git', ['check-ignore', '-q', name], { cwd: backend });
        return true;
      } catch {
        return false;
      }
    };

    expect(ignored('.env')).toBe(true);
    expect(ignored('.env.production')).toBe(true);
    expect(ignored('.env.example')).toBe(false);
    expect(fs.existsSync(path.join(backend, '.env.example'))).toBe(true);
  });
});

describe('Correo de recuperación (S4-19)', () => {
  test('ENV-13 · HU-32 · en development y test el correo usa jsonTransport sin variables SMTP', () => {
    for (const NODE_ENV of ['development', 'test']) {
      expect(loadConfig({ NODE_ENV }).mail).toEqual({
        transport: 'json',
        from: 'KoPay <no-reply@kopay.local>',
      });
    }
  });

  test('ENV-14 · HU-32 · en producción falta cada variable SMTP y no arranca', () => {
    for (const variable of SMTP_VARIABLES) {
      const env = { ...PROD };
      delete env[variable];
      expect(() => loadConfig(env)).toThrow(`falta ${variable}`);
    }
    expect(() => loadConfig({ ...PROD, SMTP_PASS: '   ' })).toThrow('falta SMTP_PASS');
  });

  test('ENV-15 · HU-32 · un SMTP_PORT que no es número de puerto se rechaza', () => {
    for (const port of ['abc', '0', '70000', '58.7']) {
      expect(() => loadConfig({ ...PROD, SMTP_PORT: port })).toThrow(
        'SMTP_PORT debe ser un número de 1 a 65535',
      );
    }
  });

  test('ENV-16 · HU-32 · producción lee SMTP y el resumen de consola no muestra sus valores', () => {
    const config = loadConfig(PROD);

    expect(config.mail).toEqual({
      transport: 'smtp',
      host: 'smtp.example.com',
      port: 587,
      user: 'kopay@example.com',
      pass: 'clave-smtp-secreta',
      from: 'KoPay <kopay@example.com>',
    });
    const resumen = JSON.stringify(describeConfig(config));
    expect(resumen).not.toContain('clave-smtp-secreta');
    expect(resumen).not.toContain('kopay@example.com');
    expect(resumen).not.toContain('smtp.example.com');
  });
  test('SEG-08 · HU-34 · S4-13 · en producción CORS_ORIGIN no puede ser *', () => {
    for (const origin of ['*', ' * ', 'https://kopay.example.com,*']) {
      expect(() => loadConfig({ ...PROD, CORS_ORIGIN: origin })).toThrow(
        'CORS_ORIGIN no puede ser * en producción',
      );
    }
    expect(loadConfig(PROD).corsOrigin).toBe('https://kopay.example.com');
    // En desarrollo y pruebas * sigue permitido.
    expect(loadConfig({}).corsOrigin).toBe('*');
  });
});
