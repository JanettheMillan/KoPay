// S2-13 · Formulario y detalle de tarjeta (HU-13, HU-14, HU-15).
//
// El plan de pruebas no tiene casos de interfaz para tarjetas; estos son
// casos nuevos (UI-TAR-xx). Usan un CardProvider en memoria que aplica
// las mismas validaciones que el real, sin SQLite.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/screens/home_screen.dart';
import 'package:kopay/utils/validators.dart';
import 'package:kopay/widgets/cards_section.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base vacía para los providers de Inicio (desde D-05 Inicio los lee).
class _EmptyDb extends DatabaseHelper {
  _EmptyDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async => [];

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async => [];
}

class MemoryCards extends CardProvider {
  final List<CardModel> saved = [];
  int _id = 1;

  @override
  bool get isLoaded => true;
  @override
  List<CardModel> get cards => List.unmodifiable(saved);

  @override
  CardModel? byId(int id) {
    for (final c in saved) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<CardModel> add(CardModel card) async {
    final error = Validators.checkCard(card);
    if (error != null) throw ValidationException(error);
    final withId = card.copyWith(id: _id++);
    saved.add(withId);
    notifyListeners();
    return withId;
  }

  @override
  Future<void> update(CardModel card) async {
    final error = Validators.checkCard(card);
    if (error != null) throw ValidationException(error);
    saved[saved.indexWhere((c) => c.id == card.id)] = card;
    notifyListeners();
  }

  @override
  Future<void> delete(int id) async {
    saved.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}

void main() {
  late MemoryCards cards;

  setUp(() => cards = MemoryCards());

  Future<void> start(WidgetTester tester, {Widget? child}) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<CardProvider>.value(
        value: cards,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: child ?? const CardsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, Map<String, String> fields) async {
    for (final entry in fields.entries) {
      final field = find.byKey(Key('card-${entry.key}'));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
    }
  }

  Future<CardModel> seed() => cards.add(
    const CardModel(
      name: 'Oro',
      bank: 'BBVA',
      creditLimit: 1000,
      usedBalance: 200,
      cutDay: 5,
      paymentDay: 25,
      minimumPayment: 100,
    ),
  );

  testWidgets('UI-TAR-01 · HU-13 · Inicio muestra la sección de tarjetas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 2532); // ver OBS-01
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final db = _EmptyDb();
    final movements = MovementProvider(database: db);
    final incomes = IncomeProvider(database: db);
    await movements.load();
    await incomes.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MovementProvider>.value(value: movements),
          ChangeNotifierProvider<IncomeProvider>.value(value: incomes),
          ChangeNotifierProvider<CardProvider>.value(value: cards),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('cards-empty')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('home-cards')), findsOneWidget);
    expect(find.byKey(const Key('cards-add')), findsOneWidget);
  });

  testWidgets('UI-TAR-02 · HU-13 · Formulario incompleto o inválido no '
      'guarda', (tester) async {
    await start(tester);
    expect(find.byKey(const Key('cards-empty')), findsOneWidget);

    await tapKey(tester, 'cards-add');
    expect(find.text('Nueva tarjeta'), findsOneWidget);

    await tapKey(tester, 'card-save');
    expect(find.text(Validators.emptyCardName), findsOneWidget);
    expect(find.text(Validators.emptyBank), findsOneWidget);
    expect(find.text(Validators.emptyAmount), findsOneWidget);
    expect(find.text(Validators.invalidDay), findsNWidgets(2));

    await fill(tester, {
      'name': 'Oro',
      'bank': 'BBVA',
      'limit': '0',
      'cut-day': '0',
      'payment-day': '32',
    });
    await tapKey(tester, 'card-save');
    expect(find.text(Validators.notPositive), findsOneWidget);
    expect(find.text(Validators.invalidDay), findsNWidgets(2));

    expect(find.text('Nueva tarjeta'), findsOneWidget);
    expect(cards.saved, isEmpty);
  });

  testWidgets('UI-TAR-03 · HU-13 · Una tarjeta válida aparece con su '
      'disponible', (tester) async {
    await start(tester);
    await tapKey(tester, 'cards-add');
    await fill(tester, {
      'name': 'Oro',
      'bank': 'BBVA',
      'limit': '1000',
      'used': '200',
      'cut-day': '5',
      'payment-day': '25',
    });
    await tapKey(tester, 'card-save');

    expect(find.text('Nueva tarjeta'), findsNothing);
    expect(find.text('Tarjeta guardada'), findsOneWidget);
    final saved = cards.saved.single;
    expect(saved.creditLimit, 1000);
    expect(saved.usedBalance, 200);
    expect(saved.minimumPayment, 0);
    expect(find.byKey(Key('card-row-${saved.id}')), findsOneWidget);
    expect(find.text(r'$800.00 disponible'), findsOneWidget);
  });

  testWidgets('UI-TAR-04 · HU-13 · Tocar la tarjeta abre su detalle', (
    tester,
  ) async {
    final oro = await seed();
    await start(tester);

    await tapKey(tester, 'card-row-${oro.id}');
    expect(find.text('Oro'), findsOneWidget);
    expect(find.text('BBVA'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('card-available'))).data,
      r'$800.00',
    );
    expect(find.text(r'$1,000.00'), findsOneWidget);
    expect(find.text('Día 5'), findsOneWidget);
    expect(find.text('Día 25'), findsOneWidget);
    expect(find.byKey(const Key('card-edit')), findsOneWidget);
    expect(find.byKey(const Key('card-delete')), findsOneWidget);
  });

  testWidgets('UI-TAR-05 · HU-14 · Editar recalcula el disponible', (
    tester,
  ) async {
    final oro = await seed();
    await start(tester);
    await tapKey(tester, 'card-row-${oro.id}');

    await tapKey(tester, 'card-edit');
    expect(find.text('Editar tarjeta'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('card-limit')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      '1000.00',
    );
    await fill(tester, {'limit': '1500', 'used': '300', 'payment-day': '28'});
    await tapKey(tester, 'card-save');

    expect(find.text('Editar tarjeta'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('card-available'))).data,
      r'$1,200.00',
    );
    expect(find.text('Día 28'), findsOneWidget);
    expect(cards.saved.single.id, oro.id);
    expect(cards.saved.single.paymentDay, 28);
  });

  testWidgets('UI-TAR-06 · HU-15 · Cancelar conserva y confirmar elimina', (
    tester,
  ) async {
    final oro = await seed();
    await start(tester);
    await tapKey(tester, 'card-row-${oro.id}');

    await tapKey(tester, 'card-delete');
    expect(find.text('¿Eliminar tarjeta?'), findsOneWidget);
    await tapKey(tester, 'card-delete-cancel');
    expect(cards.saved, hasLength(1));
    expect(find.byKey(const Key('card-available')), findsOneWidget);

    await tapKey(tester, 'card-delete');
    await tapKey(tester, 'card-delete-confirm');
    expect(cards.saved, isEmpty);
    expect(find.text('Tarjeta eliminada'), findsOneWidget);
    // Regresa a Inicio y la fila ya no está.
    expect(find.byKey(const Key('card-available')), findsNothing);
    expect(find.byKey(const Key('cards-empty')), findsOneWidget);
  });
}
