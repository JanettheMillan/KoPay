// S2-17 · Flujos de tarjetas, deudas y pagos (HU-13 a HU-23).
//
// Recorren las pantallas con los providers reales sobre SQLite real
// (en memoria, con sqflite_ffi). Las pruebas por capa ya existían; estos
// casos nuevos (FLU-xx) comprueban cada flujo completo, desde el
// formulario hasta lo que queda guardado. Están descritos en
// docs/casos-s2-17.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/models/upcoming_payment.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/home_screen.dart';
import 'package:kopay/screens/movements_screen.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:kopay/utils/month_summary.dart';
import 'package:kopay/utils/upcoming_payments.dart';
import 'package:kopay/utils/validators.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SpanishSettings extends SettingsProvider {
  @override
  String get language => 'es';
}

/// Hoy sin hora, como lo guardan los formularios.
DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void main() {
  sqfliteFfiInit();

  late DatabaseHelper db;
  late CardProvider cards;
  late DebtProvider debts;
  late MovementProvider movements;
  late IncomeProvider incomes;

  setUp(() async {
    db = DatabaseHelper.withFactory(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
    );
    cards = CardProvider(database: db);
    debts = DebtProvider(database: db);
    movements = MovementProvider(database: db);
    incomes = IncomeProvider(database: db);
    await cards.load();
    await debts.load();
    await movements.load();
    await incomes.load();
  });

  tearDown(() async => db.close());

  /// SQLite responde con el reloj real y las pantallas avanzan con el
  /// simulado, así que se alternan los dos hasta que todo termina.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 4)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Consulta o cambia la base desde dentro de una prueba de pantalla.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() action) async =>
      (await tester.runAsync(action)) as T;

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CardProvider>.value(value: cards),
          ChangeNotifierProvider<DebtProvider>.value(value: debts),
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
          ChangeNotifierProvider<SettingsProvider>.value(
            value: _SpanishSettings(),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: screen)),
      ),
    );
    await settle(tester);
  }

  Future<void> tapOn(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> tapKey(WidgetTester tester, String key) =>
      tapOn(tester, find.byKey(Key(key)));

  Future<void> type(WidgetTester tester, String key, String text) =>
      tester.enterText(find.byKey(Key(key)), text);

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  Future<CardModel> seedCard({
    double used = 200,
    int paymentDay = 25,
    double minimum = 0,
  }) => cards.add(
    CardModel(
      name: 'Oro',
      bank: 'BBVA',
      creditLimit: 1000,
      usedBalance: used,
      cutDay: 5,
      paymentDay: paymentDay,
      minimumPayment: minimum,
    ),
  );

  Future<DebtModel> seedDebt({
    String name = 'Auto',
    double balance = 300,
    double monthly = 100,
    int dueInDays = 10,
  }) {
    final today = _today();
    return debts.add(
      DebtModel(
        name: name,
        monthlyPayment: monthly,
        remainingBalance: balance,
        // Días de calendario, sin que el horario de verano cambie la fecha.
        dueDate: DateTime(today.year, today.month, today.day + dueInDays),
      ),
    );
  }

  Future<List<UpcomingPayment>> upcomingFromDatabase() async => computeUpcoming(
    cards: await db.getCards(),
    debts: await db.getDebts(),
    movements: await db.getMovements(),
  );

  group('Tarjetas', () {
    testWidgets('FLU-01 · HU-13 · registrar desde Inicio guarda la tarjeta y '
        'muestra el disponible', (tester) async {
      await open(tester, const HomeScreen());

      await tapKey(tester, 'cards-add');
      await type(tester, 'card-name', 'Oro');
      await type(tester, 'card-bank', 'BBVA');
      await type(tester, 'card-limit', '1000');
      await type(tester, 'card-used', '250.50');
      await type(tester, 'card-cut-day', '5');
      await type(tester, 'card-payment-day', '25');
      await tapKey(tester, 'card-save');

      final saved = (await real(tester, db.getCards)).single;
      expect(saved.creditLimit, 1000);
      expect(saved.usedBalance, 250.50);
      expect(saved.available, 749.50);
      expect(find.textContaining(FormatUtils.money(749.50)), findsWidgets);
    });

    testWidgets('FLU-02 · HU-13 · una tarjeta excedida queda con disponible '
        'cero', (tester) async {
      await real(tester, () => seedCard(used: 1200));
      await open(tester, const HomeScreen());

      await tapOn(tester, find.text('Oro'));

      expect(textOf(tester, 'card-available'), FormatUtils.money(0));
    });

    testWidgets('FLU-03 · HU-14 · editar persiste y recalcula el disponible', (
      tester,
    ) async {
      await real(tester, seedCard);
      await open(tester, const HomeScreen());
      await tapOn(tester, find.text('Oro'));

      await tapKey(tester, 'card-edit');
      await type(tester, 'card-limit', '1500');
      await type(tester, 'card-used', '400');
      await type(tester, 'card-payment-day', '12');
      await tapKey(tester, 'card-save');

      final stored = (await real(tester, db.getCards)).single;
      expect(stored.creditLimit, 1500);
      expect(stored.usedBalance, 400);
      expect(stored.paymentDay, 12);
      expect(textOf(tester, 'card-available'), FormatUtils.money(1100));
    });

    testWidgets('FLU-04 · HU-15 · cancelar la conserva y confirmar la quita '
        'de la base y de Inicio', (tester) async {
      await real(tester, seedCard);
      await open(tester, const HomeScreen());
      await tapOn(tester, find.text('Oro'));

      await tapKey(tester, 'card-delete');
      await tapKey(tester, 'card-delete-cancel');
      expect(await real(tester, db.getCards), hasLength(1));

      await tapKey(tester, 'card-delete');
      await tapKey(tester, 'card-delete-confirm');
      expect(await real(tester, db.getCards), isEmpty);
      expect(find.text('Oro'), findsNothing);
    });

    testWidgets(
      'FLU-05 · HU-16 · HU-18 · pagar desde el detalle baja el saldo, '
      'cuenta como pago y cubre el vencimiento',
      (tester) async {
        // El pago vence hoy, para que el pago de hoy caiga en el periodo.
        final card = await real(
          tester,
          () => seedCard(paymentDay: _today().day, minimum: 100),
        );
        expect(
          (await real(tester, upcomingFromDatabase)).single.isPaid,
          isFalse,
        );

        await open(tester, const HomeScreen());
        await tapOn(tester, find.text('Oro'));
        await tapKey(tester, 'card-pay');
        await type(tester, 'pay-amount', '120');
        await tapKey(tester, 'pay-save');

        expect((await real(tester, db.getCards)).single.usedBalance, 80);
        expect(textOf(tester, 'card-available'), FormatUtils.money(920));
        final payment = (await real(
          tester,
          () => db.getCardPayments(card.id!),
        )).single;
        expect(payment.amount, -120);
        expect(payment.type, MovementType.payment);
        final summary = MonthSummary.of(
          await real(tester, () => db.getMovements()),
          [],
          _today(),
        );
        expect(summary.cardPayments, 120);
        expect(summary.expenses, 0);
        final due = (await real(tester, upcomingFromDatabase)).single;
        expect(due.daysLeft, 0);
        expect(due.isPaid, isTrue);
        expect(due.paidAmount, 120);
      },
    );
  });

  group('Deudas', () {
    testWidgets('FLU-06 · HU-19 · registrar desde Inicio guarda la deuda como '
        'pendiente', (tester) async {
      await open(tester, const HomeScreen());

      await tapKey(tester, 'debts-add');
      await type(tester, 'debt-name', 'Auto');
      await type(tester, 'debt-monthly', '100');
      await type(tester, 'debt-remaining', '300');
      await tapKey(tester, 'debt-save');

      final saved = (await real(tester, db.getDebts)).single;
      expect(saved.name, 'Auto');
      expect(saved.monthlyPayment, 100);
      expect(saved.remainingBalance, 300);
      expect(saved.status, DebtStatus.pending);
      expect(find.text('Auto'), findsOneWidget);
      expect(find.textContaining(FormatUtils.money(300)), findsWidgets);
    });

    testWidgets('FLU-07 · HU-20 · HU-21 · un pago parcial y otro por el resto '
        'liquidan la deuda', (tester) async {
      final debt = await real(tester, seedDebt);
      await open(tester, const HomeScreen());
      await tapOn(tester, find.text('Auto'));

      await tapKey(tester, 'debt-pay');
      await type(tester, 'pay-amount', '120.10');
      await tapKey(tester, 'pay-save');
      var saved = (await real(tester, db.getDebts)).single;
      expect(saved.remainingBalance, 179.90);
      expect(saved.status, DebtStatus.pending);

      await tapKey(tester, 'debt-pay');
      await tapKey(tester, 'pay-all');
      await tapKey(tester, 'pay-save');
      saved = (await real(tester, db.getDebts)).single;
      expect(saved.remainingBalance, 0);
      expect(saved.status, DebtStatus.paid);

      final payments = await real(tester, () => db.getDebtPayments(debt.id!));
      expect(
        payments.map((m) => m.amount),
        unorderedEquals([-120.10, -179.90]),
      );
      expect(payments.every((m) => m.isPayment), isTrue);
      expect(await real(tester, upcomingFromDatabase), isEmpty);
    });

    testWidgets('FLU-08 · HU-22 · un monto cero, no numérico o mayor que el '
        'saldo no cambia la base', (tester) async {
      final debt = await real(tester, seedDebt);
      await open(tester, const HomeScreen());
      await tapOn(tester, find.text('Auto'));
      await tapKey(tester, 'debt-pay');

      for (final amount in ['0', 'abc', '300.01']) {
        await type(tester, 'pay-amount', amount);
        await tapKey(tester, 'pay-save');

        expect(find.byKey(const Key('pay-save')), findsOneWidget);
        final stored = (await real(tester, db.getDebts)).single;
        expect(stored.remainingBalance, 300, reason: amount);
        expect(
          await real(tester, () => db.getDebtPayments(debt.id!)),
          isEmpty,
          reason: amount,
        );
      }
    });
  });

  group('Plan de pruebas', () {
    testWidgets('UI-07 · HU-22 · Pago inválido de deuda', (tester) async {
      final debt = await real(tester, seedDebt); // saldo restante 300
      await open(tester, const HomeScreen());
      await tapOn(tester, find.text('Auto'));
      await tapKey(tester, 'debt-pay');

      for (final (amount, message) in [
        ('0', Validators.notPositive),
        ('301', Validators.overBalance),
      ]) {
        await type(tester, 'pay-amount', amount);
        await tapKey(tester, 'pay-save');

        expect(find.text(message), findsOneWidget, reason: amount);
        expect(
          await real(tester, () => db.getDebtPayments(debt.id!)),
          isEmpty,
          reason: amount,
        );
      }
      expect((await real(tester, db.getDebts)).single.remainingBalance, 300);
    });
  });

  group('Compromisos próximos', () {
    test('FLU-09 · HU-23 · lo guardado en SQLite se ordena por días restantes '
        'e identifica lo pagado', () async {
      await seedDebt(name: 'Préstamo', dueInDays: 10);
      final near = await seedDebt(name: 'Moto', dueInDays: 3);
      await debts.pay(near.id!, 100, date: _today());

      final result = await upcomingFromDatabase();

      expect(result.map((u) => u.name), ['Moto', 'Préstamo']);
      expect(result.map((u) => u.daysLeft), [3, 10]);
      expect(result.map((u) => u.isPaid), [true, false]);
    });
  });

  // FLU-10 y FLU-11 encontraron D-09 (#205): al guardar la edición de un
  // pago, el formulario armaba el movimiento sin `type`, `cardId` ni
  // `debtId`. Se corrigió en #206.
  group('Pagos ya registrados', () {
    /// Abre el pago desde Movimientos, cambia solo la nota y guarda.
    Future<Movement> editNote(WidgetTester tester) async {
      await real(tester, movements.load);
      await open(tester, const MovementsScreen());
      await tapOn(tester, find.textContaining('Pago '));
      await type(tester, 'movement-note', 'comprobante 123');
      await tapKey(tester, 'movement-save');
      return (await real(tester, () => db.getMovements())).single;
    }

    testWidgets('FLU-10 · HU-16 · HU-05 · editar la nota de un pago de tarjeta '
        'lo conserva como pago de esa tarjeta', (tester) async {
      final card = await real(tester, seedCard);
      await real(tester, () => cards.pay(card.id!, 120, date: _today()));

      final edited = await editNote(tester);

      expect(edited.note, 'comprobante 123');
      expect((edited.type, edited.cardId), (MovementType.payment, card.id));
    });

    testWidgets('FLU-11 · HU-20 · HU-05 · editar la nota de un pago de deuda '
        'lo conserva como pago de esa deuda', (tester) async {
      final debt = await real(tester, seedDebt);
      await real(tester, () => debts.pay(debt.id!, 120, date: _today()));

      final edited = await editNote(tester);

      expect(edited.note, 'comprobante 123');
      expect((edited.type, edited.debtId), (MovementType.payment, debt.id));
    });
  });
}
