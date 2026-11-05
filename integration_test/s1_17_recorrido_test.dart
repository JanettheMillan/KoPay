// S1-17 · Recorrido en dispositivo (sección 8.2 B del plan de pruebas).
//
// Corre la app real en un dispositivo, con SQLite real, a 390 × 844 pt,
// y guarda una captura por paso. Se ejecuta en dos corridas:
//
//   flutter test integration_test/s1_17_recorrido_test.dart -d macos \
//     --dart-define=FASE=A      # pasos 1 a 7, empieza con la base vacía
//   flutter test integration_test/s1_17_recorrido_test.dart -d macos \
//     --dart-define=FASE=B      # paso 8: proceso nuevo, lee lo guardado
//
// Las capturas quedan en la carpeta temporal del dispositivo; la ruta se
// imprime al final de cada corrida.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:provider/provider.dart';

const fase = String.fromEnvironment('FASE', defaultValue: 'A');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // En escritorio, la entrada de texto del sistema reescribe lo que pone
  // enterText; se usa la entrada simulada de Flutter.
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s1_17')
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

  Future<void> startApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
    tester.view.devicePixelRatio = 3;

    // Registra desbordes en lugar de detener el recorrido (OBS-01).
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

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MovementProvider()..load()),
            ChangeNotifierProvider(create: (_) => IncomeProvider()..load()),
          ],
          child: const KopayApp(),
        ),
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

  /// Espera a que se cierre una hoja después de guardar en SQLite.
  Future<void> waitGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    if (finder.evaluate().isNotEmpty) {
      // ignore: avoid_print
      print('PANTALLA=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList()}');
    }
    expect(finder, findsNothing);
  }

  /// Espera a que termine una escritura en SQLite.
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  if (fase == 'A') {
    testWidgets('Recorrido A · pasos 1 a 7', (tester) async {
      // Instalación limpia: se vacían movimientos e ingresos.
      final db = await DatabaseHelper.instance.database;
      await db.delete(DatabaseHelper.movementsTable);
      await db.delete(DatabaseHelper.incomesTable);

      // Paso 1 · Abrir la app.
      await startApp(tester);
      expect(find.byKey(const Key('home-balance')), findsOneWidget);
      await shot(tester, 'paso1-inicio');

      // Paso 2 · Movimientos y Ajustes.
      await goTo(tester, 'Movimientos');
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      await shot(tester, 'paso2a-movimientos-vacio');
      await goTo(tester, 'Ajustes');
      expect(find.byKey(const Key('add-button')), findsNothing);
      await shot(tester, 'paso2b-ajustes');
      await goTo(tester, 'Movimientos');

      // Paso 3 · Gasto vacío.
      await tapKey(tester, 'add-button');
      await shot(tester, 'paso3a-menu-agregar');
      await tapKey(tester, 'add-movement');
      await tapKey(tester, 'movement-save');
      expect(find.text('Escribe un monto'), findsOneWidget);
      expect(find.text('Escribe una descripción'), findsOneWidget);
      expect(find.text('Elige una categoría'), findsOneWidget);
      await shot(tester, 'paso3b-gasto-vacio');

      // Paso 4 · Monto cero.
      await tester.enterText(find.byKey(const Key('movement-amount')), '0');
      await tapKey(tester, 'movement-save');
      expect(find.text('El monto debe ser mayor que cero'), findsOneWidget);
      await shot(tester, 'paso4-monto-cero');

      // Paso 5 · Gasto válido.
      await tester.enterText(find.byKey(const Key('movement-amount')), '50');
      await tester.enterText(
        find.byKey(const Key('movement-description')),
        'Café',
      );
      await tapKey(tester, 'movement-category');
      await tapKey(tester, 'category-Comida');
      await shot(tester, 'paso5a-gasto-lleno');
      await tapKey(tester, 'movement-save');
      await waitGone(tester, find.text('Nuevo gasto'));
      expect(find.text(r'−$50.00'), findsOneWidget);
      await shot(tester, 'paso5b-gasto-guardado');

      // Paso 6 · Ingreso vacío.
      await tapKey(tester, 'add-button');
      await tapKey(tester, 'add-income');
      await tapKey(tester, 'income-save');
      expect(find.text('Escribe el nombre del ingreso'), findsOneWidget);
      expect(find.text('Escribe un monto'), findsOneWidget);
      await shot(tester, 'paso6-ingreso-vacio');

      // Paso 7 · Ingreso válido.
      await tester.enterText(find.byKey(const Key('income-name')), 'Nómina');
      await tester.enterText(find.byKey(const Key('income-amount')), '500');
      await tapKey(tester, 'income-save');
      await waitGone(tester, find.text('Nuevo ingreso'));
      expect(find.text(r'+$500.00'), findsOneWidget);
      await shot(tester, 'paso7-ingreso-guardado');

      // Resumen de Inicio después de guardar (dato para S1-18).
      await goTo(tester, 'Inicio');
      await shot(tester, 'paso7b-inicio-despues');

      // ignore: avoid_print
      print(
        'OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}',
      );
      // ignore: avoid_print
      print('CAPTURAS=${outDir.path}');
    });
  } else {
    testWidgets('Recorrido B · paso 8, datos al reabrir', (tester) async {
      await startApp(tester);
      await goTo(tester, 'Movimientos');
      await waitFor(tester, find.text('Nómina'));
      expect(find.text('Café'), findsOneWidget);
      expect(find.text(r'−$50.00'), findsOneWidget);
      expect(find.text(r'+$500.00'), findsOneWidget);
      await shot(tester, 'paso8-reabrir');

      // ignore: avoid_print
      print('CAPTURAS=${outDir.path}');
    });
  }
}
