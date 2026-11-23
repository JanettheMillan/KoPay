// S2-05 · Ajustes de moneda e idioma en la app real (HU-24, HU-25).
//
// Corre la app con SQLite real a 390 × 844 pt: cambia la moneda a USD y
// el idioma a inglés, "reabre" la app (providers nuevos sobre la misma
// base) y comprueba que ambos se conservan. Deja la base en MXN y
// español al terminar. Guarda una captura por paso.
//
//   flutter test integration_test/s2_05_moneda_idioma_test.dart -d <dispositivo>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_05')
    ..createSync(recursive: true);

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

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  /// Monta la app con providers nuevos, como al abrirla otra vez.
  Future<void> openApp(WidgetTester tester) async {
    FormatUtils.configure(currency: 'MXN', language: 'es');
    await tester.pumpWidget(
      RepaintBoundary(
        key: UniqueKey(),
        child: RepaintBoundary(
          key: boundary,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => MovementProvider()..load()),
              ChangeNotifierProvider(create: (_) => IncomeProvider()..load()),
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

  String balance(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('home-balance'))).data!;

  testWidgets('INT-SET · HU-24 · HU-25 · moneda e idioma en la app real', (
    tester,
  ) async {
    final db = DatabaseHelper.instance;
    await db.setSetting(SettingsProvider.currencyKey, 'MXN');
    await db.setSetting(SettingsProvider.languageKey, 'es');
    addTearDown(() async {
      await db.setSetting(SettingsProvider.currencyKey, 'MXN');
      await db.setSetting(SettingsProvider.languageKey, 'es');
    });

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await openApp(tester);

    // 1. Inicio en MXN y español.
    expect(balance(tester).startsWith(r'$'), isTrue);
    await shot(tester, '1-inicio-mxn');

    // 2. Ajustes con los valores actuales.
    await goTo(tester, 'Ajustes');
    expect(find.text(r'$ MXN'), findsOneWidget);
    await shot(tester, '2-ajustes');

    // 3. Elegir USD.
    await tapKey(tester, 'settings-currency');
    await shot(tester, '3-selector-moneda');
    await tapKey(tester, 'currency-USD');
    expect(find.text(r'US$ USD'), findsOneWidget);

    // 4. Elegir inglés.
    await tapKey(tester, 'settings-language');
    await shot(tester, '4-selector-idioma');
    await tapKey(tester, 'language-en');
    expect(find.text('Currency'), findsOneWidget);
    await shot(tester, '5-ajustes-en');

    // 5. Inicio en USD e inglés.
    await goTo(tester, 'Home');
    expect(balance(tester).startsWith(r'US$'), isTrue);
    expect(find.text('MONTH BALANCE'), findsOneWidget);
    await shot(tester, '6-inicio-usd-en');

    // 6. Reabrir: se conservan.
    await openApp(tester);
    expect(balance(tester).startsWith(r'US$'), isTrue);
    expect(find.text('MONTH BALANCE'), findsOneWidget);
    await shot(tester, '7-tras-reabrir');
  });
}
