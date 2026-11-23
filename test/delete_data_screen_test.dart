// S2-20 · Borrar datos desde Ajustes (HU-28).
//
// Casos BOR de docs/criterios-respaldo-importacion-borrado.md (S2-03).
// La base se reemplaza por listas en memoria para recorrer la app
// completa sin SQLite: Ajustes → Borrar datos → Movimientos.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/utils/app_colors.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base en memoria: movimientos, ingresos y ajustes en listas y mapas.
class MemoryDataDb extends DatabaseHelper {
  MemoryDataDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final List<Movement> movements = [
    Movement(
      id: 1,
      amount: -250.5,
      description: 'Súper',
      category: 'Comida',
      date: DateTime(2026, 11, 2),
    ),
    Movement(
      id: 2,
      amount: -80,
      description: 'Camión',
      category: 'Transporte',
      date: DateTime(2026, 11, 3),
    ),
  ];
  final List<Income> incomes = [
    Income(id: 1, name: 'Quincena', amount: 12000, date: DateTime(2026, 11)),
  ];
  final Map<String, String> settings = Map.of(DatabaseHelper.defaultSettings);
  bool failDelete = false;
  int deleteCalls = 0;

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async =>
      List.of(movements);

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async => List.of(incomes);

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      settings[key] = value;

  @override
  Future<void> deleteFinancialData() async {
    deleteCalls++;
    // Igual que la transacción real: si falla, no se borra nada.
    if (failDelete) throw Exception('disco bloqueado');
    movements.clear();
    incomes.clear();
  }
}

void main() {
  late MemoryDataDb db;

  setUp(() => db = MemoryDataDb());
  tearDown(() => FormatUtils.configure(currency: 'MXN', language: 'es'));

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final movements = MovementProvider(database: db);
    final incomes = IncomeProvider(database: db);
    final settings = SettingsProvider(database: db);
    await movements.load();
    await incomes.load();
    await settings.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const KopayApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('UI-BOR · HU-28 · Ajustes muestra "Borrar datos" en rojo', (
    tester,
  ) async {
    await openApp(tester);
    await goTo(tester, 'Ajustes');

    expect(find.text('DATOS'), findsOneWidget);
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('settings-delete-data')),
        matching: find.text('Borrar datos'),
      ),
    );
    expect(label.style?.color, AppColors.red);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BOR-01 · HU-28 · Cancelar conserva todos los registros', (
    tester,
  ) async {
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-delete-data');

    expect(find.text('¿Borrar todos tus datos?'), findsOneWidget);
    expect(find.textContaining('categorías y ajustes se conservan'), findsOne);

    await tapKey(tester, 'delete-data-cancel');

    expect(find.text('¿Borrar todos tus datos?'), findsNothing);
    expect(db.deleteCalls, 0);
    expect(db.movements, hasLength(2));
    expect(db.incomes, hasLength(1));

    await goTo(tester, 'Movimientos');
    expect(find.byKey(const Key('history-movement-1')), findsOneWidget);
    expect(find.byKey(const Key('history-income-1')), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsNothing);
  });

  testWidgets(
    'BOR-02 · HU-28 · Confirmar borra y Movimientos muestra el estado vacío',
    (tester) async {
      await openApp(tester);
      await goTo(tester, 'Movimientos');
      expect(find.byKey(const Key('history-movement-2')), findsOneWidget);

      await goTo(tester, 'Ajustes');
      await tapKey(tester, 'settings-delete-data');
      await tapKey(tester, 'delete-data-confirm');

      expect(db.deleteCalls, 1);
      expect(find.text('Datos borrados'), findsOneWidget);

      // Sin reiniciar la app.
      await goTo(tester, 'Movimientos');
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(find.byKey(const Key('history-movement-1')), findsNothing);
      expect(find.byKey(const Key('history-income-1')), findsNothing);
    },
  );

  testWidgets('BOR-02 · HU-28 · Confirmar conserva moneda e idioma', (
    tester,
  ) async {
    db.settings['currency'] = 'USD';
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-delete-data');
    await tapKey(tester, 'delete-data-confirm');

    expect(db.settings['currency'], 'USD');
    expect(db.settings['language'], 'es');
    expect(find.text(r'US$ USD'), findsOneWidget);
  });

  testWidgets('BOR-04 · HU-28 · Si el borrado falla se avisa y no se borra', (
    tester,
  ) async {
    db.failDelete = true;
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-delete-data');
    await tapKey(tester, 'delete-data-confirm');

    expect(
      find.text('No se pudieron borrar los datos. No se borró nada.'),
      findsOneWidget,
    );
    expect(find.text('Datos borrados'), findsNothing);

    await goTo(tester, 'Movimientos');
    expect(find.byKey(const Key('history-movement-1')), findsOneWidget);
    expect(find.byKey(const Key('history-empty')), findsNothing);
  });

  testWidgets('UI-BOR · HU-25 · HU-28 · Confirmación en inglés', (
    tester,
  ) async {
    db.settings['language'] = 'en';
    await openApp(tester);
    await goTo(tester, 'Settings');
    await tapKey(tester, 'settings-delete-data');

    expect(find.text('Delete all your data?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tapKey(tester, 'delete-data-confirm');
    expect(find.text('Data deleted'), findsOneWidget);
  });
}
