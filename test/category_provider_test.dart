// S2-04 · Administración de categorías (HU-10, HU-11, HU-12).
//
// Usa SQLite real en un archivo temporal (sqflite_common_ffi). "Reabrir
// la app" se simula cerrando la base y creando un provider nuevo sobre
// el mismo archivo.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/utils/validators.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String path;
  late DatabaseHelper db;
  late CategoryProvider provider;

  DatabaseHelper openDb() =>
      DatabaseHelper.withFactory(databaseFactoryFfi, path);

  /// Cierra la base y carga un provider nuevo sobre el mismo archivo.
  Future<CategoryProvider> reopen() async {
    await db.close();
    db = openDb();
    final fresh = CategoryProvider(database: db);
    await fresh.load();
    return fresh;
  }

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kopay_categories_test');
    path = '${tempDir.path}/${DatabaseHelper.fileName}';
    db = openDb();
    provider = CategoryProvider(database: db);
    await provider.load();
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
  });

  group('HU-10 · Usar categorías', () {
    test(
      'INT-CAT-01 · HU-10 · una base nueva carga las categorías iniciales',
      () {
        expect(provider.isLoaded, isTrue);
        expect(provider.categories, DatabaseHelper.defaultCategories);
      },
    );

    test(
      'INT-CAT-02 · HU-10 · un valor dañado se reemplaza por las iniciales',
      () async {
        await db.setSetting(CategoryProvider.settingsKey, 'no es json');
        final fresh = await reopen();
        expect(fresh.categories, DatabaseHelper.defaultCategories);
        expect(
          jsonDecode((await db.getSetting(CategoryProvider.settingsKey))!),
          DatabaseHelper.defaultCategories,
        );
      },
    );

    test(
      'INT-CAT-03 · HU-10 · la búsqueda ignora mayúsculas, acentos y espacios',
      () async {
        await provider.add('Educación');
        expect(provider.search('  TRANS '), ['Transporte']);
        expect(provider.search('educacion'), ['Educación']);
        expect(provider.search(''), provider.categories);
        expect(provider.search('zzz'), isEmpty);
      },
    );
  });

  group('HU-11 · Crear categorías', () {
    test(
      'INT-CAT-04 · HU-11 · la categoría nueva persiste al reabrir',
      () async {
        final name = await provider.add('  Mascotas ');
        expect(name, 'Mascotas');
        expect(provider.categories.last, 'Mascotas');

        final fresh = await reopen();
        expect(fresh.categories, contains('Mascotas'));
      },
    );

    test(
      'INT-CAT-05 · HU-11 · rechaza nombres vacíos, repetidos o muy largos',
      () async {
        expect(
          () => provider.add('   '),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              CategoryProvider.emptyName,
            ),
          ),
        );
        expect(
          () => provider.add(' comida '),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              CategoryProvider.duplicated,
            ),
          ),
        );
        expect(
          () => provider.add('x' * (CategoryProvider.maxLength + 1)),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.message,
              'message',
              CategoryProvider.tooLong,
            ),
          ),
        );
        expect(provider.categories, DatabaseHelper.defaultCategories);
      },
    );
  });

  group('HU-12 · Administrar categorías', () {
    test(
      'INT-CAT-06 · HU-12 · renombrar conserva la posición y persiste',
      () async {
        final index = provider.categories.indexOf('Salud');
        await provider.rename('Salud', 'Farmacia');

        expect(provider.categories[index], 'Farmacia');
        expect(provider.categories, isNot(contains('Salud')));

        final fresh = await reopen();
        expect(fresh.categories[index], 'Farmacia');
      },
    );

    test(
      'INT-CAT-07 · HU-12 · renombrar con el mismo nombre o a uno existente',
      () async {
        await provider.rename('Salud', 'Salud'); // permitido, sin cambios
        expect(provider.categories, DatabaseHelper.defaultCategories);
        expect(
          () => provider.rename('Salud', 'comida'),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => provider.rename('No existe', 'Algo'),
          throwsA(isA<ValidationException>()),
        );
      },
    );

    test(
      'INT-CAT-08 · HU-12 · eliminar quita la categoría y persiste',
      () async {
        var notifications = 0;
        provider.addListener(() => notifications++);

        await provider.remove('Vivienda');
        expect(provider.categories, isNot(contains('Vivienda')));
        expect(notifications, 1);

        await provider.remove('No existe'); // no hace nada
        expect(notifications, 1);

        final fresh = await reopen();
        expect(fresh.categories, isNot(contains('Vivienda')));
        expect(
          fresh.categories.length,
          DatabaseHelper.defaultCategories.length - 1,
        );
      },
    );
  });
}
