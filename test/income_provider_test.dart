import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper db;
  late IncomeProvider provider;
  late int notifications;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kopay_income_test');
    db = DatabaseHelper.withFactory(
      databaseFactoryFfi,
      '${tempDir.path}/${DatabaseHelper.fileName}',
    );
    provider = IncomeProvider(database: db);
    notifications = 0;
    provider.addListener(() => notifications++);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  Income ingreso(String name, DateTime date, {double amount = 12000}) =>
      Income(name: name, amount: amount, date: date, note: 'Quincena');

  test('load lee lo guardado en la base y notifica', () async {
    await db.insertIncome(ingreso('Salario', DateTime(2026, 11, 1)));

    await provider.load();

    expect(provider.isLoaded, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.incomes.single.name, 'Salario');
    expect(notifications, 2);
  });

  test('el ingreso se guarda, se consulta y notifica', () async {
    await provider.load();
    notifications = 0;

    final nuevo = ingreso('Salario', DateTime(2026, 11, 1));
    final guardado = await provider.add(nuevo);

    expect(guardado.id, isNotNull);
    expect(guardado, nuevo.copyWith(id: guardado.id));
    expect(provider.byId(guardado.id!), guardado);
    expect(await db.getIncome(guardado.id!), guardado);
    expect(notifications, 1);
  });

  test('la lista se ordena del más reciente al más antiguo', () async {
    await provider.add(ingreso('Oct', DateTime(2026, 10, 15)));
    await provider.add(ingreso('Nov 15', DateTime(2026, 11, 15)));
    await provider.add(ingreso('Nov 1', DateTime(2026, 11, 1)));

    expect(provider.incomes.map((i) => i.name), ['Nov 15', 'Nov 1', 'Oct']);
  });

  test('actualización y borrado cambian la base y notifican', () async {
    final guardado = await provider.add(
      ingreso('Salario', DateTime(2026, 11, 1)),
    );
    notifications = 0;

    final editado = guardado.copyWith(name: 'Bono', amount: 3000);
    await provider.update(editado);
    expect(provider.incomes, [editado]);
    expect(await db.getIncome(guardado.id!), editado);

    await provider.delete(guardado.id!);
    expect(provider.incomes, isEmpty);
    expect(provider.byId(guardado.id!), isNull);
    expect(await db.getIncomes(), isEmpty);

    expect(notifications, 2);
  });

  test('total del mes suma solo ese mes', () async {
    await provider.add(ingreso('Salario', DateTime(2026, 11, 1)));
    await provider.add(ingreso('Bono', DateTime(2026, 11, 20), amount: 1500.5));
    await provider.add(ingreso('Salario', DateTime(2026, 10, 1)));

    expect(provider.forMonth(DateTime(2026, 11)), hasLength(2));
    expect(provider.totalForMonth(DateTime(2026, 11)), 13500.5);
    expect(provider.totalForMonth(DateTime(2026, 12)), 0);
  });

  test('la lista expuesta no se puede modificar desde fuera', () async {
    await provider.add(ingreso('Salario', DateTime(2026, 11, 1)));
    expect(() => provider.incomes.clear(), throwsUnsupportedError);
  });

  testWidgets('los widgets suscritos se reconstruyen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Consumer<IncomeProvider>(
            builder: (_, p, _) => Text('${p.incomes.length} ingresos'),
          ),
        ),
      ),
    );
    expect(find.text('0 ingresos'), findsOneWidget);

    await tester.runAsync(
      () => provider.add(ingreso('Salario', DateTime(2026, 11, 1))),
    );
    await tester.pump();

    expect(find.text('1 ingresos'), findsOneWidget);
  });
}
