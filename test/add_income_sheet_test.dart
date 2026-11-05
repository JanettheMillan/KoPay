import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:kopay/widgets/add_income_sheet.dart';
import 'package:provider/provider.dart';

/// Provider en memoria con las mismas validaciones que el real, para que
/// las pruebas de interfaz no esperen a SQLite.
class FakeIncomeProvider extends IncomeProvider {
  final List<Income> saved = [];
  int _nextId = 1;

  @override
  List<Income> get incomes => List.unmodifiable(saved);

  @override
  Future<Income> add(Income income) async {
    final error = Validators.checkIncome(income);
    if (error != null) throw ValidationException(error);
    final withId = income.copyWith(id: _nextId++);
    saved.add(withId);
    notifyListeners();
    return withId;
  }

  @override
  Future<void> update(Income income) async {
    final error = Validators.checkIncome(income);
    if (error != null) throw ValidationException(error);
    saved[saved.indexWhere((i) => i.id == income.id)] = income;
    notifyListeners();
  }
}

void main() {
  late FakeIncomeProvider provider;

  setUp(() => provider = FakeIncomeProvider());
  tearDown(() => provider.dispose());

  Future<List<Income?>> openSheet(
    WidgetTester tester, {
    Income? initial,
  }) async {
    final results = <Income?>[];
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<IncomeProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showAddIncomeSheet(context, initial: initial),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('income-save')));
    await tester.tap(find.byKey(const Key('income-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra nombre, monto, fecha y nota', (tester) async {
    await openSheet(tester);

    expect(find.text('Nuevo ingreso'), findsOneWidget);
    for (final key in [
      'income-name',
      'income-amount',
      'income-date',
      'income-note',
      'income-save',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('no guarda un ingreso vacío y muestra los errores', (
    tester,
  ) async {
    final results = await openSheet(tester);
    await save(tester);

    expect(find.text(Validators.emptyName), findsOneWidget);
    expect(find.text(Validators.emptyAmount), findsOneWidget);
    expect(find.text('Nuevo ingreso'), findsOneWidget);
    expect(results, isEmpty);
    expect(provider.saved, isEmpty);
  });

  testWidgets('no guarda si falta el nombre', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('income-amount')), '12000');
    await save(tester);

    expect(find.text(Validators.emptyName), findsOneWidget);
    expect(provider.saved, isEmpty);
  });

  testWidgets('no guarda si el monto es inválido', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('income-name')), 'Salario');
    await tester.enterText(find.byKey(const Key('income-amount')), '0');
    await save(tester);

    expect(find.text(Validators.notPositive), findsOneWidget);
    expect(provider.saved, isEmpty);
  });

  testWidgets('un ingreso completo se guarda y cierra la hoja', (tester) async {
    final results = await openSheet(tester);

    await tester.enterText(find.byKey(const Key('income-name')), ' Salario ');
    await tester.enterText(find.byKey(const Key('income-amount')), '12,000');
    await tester.enterText(find.byKey(const Key('income-note')), 'Quincena');
    await save(tester);

    expect(find.text('Nuevo ingreso'), findsNothing);
    final saved = results.single!;
    expect(saved.id, isNotNull);
    expect(saved.name, 'Salario');
    expect(saved.amount, 12000);
    expect(saved.note, 'Quincena');
    final today = DateTime.now();
    expect(saved.date, DateTime(today.year, today.month, today.day));
    expect(provider.saved, [saved]);
  });

  testWidgets('editar carga los datos y guarda los cambios', (tester) async {
    final original = await provider.add(
      Income(name: 'Salario', amount: 12000, date: DateTime(2026, 11, 1)),
    );

    final results = await openSheet(tester, initial: original);
    expect(find.text('Editar ingreso'), findsOneWidget);
    expect(find.text('12000.00'), findsOneWidget);
    expect(find.text('01/11/2026'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('income-name')), 'Bono');
    await save(tester);

    final edited = results.single!;
    expect(edited.id, original.id);
    expect(edited.name, 'Bono');
    expect(provider.saved, [edited]);
  });
}
