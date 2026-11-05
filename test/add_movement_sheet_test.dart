import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:kopay/widgets/add_movement_sheet.dart';
import 'package:kopay/widgets/category_picker_sheet.dart';
import 'package:provider/provider.dart';

/// Provider en memoria: aplica las mismas validaciones que el real pero
/// sin SQLite, para que las pruebas de interfaz no esperen a la base.
class FakeMovementProvider extends MovementProvider {
  final List<Movement> saved = [];
  int _nextId = 1;

  @override
  List<Movement> get movements => List.unmodifiable(saved);

  @override
  Future<Movement> add(Movement movement) async {
    final error = Validators.checkMovement(movement);
    if (error != null) throw ValidationException(error);
    final withId = movement.copyWith(id: _nextId++);
    saved.add(withId);
    notifyListeners();
    return withId;
  }

  @override
  Future<void> update(Movement movement) async {
    final error = Validators.checkMovement(movement);
    if (error != null) throw ValidationException(error);
    final i = saved.indexWhere((m) => m.id == movement.id);
    saved[i] = movement;
    notifyListeners();
  }
}

void main() {
  late FakeMovementProvider provider;

  setUp(() => provider = FakeMovementProvider());
  tearDown(() => provider.dispose());

  /// Monta un botón que abre el formulario y guarda lo que devuelve.
  Future<List<Movement?>> openSheet(
    WidgetTester tester, {
    Movement? initial,
  }) async {
    final results = <Movement?>[];
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<MovementProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showAddMovementSheet(context, initial: initial),
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

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('movement-save')));
    await tester.tap(find.byKey(const Key('movement-save')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseCategory(WidgetTester tester, String category) async {
    await tester.tap(find.byKey(const Key('movement-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('category-$category')));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra monto, tipo, descripción, categoría, fecha y nota', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Nuevo gasto'), findsOneWidget);
    for (final key in [
      'movement-type',
      'movement-amount',
      'movement-description',
      'movement-category',
      'movement-date',
      'movement-note',
      'movement-save',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('guardar vacío muestra los errores y no guarda nada', (
    tester,
  ) async {
    final results = await openSheet(tester);
    await save(tester);

    expect(find.text(Validators.emptyAmount), findsOneWidget);
    expect(find.text(Validators.emptyDescription), findsOneWidget);
    expect(find.text(Validators.emptyCategory), findsOneWidget);
    expect(results, isEmpty); // la hoja sigue abierta
    expect(provider.saved, isEmpty);
  });

  testWidgets('un monto inválido muestra su mensaje', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byKey(const Key('movement-amount')), '12.345');
    await save(tester);
    expect(find.text(Validators.tooManyDecimals), findsOneWidget);

    await tester.enterText(find.byKey(const Key('movement-amount')), 'abc');
    await tester.pump();
    expect(find.text(Validators.notANumber), findsOneWidget);
  });

  testWidgets('un gasto válido se guarda negativo y cierra la hoja', (
    tester,
  ) async {
    final results = await openSheet(tester);

    await tester.enterText(
      find.byKey(const Key('movement-amount')),
      '1,350.50',
    );
    await tester.enterText(
      find.byKey(const Key('movement-description')),
      '  Súper  ',
    );
    await chooseCategory(tester, 'Comida');
    await tester.enterText(find.byKey(const Key('movement-note')), 'Despensa');
    await save(tester);

    expect(find.text('Nuevo gasto'), findsNothing);
    final saved = results.single!;
    expect(saved.id, isNotNull);
    expect(saved.amount, -1350.5);
    expect(saved.description, 'Súper');
    expect(saved.category, 'Comida');
    expect(saved.note, 'Despensa');
    expect(provider.saved, [saved]);
  });

  testWidgets('tipo Entrada guarda el monto positivo', (tester) async {
    final results = await openSheet(tester);

    await tester.tap(find.byKey(const Key('toggle-Entrada')));
    await tester.pump();
    expect(find.text('Nueva entrada'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('movement-amount')), '200');
    await tester.enterText(
      find.byKey(const Key('movement-description')),
      'Reembolso',
    );
    await chooseCategory(tester, 'Otros');
    await save(tester);

    expect(results.single!.amount, 200);
    expect(results.single!.note, isNull);
  });

  testWidgets('editar carga los datos y guarda los cambios', (tester) async {
    final original = await provider.add(
      Movement(
        amount: -540,
        description: 'Luz',
        category: 'Servicios',
        date: DateTime(2026, 11, 8),
      ),
    );

    final results = await openSheet(tester, initial: original);
    expect(find.text('Editar movimiento'), findsOneWidget);
    expect(find.text('540.00'), findsOneWidget);
    expect(find.text('Luz'), findsOneWidget);
    expect(find.text('08/11/2026'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('movement-amount')), '600');
    await save(tester);

    final edited = results.single!;
    expect(edited.id, original.id);
    expect(edited.amount, -600);
    expect(provider.saved, [edited]);
  });

  test('las categorías del selector coinciden con las de la base', () {
    expect(
      defaultCategoryEmojis.keys.toList(),
      DatabaseHelper.defaultCategories,
    );
  });
}
