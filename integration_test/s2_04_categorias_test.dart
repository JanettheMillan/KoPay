// S2-04 · Administración de categorías en la app real (HU-10 a HU-12).
//
// Corre la app con SQLite real a 390 × 844 pt: crea, busca, renombra y
// elimina categorías desde el selector del formulario de gasto, guarda
// un gasto con la categoría nueva y "reabre" la app (providers nuevos
// sobre la misma base) para comprobar que los cambios persisten.
// Guarda una captura por paso.
//
//   flutter test integration_test/s2_04_categorias_test.dart -d macos

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
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s2_04')
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

  /// Monta la app con providers nuevos, como al abrirla otra vez.
  Future<void> openApp(WidgetTester tester) async {
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
            ],
            child: const KopayApp(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openPickerFromExpenseForm(WidgetTester tester) async {
    await tapKey(tester, 'add-button');
    await tapKey(tester, 'add-movement');
    await tapKey(tester, 'movement-category');
  }

  testWidgets('INT-CAT · HU-10 a HU-12 · categorías en la app real', (
    tester,
  ) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(DatabaseHelper.movementsTable);
    await DatabaseHelper.instance.setSetting(
      CategoryProvider.settingsKey,
      '["Comida","Transporte","Servicios","Vivienda","Entretenimiento",'
      '"Salud","Otros"]',
    );

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await openApp(tester);

    // 1. Selector con las categorías iniciales.
    await openPickerFromExpenseForm(tester);
    expect(find.byKey(const Key('category-Comida')), findsOneWidget);
    await shot(tester, '1-selector');

    // 2. Búsqueda.
    await tester.enterText(find.byKey(const Key('category-search')), 'tra');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('category-Transporte')), findsOneWidget);
    expect(find.byKey(const Key('category-Comida')), findsNothing);
    await shot(tester, '2-busqueda');
    await tester.enterText(find.byKey(const Key('category-search')), '');
    await tester.pumpAndSettle();

    // 3. Renombrar Salud → Farmacia.
    await tapKey(tester, 'category-edit-Salud');
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Farmacia',
    );
    await shot(tester, '3-renombrar');
    await tapKey(tester, 'category-save');
    expect(find.byKey(const Key('category-Farmacia')), findsOneWidget);

    // 4. Eliminar Vivienda con confirmación.
    await tapKey(tester, 'category-delete-Vivienda');
    await shot(tester, '4-eliminar-confirmacion');
    await tapKey(tester, 'category-delete-confirm');
    expect(find.byKey(const Key('category-Vivienda')), findsNothing);

    // 5. Crear Mascotas: queda elegida en el formulario.
    await tapKey(tester, 'category-add');
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Mascotas',
    );
    await shot(tester, '5-nueva-categoria');
    await tapKey(tester, 'category-save');
    expect(find.textContaining('Mascotas'), findsOneWidget);

    // 6. Guardar el gasto con la categoría nueva (HU-10).
    await tester.enterText(find.byKey(const Key('movement-amount')), '120');
    await tester.enterText(
      find.byKey(const Key('movement-description')),
      'Croquetas',
    );
    await shot(tester, '6-gasto-con-categoria');
    await tapKey(tester, 'movement-save');
    final saved = await DatabaseHelper.instance.getMovements();
    expect(saved.single.category, 'Mascotas');

    // 7. Reabrir: los cambios siguen en el selector (HU-11, HU-12).
    await openApp(tester);
    await openPickerFromExpenseForm(tester);
    expect(find.byKey(const Key('category-Mascotas')), findsOneWidget);
    expect(find.byKey(const Key('category-Farmacia')), findsOneWidget);
    expect(find.byKey(const Key('category-Salud')), findsNothing);
    expect(find.byKey(const Key('category-Vivienda')), findsNothing);
    await shot(tester, '7-tras-reabrir');
  });
}
