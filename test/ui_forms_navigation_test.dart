// S1-17 · Pruebas de interfaz de formularios y navegación.
//
// Recorre la app completa (KopayApp) con providers en memoria que
// aplican las mismas validaciones que los reales, sin SQLite. El
// resultado de cada caso está en la sección 8.2 de docs/plan-de-pruebas.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:provider/provider.dart';

class MemoryMovements extends MovementProvider {
  final List<Movement> saved = [];
  int _id = 1;

  @override
  bool get isLoaded => true;
  @override
  List<Movement> get movements =>
      List.unmodifiable([...saved]..sort((a, b) => b.date.compareTo(a.date)));

  @override
  Future<Movement> add(Movement m) async {
    final error = Validators.checkMovement(m);
    if (error != null) throw ValidationException(error);
    final withId = m.copyWith(id: _id++);
    saved.add(withId);
    notifyListeners();
    return withId;
  }

  @override
  Future<void> update(Movement m) async {
    final error = Validators.checkMovement(m);
    if (error != null) throw ValidationException(error);
    saved[saved.indexWhere((x) => x.id == m.id)] = m;
    notifyListeners();
  }
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
    // 600 × 844 pt: la fuente de prueba es más ancha que la real y a 390 pt
    // el balance de Inicio se desborda (OBS-01, verificar en dispositivo).
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

  Future<void> openForm(WidgetTester tester, String kind) async {
    await tapKey(tester, 'add-button');
    expect(find.text('¿Qué quieres registrar?'), findsOneWidget);
    await tapKey(tester, 'add-$kind');
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  group('Navegación', () {
    testWidgets('NAV-01 · Las tres pestañas cambian de pantalla', (
      tester,
    ) async {
      await startApp(tester);
      expect(find.byKey(const Key('home-balance')), findsOneWidget);

      await goTo(tester, 'Movimientos');
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(find.byKey(const Key('add-button')), findsOneWidget);

      await goTo(tester, 'Ajustes');
      expect(find.byKey(const Key('add-button')), findsNothing);

      await goTo(tester, 'Inicio');
      expect(find.byKey(const Key('home-balance')), findsOneWidget);
    });

    testWidgets('NAV-02 · El botón + ofrece gasto o ingreso y se cierra', (
      tester,
    ) async {
      await startApp(tester);
      await tapKey(tester, 'add-button');
      expect(find.byKey(const Key('add-movement')), findsOneWidget);
      expect(find.byKey(const Key('add-income')), findsOneWidget);

      Navigator.of(tester.element(find.text('¿Qué quieres registrar?'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('¿Qué quieres registrar?'), findsNothing);
    });
  });

  group('Formulario de gasto', () {
    testWidgets('UI-02 · Validación de gasto: vacío, cero y sin descripción', (
      tester,
    ) async {
      await startApp(tester);
      await openForm(tester, 'movement');
      expect(find.text('Nuevo gasto'), findsOneWidget);

      // 1. Todo vacío.
      await tapKey(tester, 'movement-save');
      expect(find.text(Validators.emptyAmount), findsOneWidget);
      expect(find.text(Validators.emptyDescription), findsOneWidget);
      expect(find.text(Validators.emptyCategory), findsOneWidget);

      // 2. Monto cero con descripción vacía.
      await tester.enterText(find.byKey(const Key('movement-amount')), '0');
      await tapKey(tester, 'movement-save');
      expect(find.text(Validators.notPositive), findsOneWidget);
      expect(find.text(Validators.emptyDescription), findsOneWidget);

      // 3. Descripción con solo espacios.
      await tester.enterText(find.byKey(const Key('movement-amount')), '50');
      await tester.enterText(
        find.byKey(const Key('movement-description')),
        '   ',
      );
      await tapKey(tester, 'movement-save');
      expect(find.text(Validators.emptyDescription), findsOneWidget);

      // El formulario sigue abierto y no se guardó nada.
      expect(find.text('Nuevo gasto'), findsOneWidget);
      expect(movements.saved, isEmpty);
    });

    testWidgets('UI-02b · Un gasto válido se guarda y aparece en Movimientos', (
      tester,
    ) async {
      await startApp(tester);
      await openForm(tester, 'movement');

      await tester.enterText(find.byKey(const Key('movement-amount')), '50');
      await tester.enterText(
        find.byKey(const Key('movement-description')),
        'Café',
      );
      await tapKey(tester, 'movement-category');
      await tapKey(tester, 'category-Comida');
      await tapKey(tester, 'movement-save');

      expect(find.text('Nuevo gasto'), findsNothing);
      expect(find.text('Gasto guardado'), findsOneWidget);
      expect(movements.saved.single.amount, -50);

      await goTo(tester, 'Movimientos');
      expect(find.text('Café'), findsOneWidget);
      expect(find.text(r'−$50.00'), findsOneWidget);
    });
  });

  group('Formulario de ingreso', () {
    testWidgets('UI-ING-01 · Ingreso incompleto no se guarda', (tester) async {
      await startApp(tester);
      await openForm(tester, 'income');
      expect(find.text('Nuevo ingreso'), findsOneWidget);

      await tapKey(tester, 'income-save');
      expect(find.text(Validators.emptyName), findsOneWidget);
      expect(find.text(Validators.emptyAmount), findsOneWidget);

      await tester.enterText(find.byKey(const Key('income-name')), 'Nómina');
      await tapKey(tester, 'income-save');
      expect(find.text(Validators.emptyAmount), findsOneWidget);

      expect(find.text('Nuevo ingreso'), findsOneWidget);
      expect(incomes.saved, isEmpty);
    });

    testWidgets('UI-ING-02 · Un ingreso válido se guarda y aparece primero', (
      tester,
    ) async {
      await startApp(tester);
      await movements.add(
        Movement(
          amount: -50,
          description: 'Café',
          category: 'Comida',
          date: DateTime(2020, 1, 1),
        ),
      );

      await openForm(tester, 'income');
      await tester.enterText(find.byKey(const Key('income-name')), 'Nómina');
      await tester.enterText(find.byKey(const Key('income-amount')), '500');
      await tapKey(tester, 'income-save');

      expect(find.text('Ingreso guardado'), findsOneWidget);
      expect(incomes.saved.single.amount, 500);

      await goTo(tester, 'Movimientos');
      expect(find.text('Nómina'), findsOneWidget);
      expect(find.text(r'+$500.00'), findsOneWidget);
      // El ingreso de hoy va antes que el gasto de 2020.
      expect(
        tester.getTopLeft(find.text('Nómina')).dy <
            tester.getTopLeft(find.text('Café')).dy,
        isTrue,
      );
    });
  });

  group('Historial', () {
    testWidgets('UI-HIS-01 · Tocar una fila abre su edición', (tester) async {
      await startApp(tester);
      final gasto = await movements.add(
        Movement(
          amount: -50,
          description: 'Café',
          category: 'Comida',
          date: DateTime(2026, 11, 3),
        ),
      );
      await goTo(tester, 'Movimientos');

      await tapKey(tester, 'history-movement-${gasto.id}');
      expect(find.text('Editar movimiento'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('movement-description')),
        'Desayuno',
      );
      await tapKey(tester, 'movement-save');

      expect(find.text('Desayuno'), findsOneWidget);
      expect(find.text('Café'), findsNothing);
    });
  });

  test(
    'UI-07 · Pago inválido de deuda',
    () {},
    skip: 'Bloqueado: las deudas no existen en el Sprint 1 (HU-22).',
  );

  test(
    'FUT-25 · Entrada a vista de contador',
    () {},
    skip: 'Bloqueado: no hay inicio de sesión ni vista de contador (HU-37).',
  );
}
