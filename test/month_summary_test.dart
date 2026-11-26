// #14 · Resumen mensual de HU-09 (UT-34 a UT-46).
//
// Los totales se calculan con MonthSummary.of sobre datos conocidos.
// El resultado de cada caso está en docs/casos-hu-09.md.

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/utils/month_summary.dart';

void main() {
  final octubre = DateTime(2026, 10);

  Movement movimiento(
    double amount,
    DateTime date, {
    String category = 'Comida',
    String description = 'Prueba',
    MovementType type = MovementType.regular,
  }) {
    return Movement(
      amount: amount,
      description: description,
      category: category,
      date: date,
      type: type,
    );
  }

  Income ingreso(double amount, DateTime date, {String name = 'Nómina'}) {
    return Income(name: name, amount: amount, date: date);
  }

  test('UT-34 · HU-09 · Resumen mensual vacío', () {
    final summary = MonthSummary.of([], [], octubre);

    expect(summary.income, 0);
    expect(summary.expenses, 0);
    expect(summary.cardPayments, 0);
    expect(summary.expensesByCategory, isEmpty);
    expect(summary.balance, 0);
  });

  test('UT-35 · HU-02 · Ingreso de la tabla de ingresos', () {
    final summary = MonthSummary.of([], [
      ingreso(500, DateTime(2026, 10, 5)),
    ], octubre);

    expect(summary.income, 500);
    expect(summary.expenses, 0);
    expect(summary.balance, 500);
  });

  test('UT-36 · HU-01 · Gasto ordinario en resumen', () {
    final summary = MonthSummary.of(
      [movimiento(-50, DateTime(2026, 10, 6))],
      [],
      octubre,
    );

    expect(summary.income, 0);
    expect(summary.expenses, 50);
    expect(summary.balance, -50);
  });

  test('UT-37 · HU-03 · Ingreso como movimiento positivo', () {
    final summary = MonthSummary.of(
      [
        movimiento(
          200,
          DateTime(2026, 10, 7),
          category: 'Ingreso',
          description: 'Venta',
        ),
      ],
      [],
      octubre,
    );

    expect(summary.income, 200);
    expect(summary.expenses, 0);
    expect(summary.balance, 200);
  });

  test('UT-38 · HU-16 · Pago de tarjeta separado de los gastos', () {
    final summary = MonthSummary.of(
      [
        movimiento(
          -100,
          DateTime(2026, 10, 8),
          category: 'Pago',
          type: MovementType.payment,
        ),
      ],
      [],
      octubre,
    );

    expect(summary.cardPayments, 100);
    expect(summary.expenses, 0);
    expect(summary.expensesByCategory, isEmpty);
    expect(summary.balance, -100);
  });

  test('UT-39 · HU-10 · Gastos agrupados por categoría', () {
    final summary = MonthSummary.of(
      [
        movimiento(-30, DateTime(2026, 10, 9), category: 'Comida'),
        movimiento(-20, DateTime(2026, 10, 10), category: 'Comida'),
      ],
      [],
      octubre,
    );

    expect(summary.expenses, 50);
    expect(summary.expensesByCategory['Comida'], 50);
  });

  test('UT-40 · HU-09 · La categoría con más gasto aparece primero', () {
    final summary = MonthSummary.of(
      [
        movimiento(-20, DateTime(2026, 10, 11), category: 'Salud'),
        movimiento(-80, DateTime(2026, 10, 12), category: 'Comida'),
      ],
      [],
      octubre,
    );

    expect(summary.expensesByCategory.keys.first, 'Comida');
    expect(summary.expensesByCategory.values.first, 80);
  });

  test('UT-41 · HU-08 · Exclusión de otro mes', () {
    final summary = MonthSummary.of(
      [
        movimiento(-50, DateTime(2026, 9, 30)),
        movimiento(300, DateTime(2026, 9, 29), category: 'Ingreso'),
      ],
      [ingreso(500, DateTime(2026, 9, 28))],
      octubre,
    );

    expect(summary.income, 0);
    expect(summary.expenses, 0);
    expect(summary.cardPayments, 0);
    expect(summary.balance, 0);
  });

  test('UT-42 · HU-09 · Balance del mes', () {
    final summary = MonthSummary.of(
      [
        movimiento(-120, DateTime(2026, 10, 13), category: 'Servicios'),
        movimiento(
          -30,
          DateTime(2026, 10, 14),
          category: 'Pago',
          type: MovementType.payment,
        ),
      ],
      [ingreso(500, DateTime(2026, 10, 15))],
      octubre,
    );

    expect(summary.income, 500);
    expect(summary.expenses, 120);
    expect(summary.cardPayments, 30);
    expect(summary.balance, 350);
  });

  test('UT-43 · HU-02 · Ingreso legado sin doble conteo', () {
    // El ingreso vive en `incomes`; el historial lo muestra con
    // toMovement(), pero no se guarda una copia en `movements`.
    final nomina = ingreso(500, DateTime(2026, 10, 16));
    final summary = MonthSummary.of([], [nomina], octubre);

    expect(summary.income, 500);
    expect(summary.expenses, 0);
    expect(nomina.toMovement().amount, 500);
  });

  test('UT-44 · HU-03 · Entrada positiva no clasificada', () {
    // Corrección del plan: el modelo real no tiene un tipo `income`.
    // Una entrada positiva regular se suma una sola vez como ingreso
    // (HU-03), no como gasto. Antes el plan esperaba ignorarla.
    final summary = MonthSummary.of(
      [
        movimiento(
          75,
          DateTime(2026, 10, 17),
          category: 'Otros',
          description: 'Reembolso',
        ),
      ],
      [],
      octubre,
    );

    expect(summary.income, 75);
    expect(summary.expenses, 0);
    expect(summary.balance, 75);
  });

  test('UT-45 · HU-09 · Movimiento de monto cero', () {
    final summary = MonthSummary.of(
      [movimiento(0, DateTime(2026, 10, 18))],
      [],
      octubre,
    );

    expect(summary.income, 0);
    expect(summary.expenses, 0);
    expect(summary.cardPayments, 0);
    expect(summary.balance, 0);
  });

  test('UT-46 · HU-08 · Límite entre dos meses', () {
    final movimientos = [
      movimiento(-40, DateTime(2026, 10, 31)),
      movimiento(-60, DateTime(2026, 11, 1)),
    ];

    final octubreResumen = MonthSummary.of(movimientos, [], DateTime(2026, 10));
    final noviembreResumen = MonthSummary.of(
      movimientos,
      [],
      DateTime(2026, 11),
    );

    expect(octubreResumen.expenses, 40);
    expect(noviembreResumen.expenses, 60);
  });
}
