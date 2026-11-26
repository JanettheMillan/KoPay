// S2-14 · Formulario y consulta de deuda en la app real (HU-19, HU-21).
//
// Corre la app con SQLite real a 390 × 844 pt: agrega una deuda desde
// Inicio, "reabre" la app para comprobar que se guardó, abre su detalle,
// la edita hasta dejarla pagada y la elimina. Guarda una captura por paso.
//
// ATENCIÓN: borra las deudas del dispositivo donde corre.
//
//   flutter test integration_test/s2_14_deudas_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
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
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_14')
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

  testWidgets('S2-14 · Registrar, consultar, editar y eliminar deuda', (
    tester,
  ) async {
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

    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.debtsTable);

    // 1. Inicio sin deudas.
    await openApp(tester);
    await tester.ensureVisible(find.byKey(const Key('debts-empty')));
    await shot(tester, '1-inicio-sin-deudas');

    // 2. Formulario vacío.
    await tapKey(tester, 'debts-add');
    await tapKey(tester, 'debt-save');
    expect(find.text('Escribe el nombre de la deuda'), findsOneWidget);
    await shot(tester, '2-formulario-vacio');

    // 3. Formulario lleno.
    for (final e in {
      'name': 'Préstamo auto',
      'monthly': '2500',
      'remaining': '30000',
    }.entries) {
      await tester.ensureVisible(find.byKey(Key('debt-${e.key}')));
      await tester.enterText(find.byKey(Key('debt-${e.key}')), e.value);
    }
    await shot(tester, '3-formulario-lleno');
    await tapKey(tester, 'debt-save');
    await waitGone(tester, find.text('Nueva deuda'));
    await waitFor(tester, find.text(r'$30,000.00'));
    await tester.ensureVisible(find.text(r'$30,000.00'));
    await shot(tester, '4-deuda-en-inicio');

    // 4. Reabrir: la deuda sigue guardada en SQLite.
    await openApp(tester);
    await waitFor(tester, find.text(r'$30,000.00'));
    final id = (await DatabaseHelper.instance.getDebts()).single.id;

    // 5. Detalle.
    await tapKey(tester, 'debt-row-$id');
    expect(
      tester.widget<Text>(find.byKey(const Key('debt-status-value'))).data,
      'Pendiente',
    );
    await shot(tester, '5-detalle');

    // 6. Editar: saldo en cero, queda pagada (HU-21).
    await tapKey(tester, 'debt-edit');
    await tester.enterText(find.byKey(const Key('debt-remaining')), '0');
    await shot(tester, '6-editar');
    await tapKey(tester, 'debt-save');
    await waitGone(tester, find.text('Editar deuda'));
    await waitFor(tester, find.text('Pagada'));
    await shot(tester, '7-detalle-pagada');
    final edited = (await DatabaseHelper.instance.getDebts()).single;
    expect(edited.remainingBalance, 0);
    expect(edited.isPaid, isTrue);

    // 7. Eliminar: cancelar conserva, confirmar quita.
    await tapKey(tester, 'debt-delete');
    await shot(tester, '8-confirmar-eliminar');
    await tapKey(tester, 'debt-delete-cancel');
    expect(await DatabaseHelper.instance.getDebts(), hasLength(1));
    await tapKey(tester, 'debt-delete');
    await tapKey(tester, 'debt-delete-confirm');
    await waitFor(tester, find.byKey(const Key('debts-empty')));
    await shot(tester, '9-eliminada');
    expect(await DatabaseHelper.instance.getDebts(), isEmpty);

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
