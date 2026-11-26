// S3-16 · Casos unitarios de validación y autorización (HU-30, HU-34,
// HU-37; los de login y recuperación llevan HU-31 y HU-32).
//
// Prueban las funciones aisladas, sin HTTP. FUT-01, FUT-14 y FUT-21 son
// casos de docs/plan-de-pruebas.md. VAL-xx y AUT-xx son pruebas nuevas de
// esta tarjeta, descritas en docs/casos-s3-16.md. No repiten los límites
// que ya cubren REG-07 (register.test.js) y RBAC-09 (rbac.test.js).

const { PERMISSIONS, can } = require('../src/middleware/rbac');
const {
  MESSAGES,
  validateLogin,
  validateRecover,
  validateRegistration,
  validateReset,
} = require('../src/validators/auth.validator');

const ana = { name: 'Ana López', email: 'ana@mail.com', password: 'kopay2026' };
const registro = (cambios) => validateRegistration({ ...ana, ...cambios }).fields;

describe('Validación del registro', () => {
  test('FUT-01 · HU-30 · datos válidos pasan; vacíos y mal formados no', () => {
    expect(registro({})).toEqual({});
    expect(validateRegistration({ name: '', email: '', password: '' }).fields).toEqual({
      name: MESSAGES.nameRequired,
      email: MESSAGES.emailInvalid,
      password: MESSAGES.passwordTooShort,
    });
    expect(registro({ email: 'ana.mail.com' })).toEqual({ email: MESSAGES.emailInvalid });
  });

  test.each([
    [7, { password: MESSAGES.passwordTooShort }],
    [8, {}],
    [72, {}],
    [73, { password: MESSAGES.passwordTooLong }],
  ])('FUT-14 · HU-30 · contraseña de %i caracteres', (largo, esperado) => {
    expect(registro({ password: `a1${'x'.repeat(largo - 2)}` })).toEqual(esperado);
  });

  test('VAL-01 · HU-30 · el nombre se recorta antes de medirlo', () => {
    expect(registro({ name: '     ' })).toEqual({ name: MESSAGES.nameRequired });
    expect(registro({ name: `  ${'a'.repeat(80)}  ` })).toEqual({});
  });

  test('VAL-02 · HU-30 · un emoji cuenta como un solo carácter', () => {
    expect(registro({ name: '😀'.repeat(80) })).toEqual({});
    expect(registro({ name: '😀'.repeat(81) })).toEqual({ name: MESSAGES.nameTooLong });
    expect(registro({ password: `a1${'😀'.repeat(6)}` })).toEqual({});
    expect(registro({ password: `a1${'😀'.repeat(5)}` })).toEqual({
      password: MESSAGES.passwordTooShort,
    });
  });

  test('VAL-03 · HU-30 · los espacios alrededor del correo no cuentan en los 254', () => {
    const correo254 = `${'a'.repeat(64)}@${'b'.repeat(185)}.com`;

    expect(correo254).toHaveLength(254);
    expect(registro({ email: `  ${correo254}  ` })).toEqual({});
  });
});

describe('Validación del login', () => {
  test.each([undefined, null, 'texto', []])(
    'VAL-04 · HU-31 · un cuerpo %p pide correo y contraseña',
    (body) => {
      expect(validateLogin(body).fields).toEqual({
        email: MESSAGES.loginEmailRequired,
        password: MESSAGES.loginPasswordRequired,
      });
    },
  );

  test('VAL-05 · HU-31 · el correo de solo espacios falta; la contraseña no se recorta', () => {
    const { value, fields } = validateLogin({ email: '   ', password: '   ' });

    expect(fields).toEqual({ email: MESSAGES.loginEmailRequired });
    expect(value.password).toBe('   ');
  });
});

describe('Validación de la recuperación', () => {
  test('VAL-06 · HU-32 · pedir código exige un correo válido y lo normaliza', () => {
    expect(validateRecover(null).fields).toEqual({ email: MESSAGES.emailInvalid });
    expect(validateRecover({ email: 'ana@mail' }).fields).toEqual({
      email: MESSAGES.emailInvalid,
    });
    expect(validateRecover({ email: '  Ana@Mail.com ' })).toEqual({
      value: { email: 'ana@mail.com' },
      fields: {},
    });
  });

  const reset = (code) => validateReset({ ...ana, code });

  test.each(['', '12345', '1234567', '12345a', '123 456', '-12345', '１２３４５６', 123456, null])(
    'VAL-07 · HU-32 · el código %p se rechaza',
    (code) => {
      expect(reset(code).fields).toEqual({ code: MESSAGES.codeRequired });
    },
  );

  test('VAL-08 · HU-32 · 6 dígitos valen, con ceros a la izquierda y espacios alrededor', () => {
    expect(reset('048213').fields).toEqual({});
    expect(reset('000000').fields).toEqual({});
    expect(reset(' 048213 ').value.code).toBe('048213');
  });

  test('VAL-09 · HU-32 · reset reporta los tres campos inválidos a la vez', () => {
    expect(validateReset({}).fields).toEqual({
      email: MESSAGES.emailInvalid,
      code: MESSAGES.codeRequired,
      password: MESSAGES.passwordTooShort,
    });
  });
});

describe('Autorización por rol', () => {
  const todos = Object.values(PERMISSIONS);

  test('FUT-21 · HU-37 · solo el contador tiene el permiso de lectura contable', () => {
    expect(can('accountant', PERMISSIONS.READ_CLIENTS)).toBe(true);
    expect(can('user', PERMISSIONS.READ_CLIENTS)).toBe(false);
  });

  test.each(['admin', 'User', 'ACCOUNTANT', ' accountant', 'user ', '', null, undefined, 0])(
    'AUT-01 · HU-34 · el rol %p no tiene ningún permiso',
    (role) => {
      expect(todos.map((permission) => can(role, permission))).toEqual(todos.map(() => false));
    },
  );

  test('AUT-02 · HU-34 · un permiso desconocido no se concede a ningún rol', () => {
    for (const role of ['user', 'accountant']) {
      expect(can(role, 'todo')).toBe(false);
      expect(can(role, undefined)).toBe(false);
    }
  });

  // Defecto conocido D-07 (#183): `can` busca el rol en un objeto normal,
  // así que un nombre heredado lanza TypeError en lugar de devolver false.
  // La base solo admite 'user' y 'accountant' (migración 001).
  // `test.failing` deja constancia; cuando se corrija, Jest avisará y se
  // cambia a `test`.
  test.failing.each(['constructor', 'toString', '__proto__', 'hasOwnProperty'])(
    'AUT-03 · HU-34 · el nombre heredado %p tampoco tiene permisos',
    (role) => {
      expect(can(role, PERMISSIONS.OWN_FINANCES)).toBe(false);
    },
  );
});
