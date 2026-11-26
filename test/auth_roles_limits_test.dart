// S3-16 · Casos unitarios de validación y autorización en Flutter (HU-30,
// HU-31, HU-37).
//
// UT-47 a UT-49 son casos de docs/plan-de-pruebas.md. VAL-F y AUT-F son
// pruebas nuevas de esta tarjeta, descritas en docs/casos-s3-16.md. No
// repiten lo que ya cubren UT-REG-01 a UT-REG-03.

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/utils/auth_validators.dart';

void main() {
  AuthUser cuenta(String role) => AuthUser(
    id: '1',
    name: 'Ana López',
    email: 'ana@mail.com',
    role: role,
    createdAt: DateTime.utc(2026, 11, 26),
  );

  group('Rol de la cuenta', () {
    test('UT-47 · HU-37 · Una cuenta user no es contador', () {
      expect(cuenta('user').isAccountant, isFalse);
    });

    test('UT-48 · HU-37 · Una cuenta accountant es contador', () {
      expect(cuenta('accountant').isAccountant, isTrue);
    });

    test('UT-49 · HU-30 · fromMap conserva los campos de la cuenta y su '
        'rol', () {
      for (final role in ['user', 'accountant']) {
        final user = AuthUser.fromMap({
          'id': '3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f',
          'name': 'Ana López',
          'email': 'ana@mail.com',
          'role': role,
          'createdAt': '2026-11-26T18:30:00.000Z',
        });

        expect(user.id, '3f8c2a1e-9b4d-4c6a-8e2f-1a2b3c4d5e6f');
        expect(user.name, 'Ana López');
        expect(user.email, 'ana@mail.com');
        expect(user.role, role);
        expect(user.createdAt, DateTime.utc(2026, 11, 26, 18, 30));
        expect(user.isAccountant, role == 'accountant');
      }
    });

    test('AUT-F01 · HU-37 · Un rol mal escrito o desconocido no es '
        'contador', () {
      for (final role in [
        'Accountant',
        'ACCOUNTANT',
        ' accountant',
        'admin',
        '',
      ]) {
        expect(cuenta(role).isAccountant, isFalse, reason: 'rol "$role"');
      }
    });
  });

  group('Límites de validación', () {
    String conLargo(int largo) => 'a1${'x' * (largo - 2)}';

    test('VAL-F01 · HU-30 · Contraseña de 7, 8, 72 y 73 caracteres', () {
      expect(
        AuthValidators.newPassword(conLargo(7)),
        AuthValidators.passwordTooShort,
      );
      expect(AuthValidators.newPassword(conLargo(8)), isNull);
      expect(AuthValidators.newPassword(conLargo(72)), isNull);
      expect(
        AuthValidators.newPassword(conLargo(73)),
        AuthValidators.passwordTooLong,
      );
    });

    test('VAL-F02 · HU-30 · Correo de 254 caracteres sí y de 255 no', () {
      final correo254 = '${'a' * 64}@${'b' * 185}.com';

      expect(correo254, hasLength(254));
      expect(AuthValidators.email('  $correo254  '), isNull);
      expect(AuthValidators.email('a$correo254'), AuthValidators.emailInvalid);
    });

    test('VAL-F03 · HU-30 · Un emoji cuenta como un carácter, igual que en '
        'Node', () {
      expect(AuthValidators.name('😀' * 80), isNull);
      expect(AuthValidators.name('😀' * 81), AuthValidators.nameTooLong);
      expect(AuthValidators.newPassword('a1${'😀' * 6}'), isNull);
      expect(
        AuthValidators.newPassword('a1${'😀' * 5}'),
        AuthValidators.passwordTooShort,
      );
    });

    test('VAL-F04 · HU-30 · Datos nulos o de solo espacios se rechazan', () {
      expect(AuthValidators.name(null), AuthValidators.nameRequired);
      expect(AuthValidators.name('     '), AuthValidators.nameRequired);
      expect(AuthValidators.email(null), AuthValidators.emailInvalid);
      expect(AuthValidators.newPassword(null), AuthValidators.passwordTooShort);
    });

    test('VAL-F05 · HU-31 · En el login la contraseña solo es obligatoria', () {
      expect(AuthValidators.password(null), AuthValidators.passwordRequired);
      expect(AuthValidators.password(''), AuthValidators.passwordRequired);
      expect(AuthValidators.password('1'), isNull);
      expect(AuthValidators.password('   '), isNull);
    });
  });
}
