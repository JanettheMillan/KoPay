// S2-19 · Maqueta de la vista de contador en la app real (HU-39, HU-40,
// HU-42).
//
// Corre la app a 390 × 844 pt: entra desde Ajustes, elige un cliente de
// ejemplo, cambia el periodo, abre el historial y repite en inglés.
// Guarda una captura por paso y registra cualquier desborde. No escribe
// registros; deja el idioma en español al terminar.
//
//   flutter test integration_test/s2_19_maqueta_contador_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/card_provider.dart';
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
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_19')
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

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> openApp(WidgetTester tester) async {
    FormatUtils.configure(currency: 'MXN', language: 'es');
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

  testWidgets('S2-19 · Maqueta de contador con datos de ejemplo', (
    tester,
  ) async {
    final db = DatabaseHelper.instance;
    await db.setSetting(SettingsProvider.languageKey, 'es');
    addTearDown(() => db.setSetting(SettingsProvider.languageKey, 'es'));

    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
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

    await openApp(tester);

    // 1. Entrada en Ajustes.
    await goTo(tester, 'Ajustes');
    await tester.ensureVisible(
      find.byKey(const Key('settings-accountant-preview')),
    );
    await shot(tester, '1-ajustes-entrada');

    // 2. Clientes autorizados con el aviso de ejemplo.
    await tapKey(tester, 'settings-accountant-preview');
    expect(find.byKey(const Key('sample-data-banner')), findsOneWidget);
    await shot(tester, '2-clientes');

    // 3. Resumen del mes actual.
    await tapKey(tester, 'client-ejemplo-1');
    expect(find.byKey(const Key('summary-balance')), findsOneWidget);
    await shot(tester, '3-resumen-mes-actual');

    // 4. Periodo anterior.
    await tapKey(tester, 'summary-prev-month');
    await shot(tester, '4-resumen-mes-anterior');

    // 5. Historial de ese periodo, solo lectura.
    await tapKey(tester, 'summary-view-movements');
    expect(find.byKey(const Key('history-read-only')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await shot(tester, '5-historial');

    // 6. Lo mismo en inglés.
    await back(tester);
    await back(tester);
    await back(tester);
    await tapKey(tester, 'settings-language');
    await tapKey(tester, 'language-en');
    await tapKey(tester, 'settings-accountant-preview');
    expect(find.text('Authorized clients'), findsOneWidget);
    await shot(tester, '6-clientes-en');
    await tapKey(tester, 'client-ejemplo-2');
    await tapKey(tester, 'summary-view-movements');
    expect(find.text('Activity'), findsOneWidget);
    await shot(tester, '7-historial-en');

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
