// S2-13 · Formulario y detalle de tarjeta en la app real (HU-13 a HU-15).
//
// Corre la app con SQLite real a 390 × 844 pt: agrega una tarjeta desde
// Inicio, "reabre" la app para comprobar que se guardó, abre su detalle,
// la edita, cancela y confirma el borrado. Guarda una captura por paso.
//
// ATENCIÓN: borra las tarjetas del dispositivo donde corre.
//
//   flutter test integration_test/s2_13_tarjetas_test.dart -d macos

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
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_13')
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

  testWidgets('S2-13 · Agregar, consultar, editar y eliminar tarjeta', (
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
    await db.delete(DatabaseHelper.cardsTable);

    // 1. Inicio sin tarjetas.
    await openApp(tester);
    await tester.ensureVisible(find.byKey(const Key('cards-empty')));
    await shot(tester, '1-inicio-sin-tarjetas');

    // 2. Formulario vacío.
    await tapKey(tester, 'cards-add');
    await tapKey(tester, 'card-save');
    expect(find.text('Escribe el nombre de la tarjeta'), findsOneWidget);
    await shot(tester, '2-formulario-vacio');

    // 3. Formulario lleno.
    for (final e in {
      'name': 'Oro',
      'bank': 'BBVA',
      'limit': '1000',
      'used': '200',
      'cut-day': '5',
      'payment-day': '25',
      'minimum': '100',
    }.entries) {
      await tester.ensureVisible(find.byKey(Key('card-${e.key}')));
      await tester.enterText(find.byKey(Key('card-${e.key}')), e.value);
    }
    await shot(tester, '3-formulario-lleno');
    await tapKey(tester, 'card-save');
    await waitGone(tester, find.text('Nueva tarjeta'));
    await waitFor(tester, find.text(r'$800.00 disponible'));
    await shot(tester, '4-tarjeta-en-inicio');

    // 4. Reabrir: la tarjeta sigue guardada en SQLite.
    await openApp(tester);
    await waitFor(tester, find.text(r'$800.00 disponible'));
    final id = (await DatabaseHelper.instance.getCards()).single.id;

    // 5. Detalle.
    await tapKey(tester, 'card-row-$id');
    expect(
      tester.widget<Text>(find.byKey(const Key('card-available'))).data,
      r'$800.00',
    );
    await shot(tester, '5-detalle');

    // 6. Editar límite y saldo.
    await tapKey(tester, 'card-edit');
    await tester.enterText(find.byKey(const Key('card-limit')), '1500');
    await tester.enterText(find.byKey(const Key('card-used')), '300');
    await shot(tester, '6-editar');
    await tapKey(tester, 'card-save');
    await waitGone(tester, find.text('Editar tarjeta'));
    await waitFor(tester, find.text(r'$1,200.00'));
    await shot(tester, '7-detalle-editado');
    final edited = (await DatabaseHelper.instance.getCards()).single;
    expect(edited.creditLimit, 1500);
    expect(edited.usedBalance, 300);

    // 7. Eliminar: cancelar conserva, confirmar quita.
    await tapKey(tester, 'card-delete');
    await shot(tester, '8-confirmar-eliminar');
    await tapKey(tester, 'card-delete-cancel');
    expect(await DatabaseHelper.instance.getCards(), hasLength(1));
    await tapKey(tester, 'card-delete');
    await tapKey(tester, 'card-delete-confirm');
    await waitFor(tester, find.byKey(const Key('cards-empty')));
    await shot(tester, '9-eliminada');
    expect(await DatabaseHelper.instance.getCards(), isEmpty);

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
  });
}
