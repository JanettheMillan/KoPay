// S2-05 · Pantalla de Ajustes: moneda e idioma (HU-24, HU-25).
//
// Recorre la app completa con providers en memoria. "Reabrir" monta la
// app otra vez con un SettingsProvider nuevo sobre los mismos ajustes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Guarda los ajustes en un mapa en lugar de SQLite.
class MemorySettingsDb extends DatabaseHelper {
  MemorySettingsDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final Map<String, String> values = Map.of(DatabaseHelper.defaultSettings);
  bool failWrites = false;

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> setSetting(String key, String value) async {
    if (failWrites) throw Exception('disco lleno');
    values[key] = value;
  }
}

void main() {
  late MemorySettingsDb db;

  setUp(() => db = MemorySettingsDb());
  tearDown(() => FormatUtils.configure(currency: 'MXN', language: 'es'));

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider(database: db);
    await settings.load();
    await tester.pumpWidget(
      MultiProvider(
        key: UniqueKey(),
        providers: [
          ChangeNotifierProvider(create: (_) => MovementProvider()),
          ChangeNotifierProvider(create: (_) => IncomeProvider()),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const KopayApp(),
      ),
    );
    await tester.pumpAndSettle();
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

  Finder balance() => find.byKey(const Key('home-balance'));

  testWidgets('UI-SET-01 · HU-24 · Ajustes muestra moneda e idioma actuales', (
    tester,
  ) async {
    await openApp(tester);
    await goTo(tester, 'Ajustes');

    expect(find.byKey(const Key('settings-title')), findsOneWidget);
    expect(find.text(r'$ MXN'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.byKey(const Key('add-button')), findsNothing);
  });

  testWidgets(
    'UI-SET-02 · HU-24 · elegir USD cambia el símbolo en Inicio y se conserva al reabrir',
    (tester) async {
      await openApp(tester);
      expect(tester.widget<Text>(balance()).data!.startsWith(r'$'), isTrue);

      await goTo(tester, 'Ajustes');
      await tapKey(tester, 'settings-currency');
      await tapKey(tester, 'currency-USD');
      expect(find.text(r'US$ USD'), findsOneWidget);
      expect(db.values['currency'], 'USD');

      await goTo(tester, 'Inicio');
      expect(tester.widget<Text>(balance()).data!.startsWith(r'US$'), isTrue);

      // Reabrir: la moneda guardada sigue activa.
      FormatUtils.configure(currency: 'MXN');
      await openApp(tester);
      expect(tester.widget<Text>(balance()).data!.startsWith(r'US$'), isTrue);
    },
  );

  testWidgets(
    'UI-SET-03 · HU-25 · elegir English traduce los textos y se conserva al reabrir',
    (tester) async {
      await openApp(tester);
      await goTo(tester, 'Ajustes');
      await tapKey(tester, 'settings-language');
      await tapKey(tester, 'language-en');

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Currency'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Activity'), findsWidgets);
      expect(db.values['language'], 'en');

      await goTo(tester, 'Home');
      expect(find.text('MONTH BALANCE'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      final month = FormatUtils.monthNamesEn[DateTime.now().month - 1];
      expect(find.textContaining(month), findsWidgets);

      // Reabrir: sigue en inglés.
      FormatUtils.configure(language: 'es');
      await openApp(tester);
      expect(find.text('MONTH BALANCE'), findsOneWidget);

      // Volver a español.
      await goTo(tester, 'Settings');
      await tapKey(tester, 'settings-language');
      await tapKey(tester, 'language-es');
      expect(find.text('Ajustes'), findsWidgets);
      expect(db.values['language'], 'es');
    },
  );

  testWidgets('UI-SET-04 · HU-24 · si no se puede guardar avisa y no cambia', (
    tester,
  ) async {
    await openApp(tester);
    db.failWrites = true;
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-currency');
    await tapKey(tester, 'currency-EUR');

    expect(
      find.text('No se pudo guardar el ajuste. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text(r'$ MXN'), findsOneWidget);
    expect(db.values['currency'], 'MXN');
  });
}
