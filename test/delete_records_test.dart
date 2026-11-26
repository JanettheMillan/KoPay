// #185 · Eliminar un movimiento o un ingreso desde la interfaz (HU-06).
//
// DEL-02 (test/edit_delete_movements_test.dart) cubre el recorrido de un
// gasto desde el historial. Estos casos nuevos (DEL-03 a DEL-05) cubren
// el ingreso, que no se ofrezca en un registro nuevo ni en un pago, y el
// texto en inglés.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/widgets/add_income_sheet.dart';
import 'package:kopay/widgets/add_movement_sheet.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryDb extends DatabaseHelper {
  _MemoryDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final List<Movement> movements = [];
  final List<Income> incomes = [];

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async => [
    ...movements,
  ];

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async => [...incomes];

  @override
  Future<int> deleteIncome(int id) async {
    final before = incomes.length;
    incomes.removeWhere((i) => i.id == id);
    return before - incomes.length;
  }
}

class _FixedSettings extends SettingsProvider {
  _FixedSettings(this._language);
  final String _language;

  @override
  String get language => _language;
}

void main() {
  final nomina = Income(
    id: 7,
    name: 'Nómina',
    amount: 500,
    date: DateTime(2026, 11, 5),
  );
  final pago = Movement(
    id: 9,
    amount: -120,
    description: 'Pago Oro',
    category: DatabaseHelper.paymentCategory,
    date: DateTime(2026, 11, 26),
    type: MovementType.payment,
    cardId: 1,
  );

  late _MemoryDb db;
  late IncomeProvider incomes;
  late MovementProvider movements;

  setUp(() async {
    db = _MemoryDb()
      ..incomes.add(nomina)
      ..movements.add(pago);
    incomes = IncomeProvider(database: db);
    movements = MovementProvider(database: db);
    await incomes.load();
    await movements.load();
  });

  /// Pantalla con un botón que abre [open], para que la hoja se cierre
  /// como en la app.
  Future<void> start(
    WidgetTester tester,
    Future<void> Function(BuildContext) open, {
    String language = 'es',
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: _FixedSettings(language),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () => open(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('DEL-03 · HU-06 · eliminar un ingreso pide confirmación, '
      'cancelar conserva y confirmar borra y avisa', (tester) async {
    await start(tester, (c) => showAddIncomeSheet(c, initial: nomina));

    await tapKey(tester, 'income-delete');
    expect(find.text(AppStrings.es.deleteIncomeTitle), findsOneWidget);
    expect(find.textContaining('"Nómina"'), findsOneWidget);
    await tapKey(tester, 'income-delete-cancel');
    expect(db.incomes, hasLength(1));
    expect(find.text('Editar ingreso'), findsOneWidget);

    await tapKey(tester, 'income-delete');
    await tapKey(tester, 'income-delete-confirm');
    expect(db.incomes, isEmpty);
    expect(incomes.incomes, isEmpty);
    expect(find.text('Editar ingreso'), findsNothing);
    expect(find.text(AppStrings.es.incomeDeleted), findsOneWidget);
  });

  testWidgets('DEL-04 · HU-06 · un registro nuevo y un pago no ofrecen '
      'Eliminar', (tester) async {
    await start(tester, (c) => showAddMovementSheet(c));
    expect(find.byKey(const Key('movement-delete')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await start(tester, (c) => showAddIncomeSheet(c));
    expect(find.byKey(const Key('income-delete')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Borrar un pago hoy no devolvería el saldo a su tarjeta (#18).
    await start(tester, (c) => showAddMovementSheet(c, initial: pago));
    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.byKey(const Key('movement-delete')), findsNothing);
  });

  testWidgets('DEL-05 · HU-25 · el borrado se muestra en inglés', (
    tester,
  ) async {
    await start(
      tester,
      (c) => showAddIncomeSheet(c, initial: nomina),
      language: 'en',
    );
    expect(find.text('Delete income'), findsOneWidget);
    await tapKey(tester, 'income-delete');
    expect(find.text('Delete income?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
