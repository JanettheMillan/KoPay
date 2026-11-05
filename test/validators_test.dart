import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Validators.amount', () {
    test('acepta montos positivos con hasta dos decimales', () {
      for (final valido in [
        '150',
        '150.5',
        '150.50',
        '1,350.50',
        r'$ 99',
        ' 0.01 ',
      ]) {
        expect(Validators.amount(valido), isNull, reason: valido);
      }
      expect(Validators.parseAmount('1,350.50'), 1350.5);
      expect(Validators.parseAmount(r'$99'), 99);
    });

    test('rechaza montos vacíos, no numéricos, cero, negativos o enormes', () {
      final casos = {
        null: Validators.emptyAmount,
        '': Validators.emptyAmount,
        '   ': Validators.emptyAmount,
        'abc': Validators.notANumber,
        '12a': Validators.notANumber,
        '1e5': Validators.notANumber,
        '1.2.3': Validators.notANumber,
        '.5': Validators.notANumber,
        '0': Validators.notPositive,
        '0.00': Validators.notPositive,
        '-50': Validators.notPositive,
        '10.505': Validators.tooManyDecimals,
        '1000000000': Validators.tooLarge,
      };
      casos.forEach((texto, error) {
        expect(Validators.amount(texto), error, reason: '"$texto"');
        expect(Validators.parseAmount(texto), isNull, reason: '"$texto"');
      });
    });
  });

  group('Validators de texto', () {
    test('descripción, nombre y categoría no pueden quedar vacíos', () {
      expect(Validators.description(''), Validators.emptyDescription);
      expect(Validators.description('   '), Validators.emptyDescription);
      expect(Validators.description(null), Validators.emptyDescription);
      expect(Validators.description('Súper'), isNull);

      expect(Validators.incomeName(' '), Validators.emptyName);
      expect(Validators.incomeName('Salario'), isNull);

      expect(Validators.category(null), Validators.emptyCategory);
      expect(Validators.category('Comida'), isNull);
    });
  });

  group('Signo del movimiento', () {
    test('los gastos quedan negativos y las entradas positivas', () {
      expect(Validators.signedAmount(150, isExpense: true), -150);
      expect(Validators.signedAmount(-150, isExpense: true), -150);
      expect(Validators.signedAmount(150, isExpense: false), 150);
      expect(Validators.signedAmount(-150, isExpense: false), 150);
    });
  });

  group('checkMovement y checkIncome', () {
    final fecha = DateTime(2026, 11, 5);
    final valido = Movement(
      amount: -150,
      description: 'Súper',
      category: 'Comida',
      date: fecha,
    );

    test('un movimiento válido no tiene errores', () {
      expect(Validators.checkMovement(valido), isNull);
      expect(Validators.checkMovement(valido.copyWith(amount: 200)), isNull);
    });

    test('un movimiento con monto cero o descripción vacía se rechaza', () {
      expect(
        Validators.checkMovement(valido.copyWith(amount: 0)),
        Validators.notPositive,
      );
      expect(
        Validators.checkMovement(valido.copyWith(amount: double.nan)),
        Validators.notPositive,
      );
      expect(
        Validators.checkMovement(valido.copyWith(description: '  ')),
        Validators.emptyDescription,
      );
      expect(
        Validators.checkMovement(valido.copyWith(category: '')),
        Validators.emptyCategory,
      );
    });

    test('un ingreso necesita nombre y monto positivo', () {
      final ingreso = Income(name: 'Salario', amount: 12000, date: fecha);
      expect(Validators.checkIncome(ingreso), isNull);
      expect(
        Validators.checkIncome(ingreso.copyWith(amount: -5)),
        Validators.notPositive,
      );
      expect(
        Validators.checkIncome(ingreso.copyWith(name: '')),
        Validators.emptyName,
      );
    });
  });

  group('Los providers no guardan registros inválidos', () {
    sqfliteFfiInit();

    late Directory tempDir;
    late DatabaseHelper db;
    late MovementProvider movements;
    late IncomeProvider incomes;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kopay_validation_test');
      db = DatabaseHelper.withFactory(
        databaseFactoryFfi,
        '${tempDir.path}/${DatabaseHelper.fileName}',
      );
      movements = MovementProvider(database: db);
      incomes = IncomeProvider(database: db);
    });

    tearDown(() async {
      movements.dispose();
      incomes.dispose();
      await db.close();
      tempDir.deleteSync(recursive: true);
    });

    final fecha = DateTime(2026, 11, 5);

    test('MovementProvider rechaza alta y edición inválidas', () async {
      expect(
        () => movements.add(
          Movement(
            amount: -50,
            description: '',
            category: 'Comida',
            date: fecha,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => movements.add(
          Movement(
            amount: 0,
            description: 'X',
            category: 'Comida',
            date: fecha,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );

      final guardado = await movements.add(
        Movement(
          amount: Validators.signedAmount(50, isExpense: true),
          description: 'Súper',
          category: 'Comida',
          date: fecha,
        ),
      );
      expect(guardado.amount, -50);

      await expectLater(
        movements.update(guardado.copyWith(description: ' ')),
        throwsA(isA<ValidationException>()),
      );
      expect(await db.getMovements(), [guardado]);
    });

    test('IncomeProvider rechaza ingresos sin nombre o sin monto', () async {
      expect(
        () => incomes.add(Income(name: '', amount: 100, date: fecha)),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => incomes.add(Income(name: 'Salario', amount: 0, date: fecha)),
        throwsA(isA<ValidationException>()),
      );
      expect(await db.getIncomes(), isEmpty);
    });
  });
}
