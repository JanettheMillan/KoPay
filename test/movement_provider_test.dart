import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;
  late MovementProvider provider;
  late int notifications;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_provider_test');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    provider = MovementProvider(database: db);
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  Movement gasto(String description, DateTime date, {double amount = -100}) =>
      Movement(
        amount: amount,
        description: description,
        category: 'Comida',
        date: date,
      );

  test('load lee lo guardado en la base y notifica', () async {
    await db.insertMovement(gasto('Súper', DateTime(2026, 11, 3)));

    expect(provider.isLoaded, isFalse);
    await provider.load();

    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.movements.single.description, 'Súper');
    expect(notifications, 2); // inicio y fin de la carga
  });

  test('alta: guarda, recarga ordenado por fecha y notifica', () async {
    await provider.load();
    notifications = 0;

    await provider.add(gasto('Viejo', DateTime(2026, 11, 1)));
    final nuevo = await provider.add(gasto('Nuevo', DateTime(2026, 11, 5)));

    expect(nuevo.id, isNotNull);
    expect(provider.movements.map((m) => m.description), ['Nuevo', 'Viejo']);
    expect(notifications, 2);
    expect(await db.getMovements(), provider.movements);
  });

  test('actualización: cambia el registro en la base y notifica', () async {
    final guardado = await provider.add(gasto('Súper', DateTime(2026, 11, 3)));
    notifications = 0;

    final editado = guardado.copyWith(description: 'Mercado', amount: -250);
    await provider.update(editado);

    expect(provider.movements, [editado]);
    expect(await db.getMovement(guardado.id!), editado);
    expect(notifications, 1);
  });

  test('borrado: quita el registro de la base y notifica', () async {
    final a = await provider.add(gasto('A', DateTime(2026, 11, 1)));
    final b = await provider.add(gasto('B', DateTime(2026, 11, 2)));
    notifications = 0;

    await provider.delete(a.id!);

    expect(provider.movements, [b]);
    expect(await db.getMovement(a.id!), isNull);
    expect(notifications, 1);
  });

  test('la lista expuesta no se puede modificar desde fuera', () async {
    await provider.add(gasto('Súper', DateTime(2026, 11, 3)));
    expect(() => provider.movements.clear(), throwsUnsupportedError);
  });

  test('totales del mes separan gastos y entradas', () async {
    await provider.add(gasto('Súper', DateTime(2026, 11, 3), amount: -1350.5));
    await provider.add(gasto('Luz', DateTime(2026, 11, 8), amount: -540));
    await provider.add(gasto('Reembolso', DateTime(2026, 11, 9), amount: 200));
    await provider.add(gasto('Renta', DateTime(2026, 10, 2), amount: -4500));

    final noviembre = DateTime(2026, 11);
    expect(provider.forMonth(noviembre), hasLength(3));
    expect(provider.expensesForMonth(noviembre), 1890.5);
    expect(provider.entriesForMonth(noviembre), 200);
    expect(provider.expensesForMonth(DateTime(2026, 10)), 4500);
  });

  testWidgets('un widget que escucha el provider se reconstruye', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Consumer<MovementProvider>(
            builder: (_, p, _) => Text('${p.movements.length} movimientos'),
          ),
        ),
      ),
    );
    expect(find.text('0 movimientos'), findsOneWidget);

    await tester.runAsync(
      () => provider.add(gasto('Súper', DateTime(2026, 11, 3))),
    );
    await tester.pump();

    expect(find.text('1 movimientos'), findsOneWidget);
  });
}
