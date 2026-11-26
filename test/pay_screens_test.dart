// S2-15 · Formularios de pago de tarjeta y deuda (HU-16, HU-17, HU-20,
// HU-21, HU-22).
//
// El plan no tiene casos de interfaz para pagos; estos son casos nuevos:
// UT-PAY-xx (validación), DB-PAY-xx (SQLite real con sqflite_ffi) y
// UI-PAY-xx (pantallas con los providers reales sobre una base en
// memoria que aplica las mismas reglas que SQLite).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/card_detail_screen.dart';
import 'package:kopay/screens/debt_detail_screen.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:kopay/utils/validators.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tarjetas, deudas y pagos en memoria, con las reglas de SQLite.
class _MemoryDb extends DatabaseHelper {
  _MemoryDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final List<CardModel> cards = [];
  final List<DebtModel> debts = [];
  final List<Movement> movements = [];
  var _nextId = 1;

  @override
  Future<List<CardModel>> getCards() async => [...cards];

  @override
  Future<List<DebtModel>> getDebts() async => [...debts];

  @override
  Future<DebtModel?> getDebt(int id) async =>
      debts.where((d) => d.id == id).firstOrNull;

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async =>
      [...movements]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async => [];

  @override
  Future<Movement> insertCardPayment({
    required int cardId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final i = cards.indexWhere((c) => c.id == cardId);
    final card = cards[i];
    if ((amount * 100).round() > (card.usedBalance * 100).round()) {
      throw ArgumentError('El pago supera el saldo usado de la tarjeta');
    }
    cards[i] = card.copyWith(usedBalance: card.usedBalance - amount);
    final m = Movement(
      id: _nextId++,
      amount: -amount,
      description: 'Pago ${card.name}',
      category: DatabaseHelper.paymentCategory,
      date: date,
      note: note,
      type: MovementType.payment,
      cardId: cardId,
    );
    movements.add(m);
    return m;
  }

  @override
  Future<Movement> insertDebtPayment({
    required int debtId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    final i = debts.indexWhere((d) => d.id == debtId);
    final debt = debts[i];
    final rest = debt.remainingBalance - amount;
    debts[i] = debt.copyWith(
      remainingBalance: rest,
      status: (rest * 100).round() == 0 ? DebtStatus.paid : debt.status,
    );
    final m = Movement(
      id: _nextId++,
      amount: -amount,
      description: 'Pago ${debt.name}',
      category: DatabaseHelper.paymentCategory,
      date: date,
      note: note,
      type: MovementType.payment,
      debtId: debtId,
    );
    movements.add(m);
    return m;
  }

  @override
  Future<List<Movement>> getCardPayments(int cardId) async =>
      movements.where((m) => m.cardId == cardId).toList().reversed.toList();

  @override
  Future<List<Movement>> getDebtPayments(int debtId) async =>
      movements.where((m) => m.debtId == debtId).toList().reversed.toList();

  @override
  Future<void> cancelPayment(int movementId) async {
    final index = movements.indexWhere((m) => m.id == movementId);
    if (index < 0) {
      throw ArgumentError.value(movementId, 'movementId', 'El pago no existe');
    }
    final payment = movements[index];
    if (payment.cardId != null) {
      final i = cards.indexWhere((c) => c.id == payment.cardId);
      final card = cards[i];
      cards[i] = card.copyWith(
        usedBalance: card.usedBalance + payment.absAmount,
      );
    } else if (payment.debtId != null) {
      final i = debts.indexWhere((d) => d.id == payment.debtId);
      final debt = debts[i];
      final rest = debt.remainingBalance + payment.absAmount;
      debts[i] = debt.copyWith(
        remainingBalance: rest,
        status: (rest * 100).round() == 0
            ? DebtStatus.paid
            : DebtStatus.pending,
      );
    } else {
      throw ArgumentError.value(movementId, 'movementId', 'Pago desligado');
    }
    movements.removeAt(index);
  }
}

class _FixedSettings extends SettingsProvider {
  _FixedSettings(this._language);
  final String _language;

  @override
  String get language => _language;
}

void main() {
  sqfliteFfiInit();

  const oro = CardModel(
    id: 1,
    name: 'Oro',
    bank: 'BBVA',
    creditLimit: 1000,
    usedBalance: 200,
    cutDay: 5,
    paymentDay: 25,
  );
  final auto = DebtModel(
    id: 2,
    name: 'Préstamo auto',
    monthlyPayment: 100,
    remainingBalance: 300,
    dueDate: DateTime(2027, 1, 15),
  );

  group('Validación', () {
    test('UT-PAY-01 · HU-17 · el pago de tarjeta debe ser mayor que cero y no '
        'pasar del saldo usado', () {
      expect(Validators.checkCardPayment(0, 200), Validators.notPositive);
      expect(Validators.checkCardPayment(-5, 200), Validators.notPositive);
      expect(Validators.checkCardPayment(200.01, 200), Validators.overUsed);
      expect(Validators.checkCardPayment(200, 200), isNull);
      // En centavos: 0.1 + 0.2 no supera 0.30 (D-06).
      expect(Validators.checkCardPayment(0.1 + 0.2, 0.30), isNull);
    });

    test('UT-PAY-02 · HU-22 · el pago de deuda no pasa del saldo restante', () {
      expect(Validators.checkDebtPayment(0, 300), Validators.notPositive);
      expect(Validators.checkDebtPayment(300.5, 300), Validators.overBalance);
      expect(Validators.checkDebtPayment(300, 300), isNull);
    });
  });

  group('SQLite', () {
    late Directory tempDir;
    late DatabaseHelper helper;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('kopay_pay_test');
      helper = DatabaseHelper.withFactory(
        databaseFactoryFfi,
        '${tempDir.path}/${DatabaseHelper.fileName}',
      );
    });

    tearDown(() async {
      await helper.close();
      tempDir.deleteSync(recursive: true);
    });

    test('DB-PAY-01 · HU-16 · CardProvider.pay baja el saldo usado y '
        'rechaza montos inválidos sin cambiar nada', () async {
      final card = await helper.insertCard(oro.copyWith(id: null));
      final provider = CardProvider(database: helper);
      await provider.load();

      final pago = await provider.pay(
        card.id!,
        120,
        date: DateTime(2026, 11, 26),
      );
      expect(pago.isPayment, isTrue);
      expect(provider.byId(card.id!)!.usedBalance, 80);
      expect(provider.byId(card.id!)!.available, 920);

      for (final bad in [0.0, -1.0, 80.01]) {
        await expectLater(
          provider.pay(card.id!, bad),
          throwsA(isA<ValidationException>()),
        );
      }
      expect((await helper.getCard(card.id!))!.usedBalance, 80);
      expect(await provider.paymentsOf(card.id!), [pago]);
    });

    test('DB-PAY-02 · HU-16 · borrar la tarjeta conserva sus pagos en '
        'Movimientos, ya sin tarjeta', () async {
      final card = await helper.insertCard(oro.copyWith(id: null));
      final pago = await helper.insertCardPayment(
        cardId: card.id!,
        amount: 50,
        date: DateTime(2026, 11, 26),
      );
      expect(await helper.deleteCard(card.id!), 1);

      expect(await helper.getCard(card.id!), isNull);
      final kept = await helper.getMovement(pago.id!);
      expect(kept, isNotNull);
      expect(kept!.isPayment, isTrue);
      expect(kept.amount, -50);
      expect(kept.cardId, isNull);
    });

    test('DB-PAY-03 · HU-20 · borrar la deuda conserva sus pagos en '
        'Movimientos, ya sin deuda', () async {
      final debt = await helper.insertDebt(auto.copyWith(id: null));
      final pago = await helper.insertDebtPayment(
        debtId: debt.id!,
        amount: 100,
        date: DateTime(2026, 11, 26),
      );
      expect(await helper.deleteDebt(debt.id!), 1);

      final kept = await helper.getMovement(pago.id!);
      expect(kept!.isPayment, isTrue);
      expect(kept.debtId, isNull);
    });
  });

  group('Pantallas', () {
    late _MemoryDb db;
    late CardProvider cards;
    late DebtProvider debts;
    late MovementProvider movements;

    setUp(() async {
      db = _MemoryDb()
        ..cards.add(oro)
        ..debts.add(auto);
      cards = CardProvider(database: db);
      debts = DebtProvider(database: db);
      movements = MovementProvider(database: db);
      await cards.load();
      await debts.load();
      await movements.load();
    });

    Future<void> open(
      WidgetTester tester,
      Widget screen, {
      String language = 'es',
    }) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CardProvider>.value(value: cards),
            ChangeNotifierProvider<DebtProvider>.value(value: debts),
            ChangeNotifierProvider<MovementProvider>.value(value: movements),
            ChangeNotifierProvider<SettingsProvider>.value(
              value: _FixedSettings(language),
            ),
          ],
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }

    Future<void> payWith(WidgetTester tester, String amount) async {
      await tester.enterText(find.byKey(const Key('pay-amount')), amount);
      await tapKey(tester, 'pay-save');
    }

    String textOf(WidgetTester tester, String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    testWidgets('UI-PAY-01 · HU-16 · pagar la tarjeta baja el saldo, sube el '
        'disponible y el pago aparece en Movimientos', (tester) async {
      await open(tester, const CardDetailScreen(cardId: 1));
      await tapKey(tester, 'card-pay');
      expect(find.text(AppStrings.es.payCard), findsOneWidget);
      expect(textOf(tester, 'pay-balance'), FormatUtils.money(200));

      await payWith(tester, '120');

      expect(find.text(AppStrings.es.payCard), findsNothing);
      expect(textOf(tester, 'card-used-value'), FormatUtils.money(80));
      expect(textOf(tester, 'card-available'), FormatUtils.money(920));
      expect(find.byKey(const Key('payment-row-0')), findsOneWidget);
      expect(movements.movements.single.isPayment, isTrue);
      expect(movements.movements.single.amount, -120);
    });

    testWidgets('UI-PAY-02 · HU-17 · un monto vacío, cero, no numérico o mayor '
        'que el saldo usado no se guarda', (tester) async {
      await open(tester, const CardDetailScreen(cardId: 1));
      await tapKey(tester, 'card-pay');

      for (final entry in {
        '': Validators.emptyAmount,
        '0': Validators.notPositive,
        'abc': Validators.notANumber,
        '200.01': Validators.overUsed,
      }.entries) {
        await payWith(tester, entry.key);
        expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      }
      expect(db.movements, isEmpty);
      expect(db.cards.single.usedBalance, 200);
    });

    testWidgets('UI-PAY-03 · HU-20 · HU-21 · "Pagar todo" liquida la deuda y '
        'el pago ya no se puede repetir', (tester) async {
      await open(tester, const DebtDetailScreen(debtId: 2));
      await tapKey(tester, 'debt-pay');
      await tapKey(tester, 'pay-all');
      await tapKey(tester, 'pay-save');

      expect(textOf(tester, 'debt-remaining-value'), FormatUtils.money(0));
      expect(textOf(tester, 'debt-status-value'), AppStrings.es.debtPaid);
      expect(db.debts.single.status, DebtStatus.paid);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('debt-pay')))
            .onPressed,
        isNull,
      );
      expect(find.text(AppStrings.es.nothingToPay), findsOneWidget);
      expect(movements.movements.single.debtId, 2);
    });

    testWidgets('UI-PAY-04 · HU-22 · un pago mayor que el saldo restante no se '
        'guarda', (tester) async {
      await open(tester, const DebtDetailScreen(debtId: 2));
      await tapKey(tester, 'debt-pay');
      await payWith(tester, '300.01');

      expect(find.text(Validators.overBalance), findsOneWidget);
      expect(db.debts.single.remainingBalance, 300);
      expect(db.movements, isEmpty);
    });

    testWidgets('UI-PAY-05 · HU-15 · al borrar avisa que los pagos se '
        'conservan', (tester) async {
      await open(tester, const CardDetailScreen(cardId: 1));
      await tapKey(tester, 'card-delete');
      expect(find.textContaining(AppStrings.es.paymentsKept), findsOneWidget);
      await tapKey(tester, 'card-delete-cancel');

      await open(tester, const DebtDetailScreen(debtId: 2));
      await tapKey(tester, 'debt-delete');
      expect(find.textContaining(AppStrings.es.paymentsKept), findsOneWidget);
    });

    testWidgets('UI-PAY-06 · HU-25 · el formulario de pago cambia a inglés', (
      tester,
    ) async {
      await open(tester, const DebtDetailScreen(debtId: 2), language: 'en');
      expect(find.text('Record payment'), findsOneWidget);
      expect(find.text('PAYMENTS'), findsOneWidget);
      await tapKey(tester, 'debt-pay');
      expect(find.text('Pay debt'), findsOneWidget);
      expect(find.text('Pay all'), findsOneWidget);
    });

    testWidgets('UI-D10-01 · HU-16 · anular un pago de tarjeta devuelve el '
        'saldo usado y lo quita de Movimientos', (tester) async {
      await db.insertCardPayment(
        cardId: 1,
        amount: 50,
        date: DateTime(2026, 11, 20),
      );
      await cards.load();
      await movements.load();
      await open(tester, const CardDetailScreen(cardId: 1));
      expect(textOf(tester, 'card-used-value'), FormatUtils.money(150));

      await tapKey(tester, 'payment-cancel-0');
      expect(find.text(AppStrings.es.cancelPaymentTitle), findsOneWidget);
      expect(find.text(AppStrings.es.cancelPaymentBody), findsOneWidget);
      await tapKey(tester, 'cancel-payment-confirm');

      expect(textOf(tester, 'card-used-value'), FormatUtils.money(200));
      expect(textOf(tester, 'card-available'), FormatUtils.money(800));
      expect(find.byKey(const Key('payment-row-0')), findsNothing);
      expect(find.byKey(const Key('payments-empty')), findsOneWidget);
      expect(movements.movements, isEmpty);
      expect(find.text(AppStrings.es.paymentCanceled), findsOneWidget);
    });

    testWidgets('UI-D10-02 · HU-16 · cancelar la confirmación no cambia el '
        'pago ni el saldo', (tester) async {
      await db.insertCardPayment(
        cardId: 1,
        amount: 50,
        date: DateTime(2026, 11, 20),
      );
      await cards.load();
      await movements.load();
      await open(tester, const CardDetailScreen(cardId: 1));

      await tapKey(tester, 'payment-cancel-0');
      await tapKey(tester, 'cancel-payment-dismiss');

      expect(textOf(tester, 'card-used-value'), FormatUtils.money(150));
      expect(find.byKey(const Key('payment-row-0')), findsOneWidget);
      expect(movements.movements.single.amount, -50);
      expect(db.cards.single.usedBalance, 150);
    });

    testWidgets('UI-D10-03 · HU-20 · HU-21 · anular el pago que liquidó la '
        'deuda la deja pendiente y devuelve el saldo', (tester) async {
      await db.insertDebtPayment(
        debtId: 2,
        amount: 300,
        date: DateTime(2026, 11, 20),
      );
      await debts.load();
      await movements.load();
      await open(tester, const DebtDetailScreen(debtId: 2));
      expect(textOf(tester, 'debt-status-value'), AppStrings.es.debtPaid);

      await tapKey(tester, 'payment-cancel-0');
      await tapKey(tester, 'cancel-payment-confirm');

      expect(textOf(tester, 'debt-remaining-value'), FormatUtils.money(300));
      expect(textOf(tester, 'debt-status-value'), AppStrings.es.debtPending);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('debt-pay')))
            .onPressed,
        isNotNull,
      );
      expect(movements.movements, isEmpty);
    });

    testWidgets('UI-D10-04 · HU-25 · la confirmación de anular cambia a '
        'inglés', (tester) async {
      await db.insertCardPayment(
        cardId: 1,
        amount: 50,
        date: DateTime(2026, 11, 20),
      );
      await cards.load();
      await open(tester, const CardDetailScreen(cardId: 1), language: 'en');

      await tapKey(tester, 'payment-cancel-0');
      expect(find.text('Void this payment?'), findsOneWidget);
      expect(find.text('Void payment'), findsOneWidget);
    });
  });
}
