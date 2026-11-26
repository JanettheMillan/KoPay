// S2-11 · Proveedor de deudas y actualización de saldo (HU-19 a HU-21).
//
// El plan de pruebas (docs/plan-de-pruebas.md) no tiene un caso para el
// proveedor de deudas: UT-05 y UT-17 cubren el modelo (S2-08) y UI-07 el
// formulario de pago (S2-15). Los casos DPR-xx son pruebas nuevas de esta
// tarjeta.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;
  late DebtProvider provider;
  late int notifications;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_debt_provider_test');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    provider = DebtProvider(database: db);
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  final auto = DebtModel(
    name: 'Préstamo auto',
    monthlyPayment: 100,
    remainingBalance: 300,
    dueDate: DateTime(2026, 12, 15),
  );
  final hoy = DateTime(2026, 11, 26);

  test('DPR-01 · HU-19 · load lee lo guardado en la base y notifica', () async {
    final guardada = await db.insertDebt(auto);

    await provider.load();

    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.debts, [guardada]);
    expect(notifications, 2); // inicio y fin de la carga
  });

  test(
    'DPR-02 · HU-19 · Alta: guarda pendiente, suma saldo y notifica',
    () async {
      final guardada = await provider.add(auto);

      expect(guardada.id, isNotNull);
      expect(guardada.status, DebtStatus.pending);
      expect(await db.getDebts(), [guardada]);
      expect(provider.debts, [guardada]);
      expect(provider.pendingDebts, [guardada]);
      expect(provider.totalRemaining, 300);
      expect(provider.totalMonthlyPayment, 100);
      expect(notifications, 1);
    },
  );

  test(
    'DPR-03 · HU-20 · Un pago reduce el saldo y aparece en Movimientos',
    () async {
      final deuda = await provider.add(auto);

      final pago = await provider.pay(deuda.id!, 120, date: hoy, note: 'nov');

      expect(pago.type, MovementType.payment);
      expect(pago.debtId, deuda.id);
      expect(pago.amount, -120);
      expect(await db.getMovements(), [pago]);
      expect(await provider.paymentsOf(deuda.id!), [pago]);

      final actual = provider.byId(deuda.id!)!;
      expect(actual.remainingBalance, 180);
      expect(actual.status, DebtStatus.pending);
      expect(provider.totalRemaining, 180);
      expect(notifications, 2);
    },
  );

  test('DPR-04 · HU-21 · Pagar el saldo restante liquida la deuda', () async {
    final deuda = await provider.add(auto);

    await provider.pay(deuda.id!, 100, date: hoy);
    await provider.pay(deuda.id!, 200, date: hoy);

    final liquidada = provider.byId(deuda.id!)!;
    expect(liquidada.remainingBalance, 0);
    expect(liquidada.status, DebtStatus.paid);
    expect((await db.getDebt(deuda.id!))!.isPaid, isTrue);
    expect(provider.pendingDebts, isEmpty);
    expect(provider.paidDebts, [liquidada]);
    expect(provider.totalRemaining, 0);
    expect(provider.totalMonthlyPayment, 0);
  });

  test('DPR-05 · HU-21 · Un pago con centavos liquida sin residuo', () async {
    final deuda = await provider.add(auto.copyWith(remainingBalance: 0.3));

    await provider.pay(deuda.id!, 0.1, date: hoy);
    await provider.pay(deuda.id!, 0.2, date: hoy);

    expect(provider.byId(deuda.id!)!.isPaid, isTrue);
  });

  group('DPR-06 · HU-20 · Un pago inválido no cambia nada', () {
    final casos = <String, (double, String)>{
      'cero': (0, Validators.notPositive),
      'negativo': (-10, Validators.notPositive),
      'mayor que el saldo': (300.01, Validators.overBalance),
    };

    for (final MapEntry(key: nombre, value: (importe, mensaje))
        in casos.entries) {
      test(nombre, () async {
        final deuda = await provider.add(auto);
        notifications = 0;

        await expectLater(
          provider.pay(deuda.id!, importe, date: hoy),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              mensaje,
            ),
          ),
        );
        expect((await db.getDebt(deuda.id!))!.remainingBalance, 300);
        expect(await db.getMovements(), isEmpty);
        expect(notifications, 0);
      });
    }

    test('deuda inexistente', () async {
      await expectLater(provider.pay(999, 10, date: hoy), throwsArgumentError);
      expect(await db.getMovements(), isEmpty);
    });
  });

  test('DPR-07 · HU-19, HU-21 · Editar el saldo ajusta el estado', () async {
    final deuda = await provider.add(auto);

    await provider.update(deuda.copyWith(remainingBalance: 0));
    expect(provider.byId(deuda.id!)!.status, DebtStatus.paid);

    await provider.update(
      provider.byId(deuda.id!)!.copyWith(remainingBalance: 50),
    );
    final leida = (await db.getDebt(deuda.id!))!;
    expect(leida.remainingBalance, 50);
    expect(leida.status, DebtStatus.pending);
  });

  test(
    'DPR-08 · HU-19 · Una deuda registrada con saldo cero ya está pagada',
    () async {
      final guardada = await provider.add(auto.copyWith(remainingBalance: 0));

      expect(guardada.status, DebtStatus.paid);
      expect(provider.paidDebts, [guardada]);
    },
  );

  test('DPR-09 · HU-19 · Eliminación: quita la deuda y su saldo', () async {
    final primera = await provider.add(auto);
    await provider.add(
      auto.copyWith(name: 'Tarjeta tienda', remainingBalance: 80),
    );
    expect(provider.totalRemaining, 380);

    await provider.delete(primera.id!);

    expect(await db.getDebt(primera.id!), isNull);
    expect(provider.byId(primera.id!), isNull);
    expect(provider.debts.map((d) => d.name), ['Tarjeta tienda']);
    expect(provider.totalRemaining, 80);
  });

  group('DPR-10 · HU-19 · Rechaza deudas inválidas', () {
    final casos = <String, (DebtModel, String)>{
      'sin nombre': (auto.copyWith(name: '  '), Validators.emptyDebtName),
      'mensualidad negativa': (
        auto.copyWith(monthlyPayment: -1),
        Validators.negativeAmount,
      ),
      'saldo negativo': (
        auto.copyWith(remainingBalance: -1),
        Validators.negativeAmount,
      ),
      'saldo enorme': (
        auto.copyWith(remainingBalance: Validators.maxAmount + 1),
        Validators.tooLarge,
      ),
    };

    for (final MapEntry(key: nombre, value: (deuda, mensaje))
        in casos.entries) {
      test(nombre, () async {
        await expectLater(
          provider.add(deuda),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              mensaje,
            ),
          ),
        );
        expect(await db.getDebts(), isEmpty);
        expect(notifications, 0);
      });
    }

    test('edición inválida', () async {
      final guardada = await provider.add(auto);
      await expectLater(
        provider.update(guardada.copyWith(name: '')),
        throwsA(isA<ValidationException>()),
      );
      expect((await db.getDebt(guardada.id!))!.name, 'Préstamo auto');
    });
  });

  test(
    'DPR-11 · HU-19 · La lista expuesta no se puede modificar desde fuera',
    () async {
      await provider.add(auto);

      expect(() => provider.debts.clear(), throwsUnsupportedError);
      expect(() => provider.pendingDebts.clear(), throwsUnsupportedError);
    },
  );

  testWidgets('DPR-12 · HU-20 · Un widget que escucha el provider se '
      'reconstruye con el nuevo saldo', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<DebtProvider>.value(
        value: provider,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Consumer<DebtProvider>(
            builder: (_, debts, _) =>
                Text('saldo ${debts.totalRemaining.toStringAsFixed(0)}'),
          ),
        ),
      ),
    );
    expect(find.text('saldo 0'), findsOneWidget);

    late DebtModel deuda;
    await tester.runAsync(() async => deuda = await provider.add(auto));
    await tester.pump();
    expect(find.text('saldo 300'), findsOneWidget);

    await tester.runAsync(() => provider.pay(deuda.id!, 300, date: hoy));
    await tester.pump();
    expect(find.text('saldo 0'), findsOneWidget);
  });
}
