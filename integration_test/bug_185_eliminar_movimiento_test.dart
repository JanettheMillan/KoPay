// #185 · Eliminar un movimiento desde la app real (HU-06).
//
// Corre la app con SQLite real a 390 × 844 pt: abre un gasto desde
// Movimientos, cancela el borrado, lo confirma y comprueba que Inicio se
// actualiza. Guarda una captura por paso.
//
// ATENCIÓN: borra el movimiento de prueba "Prueba #185" que crea.
//
//   flutter test integration_test/bug_185_eliminar_movimiento_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/movement_model.dart';
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
  final outDir = Directory('${Directory.systemTemp.path}/kopay_185')
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

  testWidgets('#185 · Eliminar un movimiento con confirmación', (tester) async {
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
    await db.delete(
      DatabaseHelper.movementsTable,
      where: 'description = ?',
      whereArgs: ['Prueba #185'],
    );
    final now = DateTime.now();
    final saved = await helper.insertMovement(
      Movement(
        amount: -75,
        description: 'Prueba #185',
        category: 'Comida',
        date: DateTime(now.year, now.month, now.day),
      ),
    );

    await openApp(tester);
    await goTo(tester, 'Movimientos');
    await tapKey(tester, 'history-movement-${saved.id}');
    await tester.ensureVisible(find.byKey(const Key('movement-delete')));
    await shot(tester, '1-editar-con-eliminar');

    await tapKey(tester, 'movement-delete');
    await shot(tester, '2-confirmar');
    await tapKey(tester, 'movement-delete-cancel');
    expect(await helper.getMovement(saved.id!), isNotNull);

    await tapKey(tester, 'movement-delete');
    await tapKey(tester, 'movement-delete-confirm');
    await waitGone(tester, find.text('Editar movimiento'));
    expect(find.text('Prueba #185'), findsNothing);
    await shot(tester, '3-eliminado');
    expect(await helper.getMovement(saved.id!), isNull);

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
