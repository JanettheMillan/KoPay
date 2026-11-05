import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/screens/movements_screen.dart';
import 'package:provider/provider.dart';

/// Providers en memoria con datos fijos, sin SQLite.
class FakeMovements extends MovementProvider {
  List<Movement> data;
  FakeMovements(this.data);

  @override
  List<Movement> get movements => List.unmodifiable(data);
  @override
  bool get isLoaded => true;

  void replace(List<Movement> next) {
    data = next;
    notifyListeners();
  }
}

class FakeIncomes extends IncomeProvider {
  final List<Income> data;
  FakeIncomes(this.data);

  @override
  List<Income> get incomes => List.unmodifiable(data);
  @override
  bool get isLoaded => true;
}

Movement gasto(int id, String d, DateTime date, double amount) => Movement(
  id: id,
  amount: amount,
  description: d,
  category: 'Comida',
  date: date,
);

Income ingreso(int id, String name, DateTime date) =>
    Income(id: id, name: name, amount: 12000, date: date);

void main() {
  group('buildHistory', () {
    test('reúne movimientos e ingresos ordenados por fecha', () {
      final history = buildHistory(
        [
          gasto(1, 'Súper', DateTime(2026, 11, 3), -1350.5),
          gasto(2, 'Renta', DateTime(2026, 10, 2), -4500),
          gasto(3, 'Reembolso', DateTime(2026, 11, 9), 200),
        ],
        [
          ingreso(1, 'Salario nov', DateTime(2026, 11, 1)),
          ingreso(2, 'Bono', DateTime(2026, 11, 15)),
        ],
      );

      expect(history.map((e) => e.asMovement.description), [
        'Bono',
        'Reembolso',
        'Súper',
        'Salario nov',
        'Renta',
      ]);
      expect(history.where((e) => e.isIncome), hasLength(2));
      expect(history.first.asMovement.amount, 12000);
    });

    test('con la misma fecha conserva el orden de llegada', () {
      final dia = DateTime(2026, 11, 5);
      final history = buildHistory(
        [gasto(2, 'B', dia, -1), gasto(1, 'A', dia, -1)],
        [ingreso(1, 'C', dia)],
      );
      expect(history.map((e) => e.asMovement.description), ['B', 'A', 'C']);
    });

    test('un ingreso y un movimiento con el mismo id no se confunden', () {
      final history = buildHistory(
        [gasto(1, 'Súper', DateTime(2026, 11, 3), -100)],
        [ingreso(1, 'Salario', DateTime(2026, 11, 1))],
      );
      expect(history[0].movement?.id, 1);
      expect(history[1].income?.id, 1);
    });
  });

  group('MovementsScreen', () {
    Future<void> pump(
      WidgetTester tester,
      MovementProvider movements,
      IncomeProvider incomes,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MovementProvider>.value(value: movements),
            ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
          ],
          child: const MaterialApp(home: Scaffold(body: MovementsScreen())),
        ),
      );
    }

    testWidgets('sin registros muestra un mensaje', (tester) async {
      await pump(tester, FakeMovements([]), FakeIncomes([]));
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
    });

    testWidgets('muestra ambos tipos ordenados y agrupados por mes', (
      tester,
    ) async {
      await pump(
        tester,
        FakeMovements([
          gasto(1, 'Súper', DateTime(2026, 11, 3), -1350.5),
          gasto(2, 'Renta', DateTime(2026, 10, 2), -4500),
        ]),
        FakeIncomes([ingreso(1, 'Salario', DateTime(2026, 11, 1))]),
      );

      expect(find.text('NOVIEMBRE 2026'), findsOneWidget);
      expect(find.text('OCTUBRE 2026'), findsOneWidget);
      expect(find.text('ingreso · 1 nov'), findsOneWidget);
      expect(find.text('comida · 3 nov'), findsOneWidget);
      expect(find.text(r'+$12,000.00'), findsOneWidget);
      expect(find.text(r'−$1,350.50'), findsOneWidget);

      final top = <String, double>{
        for (final t in ['Súper', 'Salario', 'Renta'])
          t: tester.getTopLeft(find.text(t)).dy,
      };
      expect(top['Súper']! < top['Salario']!, isTrue);
      expect(top['Salario']! < top['Renta']!, isTrue);
    });

    testWidgets('se actualiza cuando el provider cambia', (tester) async {
      final movements = FakeMovements([]);
      await pump(tester, movements, FakeIncomes([]));
      expect(find.byKey(const Key('history-empty')), findsOneWidget);

      movements.replace([gasto(1, 'Cine', DateTime(2026, 11, 6), -320)]);
      await tester.pump();

      expect(find.text('Cine'), findsOneWidget);
      expect(find.byKey(const Key('history-empty')), findsNothing);
    });

    testWidgets('tocar una fila abre su formulario para editar', (
      tester,
    ) async {
      await pump(
        tester,
        FakeMovements([gasto(1, 'Súper', DateTime(2026, 11, 3), -100)]),
        FakeIncomes([ingreso(1, 'Salario', DateTime(2026, 11, 1))]),
      );

      await tester.tap(find.byKey(const Key('history-income-1')));
      await tester.pumpAndSettle();
      expect(find.text('Editar ingreso'), findsOneWidget);

      Navigator.of(tester.element(find.text('Editar ingreso'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history-movement-1')));
      await tester.pumpAndSettle();
      expect(find.text('Editar movimiento'), findsOneWidget);
    });
  });
}
