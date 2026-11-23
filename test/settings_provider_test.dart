// S2-05 · Ajustes de moneda e idioma (HU-24, HU-25).
//
// Usa SQLite real en un archivo temporal (sqflite_common_ffi). "Reabrir
// la app" se simula cerrando la base y cargando un provider nuevo sobre
// el mismo archivo.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:kopay/utils/validators.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String path;
  late DatabaseHelper db;
  late SettingsProvider provider;

  DatabaseHelper openDb() =>
      DatabaseHelper.withFactory(databaseFactoryFfi, path);

  Future<SettingsProvider> reopen() async {
    await db.close();
    db = openDb();
    final fresh = SettingsProvider(database: db);
    await fresh.load();
    return fresh;
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kopay_settings_test');
    path = '${tempDir.path}/${DatabaseHelper.fileName}';
    db = openDb();
    provider = SettingsProvider(database: db);
    await provider.load();
  });

  tearDown(() async {
    FormatUtils.configure(currency: 'MXN', language: 'es');
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  test('INT-SET-01 · HU-24 · HU-25 · una base nueva usa MXN y español', () {
    expect(provider.isLoaded, isTrue);
    expect(provider.currency, 'MXN');
    expect(provider.language, 'es');
    expect(FormatUtils.money(10), r'$10.00');
  });

  test('INT-SET-02 · HU-24 · la moneda cambia el símbolo y persiste', () async {
    var notifications = 0;
    provider.addListener(() => notifications++);

    await provider.setCurrency('EUR');
    expect(provider.currency, 'EUR');
    expect(FormatUtils.money(1234.5), '€1,234.50');
    expect(notifications, 1);
    expect(await db.getSetting(SettingsProvider.currencyKey), 'EUR');

    FormatUtils.configure(currency: 'MXN'); // como al arrancar la app
    final fresh = await reopen();
    expect(fresh.currency, 'EUR');
    expect(FormatUtils.money(1234.5), '€1,234.50');
  });

  test('INT-SET-03 · HU-25 · el idioma cambia los meses y persiste', () async {
    await provider.setLanguage('en');
    expect(provider.language, 'en');
    expect(FormatUtils.monthYear(DateTime(2026, 11)), 'november 2026');
    expect(FormatUtils.shortDate(DateTime(2026, 10, 8)), '8 oct');

    FormatUtils.configure(language: 'es');
    final fresh = await reopen();
    expect(fresh.language, 'en');
    expect(FormatUtils.monthName(DateTime(2026, 1)), 'january');
  });

  test('INT-SET-04 · HU-24 · HU-25 · rechaza valores no disponibles', () async {
    expect(
      () => provider.setCurrency('JPY'),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => provider.setLanguage('fr'),
      throwsA(isA<ValidationException>()),
    );
    expect(provider.currency, 'MXN');
    expect(provider.language, 'es');
  });

  test(
    'INT-SET-05 · HU-24 · HU-25 · un valor guardado desconocido usa el predeterminado',
    () async {
      await db.setSetting(SettingsProvider.currencyKey, 'XXX');
      await db.setSetting(SettingsProvider.languageKey, 'zz');
      final fresh = await reopen();
      expect(fresh.currency, 'MXN');
      expect(fresh.language, 'es');
    },
  );

  test('INT-SET-06 · HU-24 · elegir la misma moneda no notifica', () async {
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.setCurrency('MXN');
    expect(notifications, 0);
  });

  test('UT-29 · HU-24 · formato compacto con el símbolo configurado', () {
    FormatUtils.configure(currency: 'USD');
    expect(FormatUtils.moneyCompact(1234.5), r'US$1,235');
  });

  test('UT-59 · HU-24 · el importe se muestra en valor absoluto', () {
    FormatUtils.configure(currency: 'EUR');
    expect(FormatUtils.money(-123.45), '€123.45');
  });
}
