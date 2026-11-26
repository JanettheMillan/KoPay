// Ambientes de la app (punto 5 de la §12 del manual; parte de S5-16, #102).
//
// La app toma la dirección de la API de config/*.json con
// --dart-define-from-file (S4-07, HU-31). El plan de pruebas no tiene casos
// de esto; CFG-01 a CFG-06 son pruebas nuevas, anotadas en el PR.
//
// CFG-06 compara lo que la app recibió al compilar con el archivo. Corre
// solo si se pasan el archivo y su nombre:
//   flutter test test/api_config_files_test.dart
//     --dart-define-from-file=config/prod.json --dart-define=CFG_FILE=prod.json

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/services/api_config.dart';

Map<String, dynamic> _leer(String nombre) =>
    jsonDecode(File('config/$nombre').readAsStringSync())
        as Map<String, dynamic>;

const _archivos = ['dev.json', 'dev-local.json', 'prod.json'];

void main() {
  test('CFG-01 · HU-31 · cada archivo es JSON con API_URL válida', () {
    for (final nombre in _archivos) {
      final config = _leer(nombre);
      expect(config['API_URL'], isA<String>(), reason: nombre);
      expect(
        () => ApiConfig.parse(config['API_URL'] as String),
        returnsNormally,
        reason: nombre,
      );
    }
  });

  test('CFG-02 · HU-31 · solo llevan la dirección: ningún secreto', () {
    for (final nombre in _archivos) {
      final config = _leer(nombre);
      expect(config.keys, ['API_URL'], reason: nombre);
      final texto = File('config/$nombre').readAsStringSync().toLowerCase();
      for (final palabra in [
        'secret',
        'token',
        'password',
        'pass',
        'database_url',
        'postgres',
      ]) {
        expect(texto, isNot(contains(palabra)), reason: '$nombre: $palabra');
      }
    }
  });

  test('CFG-03 · HU-31 · dev es el emulador de Android y coincide con el valor '
      'por defecto', () {
    expect(_leer('dev.json')['API_URL'], 'http://10.0.2.2:3000');
    expect(_leer('dev.json')['API_URL'], ApiConfig.defaultUrl);
    expect(_leer('dev-local.json')['API_URL'], 'http://localhost:3000');
  });

  test('CFG-04 · HU-31 · producción siempre va por https', () {
    final url = ApiConfig.parse(_leer('prod.json')['API_URL'] as String);

    expect(url.scheme, 'https');
  });

  test(
    'CFG-05 · HU-31 · producción ya tiene el dominio real de Railway',
    () {
      final url = ApiConfig.parse(_leer('prod.json')['API_URL'] as String);

      expect(url.host, isNot(endsWith('.invalid')));
    },
    skip:
        'Pendiente: el dominio sale del despliegue en Railway (#189). '
        'Quitar este skip al ponerlo en config/prod.json.',
  );

  test(
    'CFG-06 · HU-31 · la app recibe la API_URL del archivo al compilar',
    () {
      const archivo = String.fromEnvironment('CFG_FILE');
      expect(ApiConfig.apiUrl, _leer(archivo)['API_URL']);
    },
    skip: const bool.hasEnvironment('CFG_FILE')
        ? false
        : 'Solo con --dart-define-from-file=config/<archivo>.json '
              '--dart-define=CFG_FILE=<archivo>.json',
  );
}
