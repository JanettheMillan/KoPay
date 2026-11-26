// S2-14 · Formulario y consulta de deuda (HU-19, HU-21).
//
// El plan de pruebas no tiene casos de interfaz para deudas; estos son
// casos nuevos (UI-DEU-xx). Usan el DebtProvider real sobre una base en
// memoria, así que el estado (pendiente o pagada) lo pone el provider
// igual que en la app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/home_screen.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:kopay/utils/validators.dart';
import 'package:kopay/widgets/debts_section.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Deudas, movimientos e ingresos en memoria.
class _MemoryDb extends DatabaseHelper {
  _MemoryDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final List<DebtModel> debts = [];
  var _nextId = 1;

  @override
  Future<List<DebtModel>> getDebts() async =>
      [...debts]..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  @override
  Future<DebtModel?> getDebt(int id) async {
    for (final d in debts) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<DebtModel> insertDebt(DebtModel debt) async {
    final saved = debt.copyWith(id: _nextId++);
    debts.add(saved);
    return saved;
  }

  @override
  Future<int> updateDebt(DebtModel debt) async {
    debts[debts.indexWhere((d) => d.id == debt.id)] = debt;
    return 1;
  }

  @override
  Future<int> deleteDebt(int id) async {
    debts.removeWhere((d) => d.id == id);
    return 1;
  }

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async => [];

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async => [];
}

/// Ajustes sin base: solo el idioma, para probar los textos en inglés.
class _FixedSettings extends SettingsProvider {
  _FixedSettings(this._language);
  final String _language;

  @override
  String get language => _language;
}

void main() {
  late _MemoryDb db;
  late DebtProvider debts;

  setUp(() {
    db = _MemoryDb();
    debts = DebtProvider(database: db);
  });

  Future<void> start(WidgetTester tester, {String language = 'es'}) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await debts.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DebtProvider>.value(value: debts),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: _FixedSettings(language),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DebtsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, Map<String, String> fields) async {
    for (final entry in fields.entries) {
      final field = find.byKey(Key('debt-${entry.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
  }

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  DebtModel debt({
    String name = 'Préstamo auto',
    double monthly = 2500,
    double remaining = 30000,
    DateTime? due,
  }) => DebtModel(
    name: name,
    monthlyPayment: monthly,
    remainingBalance: remaining,
    dueDate: due ?? DateTime.now().add(const Duration(days: 20)),
  );

  testWidgets('UI-DEU-01 · HU-19 · Inicio muestra la sección de deudas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 2532); // ver OBS-01
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final movements = MovementProvider(database: db);
    final incomes = IncomeProvider(database: db);
    await movements.load();
    await incomes.load();
    await debts.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
          ChangeNotifierProvider<DebtProvider>.value(value: debts),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('debts-empty')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('home-debts')), findsOneWidget);
    expect(find.byKey(const Key('debts-add')), findsOneWidget);
  });

  testWidgets('UI-DEU-02 · HU-19 · Formulario incompleto o inválido no '
      'guarda', (tester) async {
    await start(tester);
    await tapKey(tester, 'debts-add');
    await tapKey(tester, 'debt-save');

    expect(find.text(Validators.emptyDebtName), findsOneWidget);
    expect(find.text(Validators.emptyAmount), findsNWidgets(2));
    expect(db.debts, isEmpty);

    await fill(tester, {
      'name': 'Préstamo',
      'monthly': '-5',
      'remaining': 'abc',
    });
    await tapKey(tester, 'debt-save');
    expect(find.text(AppStrings.es.newDebt), findsOneWidget);
    expect(db.debts, isEmpty);
  });

  testWidgets('UI-DEU-03 · HU-19 · Una deuda válida aparece con saldo y '
      'vencimiento', (tester) async {
    await start(tester);
    await tapKey(tester, 'debts-add');
    await fill(tester, {
      'name': 'Préstamo auto',
      'monthly': '2500',
      'remaining': '30,000.50',
    });
    await tapKey(tester, 'debt-save');

    expect(db.debts, hasLength(1));
    final saved = db.debts.single;
    expect(saved.name, 'Préstamo auto');
    expect(saved.monthlyPayment, 2500);
    expect(saved.remainingBalance, 30000.50);
    expect(saved.status, DebtStatus.pending);

    expect(find.text('Préstamo auto'), findsOneWidget);
    expect(find.text(FormatUtils.money(30000.50)), findsOneWidget);
    expect(
      find.text(
        AppStrings.fill(AppStrings.es.debtDue, [
          FormatUtils.shortDate(saved.dueDate),
        ]),
      ),
      findsOneWidget,
    );
    expect(find.text(AppStrings.es.debtPending), findsOneWidget);
  });

  testWidgets('UI-DEU-04 · HU-19 · Las deudas se listan por vencimiento y '
      'muestran vencida o pagada', (tester) async {
    final now = DateTime.now();
    await debts.add(
      debt(name: 'Tarde', due: now.add(const Duration(days: 40))),
    );
    await debts.add(
      debt(name: 'Atrasada', due: now.subtract(const Duration(days: 3))),
    );
    await debts.add(
      debt(
        name: 'Liquidada',
        remaining: 0,
        due: now.add(const Duration(days: 5)),
      ),
    );
    await start(tester);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => ['Tarde', 'Atrasada', 'Liquidada'].contains(t))
        .toList();
    expect(names, ['Atrasada', 'Liquidada', 'Tarde']);
    expect(textOf(tester, 'debt-status-2'), AppStrings.es.debtOverdue);
    expect(textOf(tester, 'debt-status-3'), AppStrings.es.debtPaid);
    expect(textOf(tester, 'debt-status-1'), AppStrings.es.debtPending);
  });

  testWidgets('UI-DEU-05 · HU-19 · Tocar la deuda abre su detalle', (
    tester,
  ) async {
    final due = DateTime(2027, 1, 15);
    await debts.add(debt(monthly: 2500, remaining: 30000, due: due));
    await start(tester);
    await tapKey(tester, 'debt-row-1');

    expect(textOf(tester, 'debt-remaining-value'), FormatUtils.money(30000));
    expect(textOf(tester, 'debt-monthly-value'), FormatUtils.money(2500));
    expect(textOf(tester, 'debt-due-value'), FormatUtils.fullDate(due));
    expect(textOf(tester, 'debt-status-value'), AppStrings.es.debtPending);
    expect(find.byKey(const Key('debt-edit')), findsOneWidget);
    expect(find.byKey(const Key('debt-delete')), findsOneWidget);
  });

  testWidgets('UI-DEU-06 · HU-21 · Editar el saldo a cero la deja pagada', (
    tester,
  ) async {
    await debts.add(debt());
    await start(tester);
    await tapKey(tester, 'debt-row-1');
    await tapKey(tester, 'debt-edit');
    expect(find.text(AppStrings.es.editDebt), findsOneWidget);
    await fill(tester, {'remaining': '0'});
    await tapKey(tester, 'debt-save');

    expect(db.debts.single.remainingBalance, 0);
    expect(db.debts.single.status, DebtStatus.paid);
    expect(textOf(tester, 'debt-remaining-value'), FormatUtils.money(0));
    expect(textOf(tester, 'debt-status-value'), AppStrings.es.debtPaid);
  });

  testWidgets('UI-DEU-07 · HU-19 · Cancelar conserva y confirmar elimina', (
    tester,
  ) async {
    await debts.add(debt());
    await start(tester);
    await tapKey(tester, 'debt-row-1');

    await tapKey(tester, 'debt-delete');
    await tapKey(tester, 'debt-delete-cancel');
    expect(db.debts, hasLength(1));

    await tapKey(tester, 'debt-delete');
    await tapKey(tester, 'debt-delete-confirm');
    expect(db.debts, isEmpty);
    expect(find.byKey(const Key('debts-empty')), findsOneWidget);
  });

  testWidgets('UI-DEU-08 · HU-25 · Los textos de deudas cambian a inglés', (
    tester,
  ) async {
    await debts.add(debt());
    await start(tester, language: 'en');
    expect(find.text('DEBTS'), findsOneWidget);
    expect(find.text('Add debt'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);

    await tapKey(tester, 'debt-row-1');
    expect(find.text('Remaining balance'), findsOneWidget);
    expect(find.text('Monthly payment'), findsOneWidget);
    expect(find.text('Next due date'), findsOneWidget);
  });
}
