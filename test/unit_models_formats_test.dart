// S1-16 · Pruebas unitarias de modelos y formatos.
//
// Cada prueba lleva el identificador del caso en docs/plan-de-pruebas.md.
// Los casos que encontraron un defecto o que dependen de algo que todavía
// no existe se marcan con `skip` y el motivo; el resultado de cada caso
// está en la sección 8.1 del plan de pruebas.

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/debt_model.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:kopay/widgets/category_picker_sheet.dart';

void main() {
  final fecha = DateTime(2026, 10, 8);

  group('4.1 Modelos', () {
    test('UT-01 · Copia de movimiento', () {
      final original = Movement(
        id: 4,
        amount: -50,
        description: 'Café',
        category: 'Comida',
        date: fecha,
        note: 'Mañana',
      );
      final copia = original.copyWith(amount: -75, description: 'Desayuno');

      expect(copia.amount, -75);
      expect(copia.description, 'Desayuno');
      expect(copia.id, 4);
      expect(copia.category, 'Comida');
      expect(copia.date, fecha);
      expect(copia.note, 'Mañana');
      // El original no cambia.
      expect(original.amount, -50);
      expect(original.description, 'Café');
    });

    test('UT-02 · Conversión de movimiento a mapa', () {
      final original = Movement(
        id: 9,
        amount: -50,
        description: 'Café',
        category: 'Comida',
        date: DateTime(2026, 10, 8, 9, 30),
        note: 'Mañana',
      );
      final reconstruido = Movement.fromMap(original.toMap());

      expect(reconstruido, original);
      expect(reconstruido.date, DateTime(2026, 10, 8, 9, 30));
      // El tipo se deduce del signo del monto.
      expect(reconstruido.isExpense, isTrue);
    });

    test('UT-03 · Ingreso representado como movimiento', () {
      final ingreso = Income(id: 1, name: 'Nómina', amount: 500, date: fecha);
      final m = ingreso.toMovement();

      expect(m.amount, 500);
      expect(m.isExpense, isFalse);
      expect(m.description, 'Nómina');
      expect(m.date, fecha);
      expect(m.category, 'Ingreso');
      // D-02: el ingreso se distingue por su categoría, no por un tipo
      // `legacy_income`; como movimiento es `regular`, no un pago.
      expect(m.type, MovementType.regular);
      expect(m.isPayment, isFalse);
    });

    test('UT-18 · Copia parcial de ingreso', () {
      final ingreso = Income(name: 'Nómina', amount: 500, date: fecha);
      final copia = ingreso.copyWith(amount: 650);

      expect(copia.amount, 650);
      expect(copia.name, 'Nómina');
      expect(copia.date, fecha);
      expect(ingreso.amount, 500);
    });

    test('UT-19 · Conversión de ingreso a mapa', () {
      final ingreso = Income(
        id: 3,
        name: 'Nómina',
        amount: 500,
        date: fecha,
        note: 'Quincena',
      );
      final reconstruido = Income.fromMap(ingreso.toMap());

      expect(reconstruido, ingreso);
      expect(reconstruido.id, 3);
    });
  });

  group('4.1 Formatos', () {
    test('UT-14 · HU-24 · Formato de importe en MXN, USD y EUR', () {
      addTearDown(() => FormatUtils.configure(currency: 'MXN'));
      FormatUtils.configure(currency: 'MXN');
      expect(FormatUtils.money(1234.5), r'$1,234.50');
      FormatUtils.configure(currency: 'USD');
      expect(FormatUtils.money(1234.5), r'US$1,234.50');
      FormatUtils.configure(currency: 'EUR');
      expect(FormatUtils.money(1234.5), '€1,234.50');
    });

    test('UT-14 (parcial) · Formato de importe en MXN', () {
      expect(FormatUtils.money(1234.5), r'$1,234.50');
      expect(FormatUtils.money(-1234.5), r'$1,234.50');
    });

    test('UT-15 · Formato de fecha', () {
      // El modelo guarda la fecha completa en ISO 8601, no solo el día.
      final map = Movement(
        amount: -1,
        description: 'x',
        category: 'Otros',
        date: fecha,
      ).toMap();
      expect(map['date'], '2026-10-08T00:00:00.000');
      expect((map['date'] as String).substring(0, 10), '2026-10-08');

      expect(FormatUtils.fullDate(fecha), '08/10/2026');
      expect(FormatUtils.shortDate(fecha), '8 oct');
    });

    test('UT-29 · Formato compacto del importe', () {
      final texto = FormatUtils.moneyCompact(1234.5);
      expect(texto.startsWith(r'$'), isTrue);
      expect(texto.contains('.'), isFalse);
      expect(texto, r'$1,235'); // redondea hacia arriba
    });

    test(
      'UT-30 · Fecha relativa de hoy y ayer',
      () {},
      skip:
          'Bloqueado: no existe una función de fecha relativa '
          '("hoy", "ayer"); el historial muestra la fecha corta.',
    );
  });

  group('4.1 Categorías', () {
    test('UT-20 · Emoji de categoría conocida (texto exacto)', () {
      expect(categoryEmoji('Comida'), '🛒');
      expect(categoryEmoji('Transporte'), '🚌');
    });

    test('UT-20 · Emoji de categoría conocida con espacios y mayúsculas', () {
      expect(categoryEmoji(' comida '), '🛒');
      expect(categoryEmoji('TRANSPORTE'), '🚌');
      expect(categoryEmoji('Ingreso'), isNot('🏷️'));
    });

    test('UT-21 · Emoji de categoría desconocida', () {
      expect(categoryEmoji('Mascotas'), '🏷️');
    });
  });

  group('4.2 Fechas del mes', () {
    test('UT-31 · Fecha dentro del mes', () {
      expect(
        FormatUtils.isSameMonth(DateTime(2026, 10, 9), DateTime(2026, 10)),
        isTrue,
      );
    });

    test('UT-32 · Mismo mes de otro año', () {
      expect(
        FormatUtils.isSameMonth(DateTime(2025, 10, 9), DateTime(2026, 10)),
        isFalse,
      );
    });

    Map<String, dynamic> conFecha(String date) => {
      'amount': -1,
      'description': 'x',
      'category': 'Otros',
      'date': date,
    };

    test('UT-33 · Fecha mal formada: texto que no es fecha', () {
      // isSameMonth recibe DateTime, así que el texto se valida al leerlo
      // con Movement.fromMap. Un texto que no es fecha se rechaza.
      expect(() => Movement.fromMap(conFecha('abc')), throwsFormatException);
    });

    test(
      'UT-33 · HU-08 · Fecha mal formada: día o mes fuera de rango (D-03)',
      () {
        for (final text in [
          '2026-13-45',
          '2026-02-30',
          '2026-00-10',
          '2026-04-31',
        ]) {
          expect(
            () => Movement.fromMap(conFecha(text)),
            throwsFormatException,
            reason: text,
          );
        }
      },
    );

    test('UT-33 · HU-08 · Fecha mal formada: hora fuera de rango (D-03)', () {
      expect(
        () => Movement.fromMap(conFecha('2026-10-08T25:00:00.000')),
        throwsFormatException,
      );
    });

    test('UT-33 · HU-02 · Ingreso con fecha imposible se rechaza (D-03)', () {
      expect(
        () => Income.fromMap({
          'amount': 100,
          'name': 'Nómina',
          'date': '2026-02-30',
        }),
        throwsFormatException,
      );
    });

    test(
      'UT-33 · HU-19 · Deuda con vencimiento imposible se rechaza (D-03)',
      () {
        expect(
          () => DebtModel.fromMap({
            'name': 'Préstamo',
            'monthly_payment': 500,
            'remaining_balance': 3000,
            'due_date': '2026-02-30',
          }),
          throwsFormatException,
        );
      },
    );

    test('UT-33 · HU-08 · Fechas válidas se leen igual que antes (D-03)', () {
      final guardada = DateTime(2026, 10, 8, 14, 30, 5, 120);
      expect(
        Movement.fromMap(conFecha(guardada.toIso8601String())).date,
        guardada,
      );
      expect(
        Movement.fromMap(conFecha('2028-02-29')).date,
        DateTime(2028, 2, 29),
      );
      expect(
        Movement.fromMap(conFecha('2026-12-31')).date,
        DateTime(2026, 12, 31),
      );
      expect(
        Movement.fromMap(conFecha('2026-10-08T23:59:59Z')).date,
        DateTime.utc(2026, 10, 8, 23, 59, 59),
      );
    });
  });
}
