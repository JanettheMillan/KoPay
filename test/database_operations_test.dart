import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper helper;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_ops_test');
    helper = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
  });

  tearDown(() async {
    await helper.close();
    tempDir.deleteSync(recursive: true);
  });

  Movement gasto(String description, DateTime date, {double amount = -100}) =>
      Movement(
        amount: amount,
        description: description,
        category: 'Comida',
        date: date,
      );

  group('Movimientos', () {
    test('alta: devuelve el movimiento con id y conserva los campos', () async {
      final nuevo = Movement(
        amount: -1350.5,
        description: 'Súper',
        category: 'Comida',
        date: DateTime(2026, 11, 3, 18, 45),
        note: 'Despensa',
      );
      final guardado = await helper.insertMovement(nuevo);

      expect(guardado.id, isNotNull);
      expect(guardado, nuevo.copyWith(id: guardado.id));
      expect(await helper.getMovement(guardado.id!), guardado);
    });

    test('lectura: ordena del más reciente al más antiguo', () async {
      await helper.insertMovement(gasto('Medio', DateTime(2026, 11, 3)));
      await helper.insertMovement(gasto('Viejo', DateTime(2026, 10, 28)));
      await helper.insertMovement(gasto('Nuevo', DateTime(2026, 11, 5, 9)));
      await helper.insertMovement(
        gasto('Nuevo tarde', DateTime(2026, 11, 5, 20)),
      );

      final lista = await helper.getMovements();
      expect(lista.map((m) => m.description), [
        'Nuevo tarde',
        'Nuevo',
        'Medio',
        'Viejo',
      ]);
    });

    test('lectura: el mismo día, el último registrado va primero', () async {
      final dia = DateTime(2026, 11, 5);
      await helper.insertMovement(gasto('Primero', dia));
      await helper.insertMovement(gasto('Segundo', dia));

      final lista = await helper.getMovements();
      expect(lista.map((m) => m.description), ['Segundo', 'Primero']);
    });

    test('lectura por mes: incluye el primer y último día, nada más', () async {
      await helper.insertMovement(
        gasto('Oct 31', DateTime(2026, 10, 31, 23, 59)),
      );
      await helper.insertMovement(gasto('Nov 1', DateTime(2026, 11, 1)));
      await helper.insertMovement(
        gasto('Nov 30', DateTime(2026, 11, 30, 23, 59)),
      );
      await helper.insertMovement(gasto('Dic 1', DateTime(2026, 12, 1)));

      final noviembre = await helper.getMovements(month: DateTime(2026, 11));
      expect(noviembre.map((m) => m.description), ['Nov 30', 'Nov 1']);

      final diciembre = await helper.getMovements(
        month: DateTime(2026, 12, 15),
      );
      expect(diciembre.map((m) => m.description), ['Dic 1']);
    });

    test('edición: cambia los campos y conserva el id', () async {
      final guardado = await helper.insertMovement(
        gasto('Súper', DateTime(2026, 11, 3)).copyWith(note: 'Despensa'),
      );
      final editado = guardado.copyWith(
        amount: -200,
        description: 'Mercado',
        category: 'Comida',
        date: DateTime(2026, 11, 4),
        clearNote: true,
      );

      expect(await helper.updateMovement(editado), 1);
      expect(await helper.getMovement(guardado.id!), editado);
      expect(await helper.getMovements(), [editado]);
    });

    test('edición: un id inexistente no cambia nada', () async {
      await helper.insertMovement(gasto('Súper', DateTime(2026, 11, 3)));
      final fantasma = gasto('X', DateTime(2026, 11, 3)).copyWith(id: 999);

      expect(await helper.updateMovement(fantasma), 0);
      expect(
        () => helper.updateMovement(gasto('Sin id', DateTime(2026, 11, 3))),
        throwsArgumentError,
      );
    });

    test('borrado: quita solo el movimiento indicado', () async {
      final a = await helper.insertMovement(gasto('A', DateTime(2026, 11, 1)));
      final b = await helper.insertMovement(gasto('B', DateTime(2026, 11, 2)));

      expect(await helper.deleteMovement(a.id!), 1);
      expect(await helper.getMovement(a.id!), isNull);
      expect(await helper.getMovements(), [b]);
      expect(await helper.deleteMovement(a.id!), 0);
    });

    test('los datos se conservan al cerrar y reabrir la base', () async {
      final guardado = await helper.insertMovement(
        gasto('Luz', DateTime(2026, 11, 8), amount: -540),
      );
      await helper.close();

      expect(await helper.getMovements(), [guardado]);
    });
  });

  group('Ingresos', () {
    Income ingreso(String name, DateTime date) =>
        Income(name: name, amount: 12000, date: date, note: 'Quincena');

    test('alta y lectura conservan los campos', () async {
      final nuevo = ingreso('Salario', DateTime(2026, 11, 1));
      final guardado = await helper.insertIncome(nuevo);

      expect(guardado.id, isNotNull);
      expect(
        await helper.getIncome(guardado.id!),
        nuevo.copyWith(id: guardado.id),
      );
    });

    test('lectura ordenada por fecha y filtrada por mes', () async {
      await helper.insertIncome(ingreso('Oct', DateTime(2026, 10, 15)));
      await helper.insertIncome(ingreso('Nov 1', DateTime(2026, 11, 1)));
      await helper.insertIncome(ingreso('Nov 15', DateTime(2026, 11, 15)));

      expect((await helper.getIncomes()).map((i) => i.name), [
        'Nov 15',
        'Nov 1',
        'Oct',
      ]);
      expect(
        (await helper.getIncomes(month: DateTime(2026, 11))).map((i) => i.name),
        ['Nov 15', 'Nov 1'],
      );
    });

    test('edición y borrado', () async {
      final guardado = await helper.insertIncome(
        ingreso('Salario', DateTime(2026, 11, 1)),
      );
      final editado = guardado.copyWith(name: 'Bono', amount: 3000);

      expect(await helper.updateIncome(editado), 1);
      expect(await helper.getIncome(guardado.id!), editado);

      expect(await helper.deleteIncome(guardado.id!), 1);
      expect(await helper.getIncomes(), isEmpty);
    });

    test('movimientos e ingresos no se mezclan entre tablas', () async {
      await helper.insertIncome(ingreso('Salario', DateTime(2026, 11, 1)));
      await helper.insertMovement(gasto('Súper', DateTime(2026, 11, 3)));

      expect(await helper.getIncomes(), hasLength(1));
      expect(await helper.getMovements(), hasLength(1));
    });
  });
}
