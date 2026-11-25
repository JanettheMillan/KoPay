// S2-10 · Proveedor y cálculo de crédito de tarjetas (HU-13 a HU-15).
//
// El plan de pruebas (docs/plan-de-pruebas.md) no tiene un caso para el
// proveedor de tarjetas. Los casos CRE-xx son pruebas nuevas de esta
// tarjeta.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/card_model.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;
  late CardProvider provider;
  late int notifications;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_card_provider_test');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    provider = CardProvider(database: db);
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  const oro = CardModel(
    name: 'Oro',
    bank: 'BBVA',
    creditLimit: 1000,
    usedBalance: 200,
    cutDay: 5,
    paymentDay: 25,
  );

  test('CRE-01 · HU-13 · load lee lo guardado en la base y notifica', () async {
    final guardada = await db.insertCard(oro);

    await provider.load();

    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.cards, [guardada]);
    expect(notifications, 2); // inicio y fin de la carga
  });

  test(
    'CRE-02 · HU-13 · Alta: guarda, recalcula el disponible y notifica',
    () async {
      final guardada = await provider.add(oro);

      expect(guardada.id, isNotNull);
      expect(await db.getCards(), [guardada]);
      expect(provider.cards, [guardada]);
      expect(provider.totalLimit, 1000);
      expect(provider.totalUsed, 200);
      expect(provider.totalAvailable, 800);
      expect(notifications, 1);
    },
  );

  test(
    'CRE-03 · HU-14 · Edición: persiste y recalcula el disponible',
    () async {
      final guardada = await provider.add(oro);

      await provider.update(
        guardada.copyWith(creditLimit: 1500, usedBalance: 900, paymentDay: 28),
      );

      final leida = await db.getCard(guardada.id!);
      expect(leida!.creditLimit, 1500);
      expect(leida.usedBalance, 900);
      expect(leida.paymentDay, 28);
      expect(provider.byId(guardada.id!), leida);
      expect(provider.totalAvailable, 600);
      expect(notifications, 2);
    },
  );

  test('CRE-04 · HU-15 · Eliminación: quita la tarjeta y su crédito', () async {
    final oroGuardada = await provider.add(oro);
    await provider.add(
      oro.copyWith(name: 'Azul', creditLimit: 500, usedBalance: 100),
    );
    expect(provider.totalAvailable, 1200);

    await provider.delete(oroGuardada.id!);

    expect(await db.getCard(oroGuardada.id!), isNull);
    expect(provider.byId(oroGuardada.id!), isNull);
    expect(provider.cards.map((c) => c.name), ['Azul']);
    expect(provider.totalAvailable, 400);
    expect(notifications, 3);
  });

  test(
    'CRE-05 · HU-13 · Una tarjeta excedida aporta cero al disponible',
    () async {
      await provider.add(oro);
      await provider.add(
        oro.copyWith(name: 'Excedida', creditLimit: 300, usedBalance: 450),
      );

      // 800 de Oro + 0 de la excedida; no 800 - 150.
      expect(provider.totalAvailable, 800);
      expect(provider.totalUsed, 650);
    },
  );

  test('CRE-06 · HU-13 · Sin tarjetas los totales son cero', () async {
    await provider.load();

    expect(provider.cards, isEmpty);
    expect(provider.totalLimit, 0);
    expect(provider.totalUsed, 0);
    expect(provider.totalAvailable, 0);
  });

  test(
    'CRE-07 · HU-13 · La lista expuesta no se puede modificar desde fuera',
    () async {
      await provider.add(oro);

      expect(() => provider.cards.clear(), throwsUnsupportedError);
    },
  );

  group('CRE-08 · HU-13, HU-14 · Rechaza tarjetas inválidas', () {
    final casos = <String, (CardModel, String)>{
      'sin nombre': (oro.copyWith(name: '  '), Validators.emptyCardName),
      'sin banco': (oro.copyWith(bank: ''), Validators.emptyBank),
      'límite cero': (oro.copyWith(creditLimit: 0), Validators.notPositive),
      'saldo negativo': (
        oro.copyWith(usedBalance: -1),
        Validators.negativeAmount,
      ),
      'pago mínimo negativo': (
        oro.copyWith(minimumPayment: -5),
        Validators.negativeAmount,
      ),
      'límite enorme': (
        oro.copyWith(creditLimit: Validators.maxAmount + 1),
        Validators.tooLarge,
      ),
      'día de corte 0': (oro.copyWith(cutDay: 0), Validators.invalidDay),
      'día de pago 32': (oro.copyWith(paymentDay: 32), Validators.invalidDay),
    };

    for (final MapEntry(key: nombre, value: (tarjeta, mensaje))
        in casos.entries) {
      test(nombre, () async {
        await expectLater(
          provider.add(tarjeta),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              mensaje,
            ),
          ),
        );
        expect(await db.getCards(), isEmpty);
        expect(notifications, 0);
      });
    }

    test('una edición inválida no cambia la base', () async {
      final guardada = await provider.add(oro);

      await expectLater(
        provider.update(guardada.copyWith(usedBalance: -10)),
        throwsA(isA<ValidationException>()),
      );
      expect(await db.getCard(guardada.id!), guardada);
      expect(provider.totalAvailable, 800);
    });

    test('saldo y pago mínimo en cero son válidos', () {
      expect(
        Validators.checkCard(oro.copyWith(usedBalance: 0, minimumPayment: 0)),
        isNull,
      );
    });
  });

  testWidgets('CRE-09 · HU-14 · Un widget que escucha el provider se '
      'reconstruye con el nuevo disponible', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<CardProvider>.value(
        value: provider,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer<CardProvider>(
            builder: (_, cards, _) =>
                Text('disponible ${cards.totalAvailable.toStringAsFixed(0)}'),
          ),
        ),
      ),
    );
    expect(find.text('disponible 0'), findsOneWidget);

    late CardModel guardada;
    await tester.runAsync(() async => guardada = await provider.add(oro));
    await tester.pump();
    expect(find.text('disponible 800'), findsOneWidget);

    await tester.runAsync(
      () => provider.update(guardada.copyWith(usedBalance: 1000)),
    );
    await tester.pump();
    expect(find.text('disponible 0'), findsOneWidget);
  });
}
