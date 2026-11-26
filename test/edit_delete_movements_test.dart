// #13 · Probar edición y eliminación de movimientos (HU-05 y HU-06).
//
// EDIT-01 recorre la app completa con una base en memoria (los widget
// tests no deben hacer I/O real) y comprueba la lista y el resumen.
// EDIT-02 usa SQLite real fuera de `testWidgets` para comprobar que la
// edición persiste. DEL-01 comprueba el borrado existente en el
// proveedor y su efecto en Inicio. DEL-02 recorre el borrado desde la
// hoja de edición con su confirmación (corregido en #185).
//
// Los casos y su resultado están en docs/casos-hu-05-06.md.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base en memoria para los widget tests: las operaciones terminan en
/// microtareas y no dependen del reloj falso de `testWidgets`.
class _MemoryDb extends DatabaseHelper {
  _MemoryDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final List<Movement> movements = [];
  final List<Income> incomes = [];
  int _nextId = 1;

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async {
    final list =
        movements
            .where(
              (m) =>
                  month == null ||
                  (m.date.year == month.year && m.date.month == month.month),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);
            return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
          });
    return list;
  }

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async {
    final list =
        incomes
            .where(
              (i) =>
                  month == null ||
                  (i.date.year == month.year && i.date.month == month.month),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<Movement> insertMovement(Movement movement) async {
    final saved = movement.copyWith(id: _nextId++);
    movements.add(saved);
    return saved;
  }

  @override
  Future<int> updateMovement(Movement movement) async {
    final index = movements.indexWhere((m) => m.id == movement.id);
    if (index < 0) return 0;
    movements[index] = movement;
    return 1;
  }

  @override
  Future<int> deleteMovement(int id) async {
    final before = movements.length;
    movements.removeWhere((m) => m.id == id);
    return before - movements.length;
  }

  @override
  Future<Movement?> getMovement(int id) async {
    for (final movement in movements) {
      if (movement.id == id) return movement;
    }
    return null;
  }
}

class _Harness {
  final _MemoryDb db;
  final MovementProvider movements;
  final IncomeProvider incomes;

  const _Harness(this.db, this.movements, this.incomes);
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper realDb;
  late MovementProvider realMovements;
  late IncomeProvider realIncomes;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_edit_delete_test');
    realDb = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    realMovements = MovementProvider(database: realDb);
    realIncomes = IncomeProvider(database: realDb);
  });

  tearDown(() async {
    realMovements.dispose();
    realIncomes.dispose();
    await realDb.close();
    tempDir.deleteSync(recursive: true);
    FormatUtils.configure(currency: 'MXN', language: 'es');
  });

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<_Harness> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = _MemoryDb();
    final movements = MovementProvider(database: db);
    final incomes = IncomeProvider(database: db);
    addTearDown(() {
      movements.dispose();
      incomes.dispose();
    });
    await movements.load();
    await incomes.load();
    await tester.pumpWidget(
      MultiProvider(
        key: UniqueKey(),
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
        ],
        child: const KopayApp(),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(db, movements, incomes);
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  /// Texto que sigue a una etiqueta ("Ingresos", "Gastos").
  String after(WidgetTester tester, String label) {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    return texts[texts.indexOf(label) + 1];
  }

  /// Balance completo: parte entera (key `home-balance`) más decimales.
  String balance(WidgetTester tester) {
    final row = find.ancestor(
      of: find.byKey(const Key('home-balance')),
      matching: find.byType(Row),
    );
    return tester
        .widgetList<Text>(
          find.descendant(of: row.first, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .join();
  }

  testWidgets('EDIT-01 · HU-05 · editar desde el historial actualiza la lista, '
      'Inicio y la base', (tester) async {
    final app = await startApp(tester);
    final guardado = await app.movements.add(
      Movement(
        amount: -50,
        description: 'Café',
        category: 'Comida',
        date: today(),
      ),
    );
    await tester.pumpAndSettle();

    // Antes de editar, Inicio muestra el gasto original.
    expect(balance(tester), r'−$50.00');

    await goTo(tester, 'Movimientos');
    expect(find.text('Café'), findsOneWidget);
    await tapKey(tester, 'history-movement-${guardado.id}');
    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.text('50.00'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('movement-description')),
      'Desayuno',
    );
    await tester.enterText(find.byKey(const Key('movement-amount')), '80.00');
    await tapKey(tester, 'movement-save');

    // La lista muestra los datos nuevos y ya no el registro anterior.
    expect(find.text('Desayuno'), findsOneWidget);
    expect(find.text('Café'), findsNothing);
    expect(find.text(r'−$80.00'), findsOneWidget);

    // El resumen de Inicio se recalcula con el nuevo importe.
    await goTo(tester, 'Inicio');
    expect(find.text('Desayuno'), findsOneWidget);
    expect(find.text('Café'), findsNothing);
    expect(after(tester, 'Gastos'), r'$80');
    expect(balance(tester), r'−$80.00');

    // La capa de datos recibió la edición.
    final enBase = app.db.movements.single;
    expect(enBase.description, 'Desayuno');
    expect(enBase.amount, -80);
    expect(enBase.category, 'Comida');
  });

  test('EDIT-02 · HU-05 · la edición persiste en SQLite', () async {
    final guardado = await realMovements.add(
      Movement(
        amount: -50,
        description: 'Café',
        category: 'Comida',
        date: today(),
      ),
    );

    await realMovements.update(
      guardado.copyWith(description: 'Desayuno', amount: -80),
    );

    final enBase = await realDb.getMovement(guardado.id!);
    expect(enBase, isNotNull);
    expect(enBase!.description, 'Desayuno');
    expect(enBase.amount, -80);
    expect(enBase.category, 'Comida');

    await realMovements.load();
    expect(realMovements.movements.single.description, 'Desayuno');
    expect(realMovements.movements.single.amount, -80);
  });

  testWidgets('DEL-01 · HU-06 · borrar desde el proveedor quita el registro y '
      'recalcula el resumen', (tester) async {
    final app = await startApp(tester);
    final borrar = await app.movements.add(
      Movement(
        amount: -50,
        description: 'Café',
        category: 'Comida',
        date: today(),
      ),
    );
    await app.movements.add(
      Movement(
        amount: -30,
        description: 'Camión',
        category: 'Transporte',
        date: today(),
      ),
    );
    await tester.pumpAndSettle();

    expect(balance(tester), r'−$80.00');
    await goTo(tester, 'Movimientos');
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Camión'), findsOneWidget);

    // La interfaz todavía no ofrece borrar; se ejerce la operación que
    // ya existe en MovementProvider y DatabaseHelper. DEL-02 cubre la
    // confirmación visual pendiente.
    await app.movements.delete(borrar.id!);
    await tester.pumpAndSettle();

    expect(find.text('Café'), findsNothing);
    expect(find.text('Camión'), findsOneWidget);

    await goTo(tester, 'Inicio');
    expect(find.text('Café'), findsNothing);
    expect(find.text('Camión'), findsOneWidget);
    expect(after(tester, 'Gastos'), r'$30');
    expect(balance(tester), r'−$30.00');
    expect(await app.db.getMovement(borrar.id!), isNull);
    expect(app.db.movements.single.description, 'Camión');
  });

  // Corregido en #185: la hoja de edición tiene "Eliminar movimiento"
  // con confirmación (`movement-delete`, `-cancel` y `-confirm`).
  testWidgets(
    'DEL-02 · HU-06 · eliminar pide confirmación, cancelar conserva y '
    'confirmar borra y actualiza el resumen',
    (tester) async {
      final app = await startApp(tester);
      final guardado = await app.movements.add(
        Movement(
          amount: -50,
          description: 'Café',
          category: 'Comida',
          date: today(),
        ),
      );
      await tester.pumpAndSettle();
      await goTo(tester, 'Movimientos');
      await tapKey(tester, 'history-movement-${guardado.id}');

      await tapKey(tester, 'movement-delete');
      expect(find.text('¿Eliminar movimiento?'), findsOneWidget);

      await tapKey(tester, 'movement-delete-cancel');
      // Cancelar conserva el registro y deja la hoja abierta.
      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(
        find.byKey(Key('history-movement-${guardado.id}')),
        findsOneWidget,
      );
      expect(await app.db.getMovement(guardado.id!), isNotNull);

      await tapKey(tester, 'movement-delete');
      await tapKey(tester, 'movement-delete-confirm');
      expect(find.text('Café'), findsNothing);
      expect(await app.db.getMovement(guardado.id!), isNull);

      await goTo(tester, 'Inicio');
      expect(balance(tester), r'$0.00');
    },
  );
}
