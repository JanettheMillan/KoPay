// D-10 · Anular un pago desde el detalle de su tarjeta o deuda (#207,
// HU-16, HU-06).
//
// Corre a 390 × 844 pt con el tema de KoPay y la base real del teléfono
// (sqflite). Borra los datos financieros, registra un pago de tarjeta y uno
// de deuda, anula los dos desde la lista **Pagos** y comprueba que el saldo
// vuelve a como estaba. Guarda una captura por paso y falla si hay un
// desborde.
//
//   flutter test integration_test/d_10_anular_pago_test.dart -d emulator-5554

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/card_detail_screen.dart';
import 'package:kopay/screens/debt_detail_screen.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_d10')
    ..createSync(recursive: true);
  final overflows = <String>[];

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${outDir.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('D-10 · HU-16 · HU-06 · Anular un pago de tarjeta y uno de '
      'deuda devuelve el saldo', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        overflows.add(text.split('\n').first);
      } else {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);

    // Base real del teléfono (sqflite); se vacía para partir de cero.
    final db = DatabaseHelper.instance;
    await db.deleteFinancialData();
    final card = await db.insertCard(
      const CardModel(
        name: 'Oro',
        bank: 'BBVA',
        creditLimit: 1000,
        usedBalance: 200,
        cutDay: 5,
        paymentDay: 25,
      ),
    );
    await db.insertCardPayment(
      cardId: card.id!,
      amount: 50,
      date: DateTime(2026, 11, 20),
      note: 'Quincena',
    );
    final debt = await db.insertDebt(
      DebtModel(
        name: 'Préstamo auto',
        monthlyPayment: 100,
        remainingBalance: 300,
        dueDate: DateTime(2027, 1, 15),
      ),
    );
    await db.insertDebtPayment(
      debtId: debt.id!,
      amount: 300,
      date: DateTime(2026, 11, 20),
    );

    final cards = CardProvider(database: db);
    final debts = DebtProvider(database: db);
    final movements = MovementProvider(database: db);
    final settings = SettingsProvider(database: db);
    await cards.load();
    await debts.load();
    await movements.load();
    await settings.load();

    Future<void> show(Widget screen) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider<CardProvider>.value(value: cards),
              ChangeNotifierProvider<DebtProvider>.value(value: debts),
              ChangeNotifierProvider<MovementProvider>.value(value: movements),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildKopayTheme(),
              home: screen,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String textOf(String key) =>
        tester.widget<Text>(find.byKey(Key(key))).data!;

    // Tarjeta: el pago de 50 dejó el saldo usado en 150.
    await show(CardDetailScreen(cardId: card.id!));
    expect(textOf('card-used-value'), FormatUtils.money(150));
    await shot(tester, '1-pago-en-tarjeta');

    await tap(tester, 'payment-cancel-0');
    expect(find.text(AppStrings.es.cancelPaymentTitle), findsOneWidget);
    expect(find.text(AppStrings.es.cancelPaymentBody), findsOneWidget);
    await shot(tester, '2-confirmar-anular');

    await tap(tester, 'cancel-payment-confirm');
    expect(textOf('card-used-value'), FormatUtils.money(200));
    expect(find.byKey(const Key('payments-empty')), findsOneWidget);
    expect(movements.movements.where((m) => m.cardId != null), isEmpty);
    await shot(tester, '3-saldo-devuelto');

    // Deuda: el pago de 300 la dejó pagada.
    await show(DebtDetailScreen(debtId: debt.id!));
    expect(textOf('debt-status-value'), AppStrings.es.debtPaid);
    await shot(tester, '4-deuda-pagada');

    await tap(tester, 'payment-cancel-0');
    await tap(tester, 'cancel-payment-confirm');
    expect(textOf('debt-remaining-value'), FormatUtils.money(300));
    expect(textOf('debt-status-value'), AppStrings.es.debtPending);
    expect(debts.byId(debt.id!)!.remainingBalance, 300);
    await shot(tester, '5-deuda-pendiente');

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
