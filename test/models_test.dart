import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/utils/format_utils.dart';

void main() {
  final date = DateTime(2026, 11, 5, 14, 30);

  group('Movement', () {
    final movement = Movement(
      id: 1,
      amount: -1350.50,
      description: 'Súper',
      category: 'Comida',
      date: date,
      note: 'Despensa',
    );

    test('toMap y fromMap conservan todos los campos', () {
      final map = movement.toMap();
      expect(map, {
        'id': 1,
        'amount': -1350.50,
        'description': 'Súper',
        'category': 'Comida',
        'date': '2026-11-05T14:30:00.000',
        'note': 'Despensa',
      });
      expect(Movement.fromMap(map), movement);
    });

    test('toMap omite id cuando no se ha guardado', () {
      final nuevo = movement.copyWith().toMap()..remove('id');
      final sinId = Movement.fromMap(nuevo);
      expect(sinId.id, isNull);
      expect(sinId.toMap().containsKey('id'), isFalse);
    });

    test('fromMap acepta montos enteros', () {
      final m = Movement.fromMap({
        'amount': -280,
        'description': 'Transporte',
        'category': 'Transporte',
        'date': date.toIso8601String(),
      });
      expect(m.amount, -280.0);
      expect(m.note, isNull);
    });

    test('copyWith conserva los campos que no cambian', () {
      final copia = movement.copyWith(amount: -99);
      expect(copia.amount, -99);
      expect(copia.id, movement.id);
      expect(copia.description, movement.description);
      expect(copia.category, movement.category);
      expect(copia.date, movement.date);
      expect(copia.note, movement.note);
      expect(movement.copyWith(), movement);
    });

    test('copyWith puede quitar la nota', () {
      expect(movement.copyWith(clearNote: true).note, isNull);
    });

    test('isExpense y absAmount', () {
      expect(movement.isExpense, isTrue);
      expect(movement.absAmount, 1350.50);
      expect(movement.copyWith(amount: 10).isExpense, isFalse);
    });
  });

  group('Income', () {
    final income = Income(
      id: 7,
      name: 'Salario',
      amount: 12000,
      date: date,
      note: 'Quincena',
    );

    test('toMap y fromMap conservan todos los campos', () {
      final map = income.toMap();
      expect(map, {
        'id': 7,
        'name': 'Salario',
        'amount': 12000.0,
        'date': '2026-11-05T14:30:00.000',
        'note': 'Quincena',
      });
      expect(Income.fromMap(map), income);
    });

    test('copyWith conserva los campos que no cambian', () {
      final copia = income.copyWith(name: 'Bono');
      expect(copia.name, 'Bono');
      expect(copia.id, income.id);
      expect(copia.amount, income.amount);
      expect(copia.date, income.date);
      expect(copia.note, income.note);
      expect(income.copyWith(), income);
      expect(income.copyWith(clearNote: true).note, isNull);
    });

    test('toMovement produce un movimiento positivo de categoría Ingreso', () {
      final m = income.toMovement();
      expect(m.amount, 12000);
      expect(m.isExpense, isFalse);
      expect(m.description, 'Salario');
      expect(m.category, Income.category);
      expect(m.date, date);
    });
  });

  group('FormatUtils', () {
    test('montos', () {
      expect(FormatUtils.money(-1350.5), r'$1,350.50');
      expect(FormatUtils.moneyCompact(12000), r'$12,000');
    });

    test('fechas', () {
      expect(FormatUtils.monthYear(date), 'noviembre 2026');
      expect(FormatUtils.shortDate(date), '5 nov');
      expect(FormatUtils.fullDate(date), '05/11/2026');
      expect(FormatUtils.isSameMonth(date, DateTime(2026, 11)), isTrue);
      expect(FormatUtils.isSameMonth(date, DateTime(2025, 11)), isFalse);
    });
  });
}
