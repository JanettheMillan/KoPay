// S2-04 · Selector de categorías con alta, búsqueda, edición y
// eliminación (HU-10, HU-11, HU-12).
//
// La base se reemplaza por una versión en memoria de los ajustes para
// que la interfaz no espere a SQLite; el provider es el real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:kopay/widgets/add_movement_sheet.dart';
import 'package:kopay/widgets/category_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Guarda los ajustes en un mapa en lugar de SQLite.
class MemorySettingsDb extends DatabaseHelper {
  MemorySettingsDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final Map<String, String> values = {};

  @override
  Future<String?> getSetting(String key) async => values[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      values[key] = value;
}

class FakeMovementProvider extends MovementProvider {
  final List<Movement> saved = [];

  @override
  Future<Movement> add(Movement movement) async {
    final error = Validators.checkMovement(movement);
    if (error != null) throw ValidationException(error);
    final withId = movement.copyWith(id: saved.length + 1);
    saved.add(withId);
    return withId;
  }
}

void main() {
  late MemorySettingsDb db;
  late CategoryProvider categories;

  setUp(() async {
    db = MemorySettingsDb();
    categories = CategoryProvider(database: db);
    await categories.load();
  });

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Monta un botón que abre el selector y guarda lo que devuelve.
  Future<List<String?>> openPicker(
    WidgetTester tester, {
    String? selected,
  }) async {
    phoneSize(tester);
    final results = <String?>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<CategoryProvider>.value(
        value: categories,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showCategoryPicker(context, selected: selected),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return results;
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'UI-CAT-01 · HU-10 · muestra las categorías y elegir una la devuelve',
    (tester) async {
      final results = await openPicker(tester, selected: 'Comida');

      for (final c in DatabaseHelper.defaultCategories) {
        expect(find.byKey(Key('category-$c')), findsOneWidget);
      }
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tapKey(tester, 'category-Transporte');
      expect(results, ['Transporte']);
    },
  );

  testWidgets(
    'UI-CAT-02 · HU-10 · la búsqueda filtra y avisa si no hay resultados',
    (tester) async {
      await openPicker(tester);

      await tester.enterText(find.byKey(const Key('category-search')), 'sal');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('category-Salud')), findsOneWidget);
      expect(find.byKey(const Key('category-Comida')), findsNothing);

      await tester.enterText(find.byKey(const Key('category-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados para "zzz"'), findsOneWidget);
    },
  );

  testWidgets(
    'UI-CAT-03 · HU-11 · crear una categoría la guarda y la selecciona',
    (tester) async {
      final results = await openPicker(tester);

      await tapKey(tester, 'category-add');
      await tester.enterText(
        find.byKey(const Key('category-name-field')),
        'Mascotas',
      );
      await tapKey(tester, 'category-save');

      expect(results, ['Mascotas']);
      expect(categories.categories.last, 'Mascotas');
      expect(db.values[CategoryProvider.settingsKey], contains('Mascotas'));
    },
  );

  testWidgets(
    'UI-CAT-04 · HU-11 · un nombre repetido muestra el error y no se guarda',
    (tester) async {
      final results = await openPicker(tester);

      await tapKey(tester, 'category-add');
      await tester.enterText(
        find.byKey(const Key('category-name-field')),
        'comida',
      );
      await tapKey(tester, 'category-save');

      expect(find.text(CategoryProvider.duplicated), findsOneWidget);
      expect(results, isEmpty);
      expect(categories.categories, DatabaseHelper.defaultCategories);
    },
  );

  testWidgets('UI-CAT-05 · HU-12 · renombrar actualiza el selector', (
    tester,
  ) async {
    await openPicker(tester);

    await tapKey(tester, 'category-edit-Salud');
    await tester.enterText(
      find.byKey(const Key('category-name-field')),
      'Farmacia',
    );
    await tapKey(tester, 'category-save');

    expect(find.byKey(const Key('category-Farmacia')), findsOneWidget);
    expect(find.byKey(const Key('category-Salud')), findsNothing);
    expect(categories.categories, contains('Farmacia'));
  });

  testWidgets(
    'UI-CAT-06 · HU-12 · eliminar pide confirmación; cancelar conserva',
    (tester) async {
      await openPicker(tester);

      await tapKey(tester, 'category-delete-Vivienda');
      expect(find.text('¿Eliminar "Vivienda"?'), findsOneWidget);
      await tapKey(tester, 'category-delete-cancel');
      expect(find.byKey(const Key('category-Vivienda')), findsOneWidget);
      expect(categories.categories, contains('Vivienda'));

      await tapKey(tester, 'category-delete-Vivienda');
      await tapKey(tester, 'category-delete-confirm');
      expect(find.byKey(const Key('category-Vivienda')), findsNothing);
      expect(categories.categories, isNot(contains('Vivienda')));
    },
  );

  testWidgets(
    'UI-CAT-07 · HU-10 · el gasto guardado conserva una categoría creada',
    (tester) async {
      phoneSize(tester);
      final movements = FakeMovementProvider();
      addTearDown(movements.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<MovementProvider>.value(value: movements),
            ChangeNotifierProvider<CategoryProvider>.value(value: categories),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAddMovementSheet(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('movement-amount')), '120');
      await tester.enterText(
        find.byKey(const Key('movement-description')),
        'Croquetas',
      );
      await tapKey(tester, 'movement-category');
      await tapKey(tester, 'category-add');
      await tester.enterText(
        find.byKey(const Key('category-name-field')),
        'Mascotas',
      );
      await tapKey(tester, 'category-save');
      expect(find.textContaining('Mascotas'), findsOneWidget);

      await tapKey(tester, 'movement-save');
      expect(movements.saved.single.category, 'Mascotas');
    },
  );

  testWidgets('UI-CAT-08 · HU-10 · sin provider solo permite elegir', (
    tester,
  ) async {
    phoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCategoryPicker(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('category-Comida')), findsOneWidget);
    expect(find.byKey(const Key('category-add')), findsNothing);
    expect(find.byKey(const Key('category-edit-Comida')), findsNothing);
  });

  test('UT-63 · HU-10 · emoji por coincidencia parcial', () {
    expect(categoryEmoji('Compra de comida'), '🛒');
    expect(categoryEmoji('Ingreso'), '💼');
  });
}
