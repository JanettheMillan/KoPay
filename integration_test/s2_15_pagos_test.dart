// S2-15 · Pagos de tarjeta y deuda en la app real (HU-16, HU-17, HU-20,
// HU-21, HU-22).
//
// Corre la app con SQLite real a 390 × 844 pt: paga una tarjeta, prueba un
// monto mayor al saldo, liquida una deuda con "Pagar todo" y comprueba
// que los dos pagos aparecen en Movimientos. Guarda una captura por paso.
//
// ATENCIÓN: borra tarjetas, deudas y pagos del dispositivo donde corre.
//
//   flutter test integration_test/s2_15_pagos_test.dart -d macos

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
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_15')
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

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  Future<void> waitGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
  }

  /// Monta la app con providers nuevos, como al abrirla otra vez.
  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: RepaintBoundary(
          key: boundary,
          child: MultiProvider(
            providers: [
              Provider<DatabaseHelper>.value(value: DatabaseHelper.instance),
              ChangeNotifierProvider(create: (_) => MovementProvider()..load()),
              ChangeNotifierProvider(create: (_) => IncomeProvider()..load()),
              ChangeNotifierProvider(create: (_) => CardProvider()..load()),
              ChangeNotifierProvider(create: (_) => DebtProvider()..load()),
              ChangeNotifierProvider(create: (_) => CategoryProvider()..load()),
              ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
            ],
            child: const KopayApp(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('S2-15 · Pagar tarjeta y deuda', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
    tester.view.devicePixelRatio = 3;
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

    final helper = DatabaseHelper.instance;
    final db = await helper.database;
    await db.delete(DatabaseHelper.movementsTable, where: "type = 'payment'");
    await db.delete(DatabaseHelper.cardsTable);
    await db.delete(DatabaseHelper.debtsTable);
    final card = await helper.insertCard(
      const CardModel(
        name: 'Oro',
        bank: 'BBVA',
        creditLimit: 1000,
        usedBalance: 200,
        cutDay: 5,
        paymentDay: 25,
      ),
    );
    final now = DateTime.now();
    final debt = await helper.insertDebt(
      DebtModel(
        name: 'Préstamo auto',
        monthlyPayment: 100,
        remainingBalance: 300,
        dueDate: DateTime(now.year, now.month + 1, 15),
      ),
    );

    await openApp(tester);

    // 1. Detalle de tarjeta con su botón de pago.
    await tapKey(tester, 'card-row-${card.id}');
    await shot(tester, '1-tarjeta-detalle');

    // 2. Monto mayor al saldo usado: no se guarda (HU-17).
    await tapKey(tester, 'card-pay');
    await tester.enterText(find.byKey(const Key('pay-amount')), '250');
    await tapKey(tester, 'pay-save');
    expect(
      find.text('El pago no puede ser mayor que el saldo usado'),
      findsOneWidget,
    );
    await shot(tester, '2-pago-mayor-al-saldo');

    // 3. Pago válido (HU-16).
    await tester.enterText(find.byKey(const Key('pay-amount')), '120');
    await tester.enterText(find.byKey(const Key('pay-note')), 'Quincena');
    await shot(tester, '3-pago-tarjeta');
    await tapKey(tester, 'pay-save');
    await waitGone(tester, find.text('Pagar tarjeta'));
    await waitFor(tester, find.byKey(const Key('payment-row-0')));
    await shot(tester, '4-tarjeta-pagada');
    expect((await helper.getCard(card.id!))!.usedBalance, 80);

    // 4. Deuda: "Pagar todo" la liquida (HU-20, HU-21).
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapKey(tester, 'debt-row-${debt.id}');
    await tapKey(tester, 'debt-pay');
    await tapKey(tester, 'pay-all');
    await shot(tester, '5-pagar-todo');
    await tapKey(tester, 'pay-save');
    await waitFor(tester, find.text('Pagada'));
    await shot(tester, '6-deuda-pagada');
    expect((await helper.getDebt(debt.id!))!.isPaid, isTrue);

    // 5. Los dos pagos aparecen en Movimientos.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await goTo(tester, 'Movimientos');
    await waitFor(tester, find.text('Pago Oro'));
    expect(find.text('Pago Préstamo auto'), findsOneWidget);
    await shot(tester, '7-movimientos');

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
