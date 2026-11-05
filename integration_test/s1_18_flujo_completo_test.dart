// S1-18 · Flujo completo de gasto e ingreso hasta el resumen (INT-01).
//
// Corre la app real con SQLite real a 390 × 844 pt, guarda un gasto de 50
// y un ingreso de 500 con la base vacía, y compara Movimientos e Inicio
// contra los importes conocidos. Guarda una captura por paso.
//
//   flutter test integration_test/s1_18_flujo_completo_test.dart -d macos
//
// Resultado registrado en docs/plan-de-pruebas.md, sección 8.3.

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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s1_18')
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

  Future<void> waitGone(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 50 && finder.evaluate().isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
  }

  /// Lee los totales visibles en Inicio: el texto que sigue a cada
  /// etiqueta y el balance (key `home-balance` más sus decimales).
  Map<String, String> readSummary(WidgetTester tester) {
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    String after(String label) => texts[texts.indexOf(label) + 1];
    final balanceMain = tester
        .widget<Text>(find.byKey(const Key('home-balance')))
        .data!;
    final balanceIndex = texts.indexOf(balanceMain);
    return {
      'balance': '$balanceMain${texts[balanceIndex + 1]}',
      'ingresos': after('Ingresos'),
      'gastos': after('Gastos'),
    };
  }

  testWidgets('INT-01 · Gasto e ingreso hasta el resumen', (tester) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.movementsTable);
    await db.delete(DatabaseHelper.incomesTable);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
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

    // 1. Saldos iniciales con la base vacía.
    final before = readSummary(tester);
    await shot(tester, '1-inicio-antes');

    // 2. Gasto "Prueba café" de 50.
    await tapKey(tester, 'add-button');
    await tapKey(tester, 'add-movement');
    await tester.enterText(find.byKey(const Key('movement-amount')), '50');
    await tester.enterText(
      find.byKey(const Key('movement-description')),
      'Prueba café',
    );
    await tapKey(tester, 'movement-category');
    await tapKey(tester, 'category-Comida');
    await tapKey(tester, 'movement-save');
    await waitGone(tester, find.text('Nuevo gasto'));
    await shot(tester, '2-gasto-guardado');

    // 3. Ingreso "Nómina" de 500.
    await tapKey(tester, 'add-button');
    await tapKey(tester, 'add-income');
    await tester.enterText(find.byKey(const Key('income-name')), 'Nómina');
    await tester.enterText(find.byKey(const Key('income-amount')), '500');
    await tapKey(tester, 'income-save');
    await waitGone(tester, find.text('Nuevo ingreso'));

    // 4. Movimientos.
    await goTo(tester, 'Movimientos');
    final enMovimientos = {
      'Prueba café': find.text('Prueba café').evaluate().isNotEmpty,
      r'−$50.00': find.text(r'−$50.00').evaluate().isNotEmpty,
      'Nómina': find.text('Nómina').evaluate().isNotEmpty,
      r'+$500.00': find.text(r'+$500.00').evaluate().isNotEmpty,
    };
    await shot(tester, '4-movimientos');

    // 5. Inicio después de guardar.
    await goTo(tester, 'Inicio');
    final after = readSummary(tester);
    final enInicio = {
      'Prueba café': find.text('Prueba café').evaluate().isNotEmpty,
      'Nómina': find.text('Nómina').evaluate().isNotEmpty,
    };
    await shot(tester, '5-inicio-despues');

    // ignore: avoid_print
    print('ANTES=$before');
    // ignore: avoid_print
    print('DESPUES=$after');
    // ignore: avoid_print
    print('MOVIMIENTOS=$enMovimientos');
    // ignore: avoid_print
    print('INICIO=$enInicio');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');

    // Movimientos: ambos registros con su importe.
    expect(enMovimientos.values, everyElement(isTrue));

    // Inicio: con la base vacía, el mes debe mostrar exactamente lo guardado.
    expect(after['ingresos'], r'$500', reason: 'Ingresos del mes');
    expect(after['gastos'], r'$50', reason: 'Gastos del mes');
    expect(after['balance'], r'$450.00', reason: 'Balance del mes');
    expect(enInicio.values, everyElement(isTrue), reason: 'Filas en Inicio');
  });
}
