// D-05 · S2-01 · Inicio lee los providers en lugar de datos de ejemplo
// (HU-01, HU-02, HU-09).
//
// Los providers son los reales; la base es una versión en memoria para
// que la interfaz no espere a SQLite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Movimientos e ingresos en memoria.
class _MemoryDb extends DatabaseHelper {
  _MemoryDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final List<Movement> movements = [];
  final List<Income> incomes = [];
  var _nextId = 1;

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async =>
      [...movements]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async =>
      [...incomes]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<Movement> insertMovement(Movement movement) async {
    final saved = movement.copyWith(id: _nextId++);
    movements.add(saved);
    return saved;
  }

  @override
  Future<Income> insertIncome(Income income) async {
    final saved = income.copyWith(id: _nextId++);
    incomes.add(saved);
    return saved;
  }
}

void main() {
  late _MemoryDb db;
  late MovementProvider movements;
  late IncomeProvider incomes;

  final now = DateTime.now();
  DateTime day(int monthOffset, int d) =>
      DateTime(now.year, now.month + monthOffset, d);

  setUp(() {
    db = _MemoryDb();
    movements = MovementProvider(database: db);
    incomes = IncomeProvider(database: db);
  });

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await movements.load();
    await incomes.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: movements),
          ChangeNotifierProvider.value(value: incomes),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
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

  testWidgets('HOME-01 · D-05 · con la base vacía no hay datos de ejemplo', (
    tester,
  ) async {
    await openHome(tester);

    expect(find.text('Sin movimientos este mes.'), findsOneWidget);
    expect(find.text('Salario'), findsNothing);
    expect(balance(tester), r'$0.00');
    expect(after(tester, 'Ingresos'), r'$0');
    expect(after(tester, 'Gastos'), r'$0');
  });

  testWidgets('HOME-02 · HU-09 · muestra solo el mes elegido y sus totales', (
    tester,
  ) async {
    db.movements.addAll([
      Movement(
        id: 1,
        amount: -250.5,
        description: 'Súper',
        category: 'Comida',
        date: day(0, 2),
      ),
      Movement(
        id: 2,
        amount: 100,
        description: 'Reembolso',
        category: 'Otros',
        date: day(0, 3),
      ),
      Movement(
        id: 3,
        amount: -999,
        description: 'Renta vieja',
        category: 'Vivienda',
        date: day(-1, 5),
      ),
    ]);
    db.incomes.add(
      Income(id: 4, name: 'Quincena', amount: 12000, date: day(0, 1)),
    );
    await openHome(tester);

    // Mes actual: 12,000 + 100 de entradas, 250.50 de gastos.
    expect(find.text('Súper'), findsOneWidget);
    expect(find.text('Reembolso'), findsOneWidget);
    expect(find.text('Quincena'), findsOneWidget);
    expect(find.text('Renta vieja'), findsNothing);
    expect(balance(tester), r'$11,849.50');
    expect(find.byKey(const Key('home-income-4')), findsOneWidget);
    expect(find.byKey(const Key('home-movement-1')), findsOneWidget);

    // Mes anterior: solo la renta, así que el balance es negativo.
    await tester.tap(find.byKey(const Key('month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('Renta vieja'), findsOneWidget);
    expect(find.text('Súper'), findsNothing);
    expect(balance(tester), r'−$999.00');
  });

  testWidgets('HOME-04 · HU-09 · ingresos, gastos y pagos se muestran '
      'separados y el saldo resta los pagos', (tester) async {
    db.movements.addAll([
      Movement(
        id: 1,
        amount: -120,
        description: 'Luz',
        category: 'Servicios',
        date: day(0, 2),
      ),
      Movement(
        id: 2,
        amount: -30,
        description: 'Pago tarjeta',
        category: DatabaseHelper.paymentCategory,
        date: day(0, 3),
        type: MovementType.payment,
      ),
    ]);
    db.incomes.add(
      Income(id: 3, name: 'Quincena', amount: 500, date: day(0, 1)),
    );
    await openHome(tester);

    expect(after(tester, 'Ingresos'), r'$500');
    expect(after(tester, 'Gastos'), r'$120');
    expect(after(tester, 'Pagos'), r'$30');
    expect(find.byKey(const Key('home-payments')), findsOneWidget);
    expect(balance(tester), r'$350.00');
    expect(find.text('Pago tarjeta'), findsOneWidget);
  });

  testWidgets('HOME-03 · HU-01 · HU-02 · guardar un gasto y un ingreso '
      'actualiza Inicio sin reabrir', (tester) async {
    await openHome(tester);

    await movements.add(
      Movement(
        amount: -50,
        description: 'Prueba café',
        category: 'Comida',
        date: day(0, 1),
      ),
    );
    await incomes.add(Income(name: 'Nómina', amount: 500, date: day(0, 1)));
    await tester.pumpAndSettle();

    expect(find.text('Prueba café'), findsOneWidget);
    expect(find.text('Nómina'), findsOneWidget);
    expect(after(tester, 'Ingresos'), r'$500');
    expect(after(tester, 'Gastos'), r'$50');
    expect(balance(tester), r'$450.00');
    expect(find.text('Sin movimientos este mes.'), findsNothing);
  });
}
