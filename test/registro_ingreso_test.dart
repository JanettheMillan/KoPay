// #8 · Probar registro de un ingreso (HU-02).
//
// Recorre la app completa con providers en memoria que aplican las mismas
// validaciones que los reales. La persistencia en SQLite ya la prueba
// test/income_provider_test.dart; aquí se comprueba el flujo de usuario:
// formulario → fecha y nota → total del mes → Movimientos.
//
// Lo que NO cubre: que Inicio refleje el ingreso. Hoy Inicio usa datos de
// ejemplo fijos (home_screen.dart), así que ese criterio queda pendiente.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:kopay/utils/validators.dart';
import 'package:provider/provider.dart';

class MemoryMovements extends MovementProvider {
  @override
  bool get isLoaded => true;
  @override
  List<Movement> get movements => const [];
}

class MemoryIncomes extends IncomeProvider {
  final List<Income> saved = [];
  int _id = 1;

  @override
  bool get isLoaded => true;
  @override
  List<Income> get incomes =>
      List.unmodifiable([...saved]..sort((a, b) => b.date.compareTo(a.date)));

  @override
  double totalForMonth(DateTime month) => saved
      .where((i) => i.date.year == month.year && i.date.month == month.month)
      .fold(0.0, (sum, i) => sum + i.amount);

  @override
  Future<Income> add(Income i) async {
    final error = Validators.checkIncome(i);
    if (error != null) throw ValidationException(error);
    final withId = i.copyWith(id: _id++);
    saved.add(withId);
    notifyListeners();
    return withId;
  }
}

void main() {
  late MemoryMovements movements;
  late MemoryIncomes incomes;

  setUp(() {
    movements = MemoryMovements();
    incomes = MemoryIncomes();
  });

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1800, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
        ],
        child: const KopayApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'HU-02 · Ingreso con nombre, monto positivo, fecha y nota se guarda y aparece en Movimientos',
    (tester) async {
      await startApp(tester);
      final hoy = DateTime.now();
      final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);

      await tapKey(tester, 'add-button');
      expect(find.text('¿Qué quieres registrar?'), findsOneWidget);
      await tapKey(tester, 'add-income');

      await tester.enterText(find.byKey(const Key('income-name')), 'Nómina');
      await tester.enterText(find.byKey(const Key('income-amount')), '12,000');
      await tester.enterText(
        find.byKey(const Key('income-note')),
        'Quincena',
      );
      await tapKey(tester, 'income-save');

      // Se cierra el formulario y se confirma el guardado.
      expect(find.text('Nuevo ingreso'), findsNothing);
      expect(find.text('Ingreso guardado'), findsOneWidget);

      // Monto positivo, fecha de hoy por defecto y nota.
      expect(incomes.saved, hasLength(1));
      final ingreso = incomes.saved.single;
      expect(ingreso.name, 'Nómina');
      expect(ingreso.amount, 12000);
      expect(ingreso.date, fechaHoy);
      expect(ingreso.note, 'Quincena');

      // El total del mes de su fecha lo incluye.
      expect(incomes.totalForMonth(fechaHoy), 12000);

      // Movimientos muestra el ingreso con signo y su fecha.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Movimientos'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nómina'), findsOneWidget);
      expect(find.text(r'+$12,000.00'), findsOneWidget);
      expect(
        find.textContaining(FormatUtils.shortDate(fechaHoy)),
        findsWidgets,
      );
    },
  );
}
