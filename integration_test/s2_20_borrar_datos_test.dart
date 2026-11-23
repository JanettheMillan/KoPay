// S2-20 · Borrar datos locales en la app real (HU-28).
//
// Corre la app con SQLite real: registra un gasto y un ingreso, abre
// Ajustes → Borrar datos, cancela (BOR-01), confirma (BOR-02), "reabre"
// la app y comprueba que Movimientos sigue vacío y la moneda se conserva.
// Guarda una captura por paso.
//
// ATENCIÓN: borra los movimientos e ingresos del dispositivo donde corre.
// Úsala en un emulador o en un teléfono de pruebas.
//
//   flutter test integration_test/s2_20_borrar_datos_test.dart -d <dispositivo>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
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
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_20')
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

  testWidgets('BOR-01 · BOR-02 · HU-28 · borrar datos en la app real', (
    tester,
  ) async {
    final db = DatabaseHelper.instance;
    FormatUtils.configure(currency: 'MXN', language: 'es');
    await db.setSetting('currency', 'MXN');
    await db.setSetting('language', 'es');
    final hoy = DateTime.now();
    final gasto = await db.insertMovement(
      Movement(
        amount: -250.5,
        description: 'Súper',
        category: 'Comida',
        date: hoy,
      ),
    );
    final ingreso = await db.insertIncome(
      Income(name: 'Quincena', amount: 12000, date: hoy),
    );

    await openApp(tester);
    await goTo(tester, 'Movimientos');
    expect(find.byKey(Key('history-movement-${gasto.id}')), findsOneWidget);
    expect(find.byKey(Key('history-income-${ingreso.id}')), findsOneWidget);
    await shot(tester, '1-movimientos-con-datos');

    // BOR-01: cancelar conserva.
    await goTo(tester, 'Ajustes');
    await shot(tester, '2-ajustes');
    await tapKey(tester, 'settings-delete-data');
    await shot(tester, '3-confirmacion');
    await tapKey(tester, 'delete-data-cancel');
    expect(await db.getMovements(), isNotEmpty);
    expect(await db.getIncomes(), isNotEmpty);

    // BOR-02: confirmar borra.
    await tapKey(tester, 'settings-delete-data');
    await tapKey(tester, 'delete-data-confirm');
    expect(find.text('Datos borrados'), findsOneWidget);
    await shot(tester, '4-datos-borrados');

    await goTo(tester, 'Movimientos');
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    await shot(tester, '5-movimientos-vacio');

    // Al reabrir sigue vacío y los ajustes no cambiaron.
    await openApp(tester);
    await goTo(tester, 'Movimientos');
    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(await db.getMovements(), isEmpty);
    expect(await db.getIncomes(), isEmpty);
    expect(await db.getSetting('currency'), 'MXN');
    expect(await db.getSetting('categories'), isNotNull);
    await shot(tester, '6-reabierta-vacia');

    expect(tester.takeException(), isNull);
  });
}
