import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../utils/validators.dart';

/// Estado de las categorías de gasto.
///
/// La lista se guarda como JSON en la tabla `settings` (clave
/// [settingsKey]), así que las altas, cambios de nombre y bajas se
/// conservan al volver a abrir la app.
class CategoryProvider extends ChangeNotifier {
  CategoryProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  static const String settingsKey = 'categories';

  static const String emptyName = 'Escribe el nombre de la categoría';
  static const String duplicated = 'Esa categoría ya existe';
  static const String tooLong = 'Usa máximo 30 caracteres';
  static const int maxLength = 30;

  final DatabaseHelper _db;

  List<String> _categories = List.of(DatabaseHelper.defaultCategories);
  bool _loaded = false;

  /// Categorías en el orden en que se muestran en el selector.
  List<String> get categories => List.unmodifiable(_categories);

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// Lee las categorías guardadas. Si no hay o el valor está dañado,
  /// usa las iniciales y las guarda.
  Future<void> load() async {
    final raw = await _db.getSetting(settingsKey);
    final stored = _decode(raw);
    if (stored == null) {
      _categories = List.of(DatabaseHelper.defaultCategories);
      await _persist();
    } else {
      _categories = stored;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Categorías cuyo nombre contiene [query], sin importar mayúsculas,
  /// acentos ni espacios a los lados.
  List<String> search(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return categories;
    return _categories.where((c) => _normalize(c).contains(q)).toList();
  }

  /// Mensaje de error para [name], o `null` si es válido. [current] es
  /// el nombre que se está editando, para permitir dejarlo igual.
  String? validate(String name, {String? current}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return emptyName;
    if (trimmed.length > maxLength) return tooLong;
    final exists = _categories.any(
      (c) => c != current && _normalize(c) == _normalize(trimmed),
    );
    return exists ? duplicated : null;
  }

  /// Agrega una categoría al final y devuelve su nombre limpio.
  /// Lanza [ValidationException] si el nombre no es válido.
  Future<String> add(String name) async {
    _check(validate(name));
    final trimmed = name.trim();
    _categories = [..._categories, trimmed];
    await _persist();
    notifyListeners();
    return trimmed;
  }

  /// Cambia el nombre de [oldName] y devuelve el nombre nuevo.
  /// Lanza [ValidationException] si el nombre no es válido.
  Future<String> rename(String oldName, String newName) async {
    final index = _categories.indexOf(oldName);
    if (index == -1) {
      throw ValidationException('No existe la categoría "$oldName"');
    }
    _check(validate(newName, current: oldName));
    final trimmed = newName.trim();
    _categories = [..._categories]..[index] = trimmed;
    await _persist();
    notifyListeners();
    return trimmed;
  }

  /// Quita la categoría. Los movimientos ya guardados conservan su texto.
  Future<void> remove(String name) async {
    if (!_categories.contains(name)) return;
    _categories = _categories.where((c) => c != name).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() =>
      _db.setSetting(settingsKey, jsonEncode(_categories));

  static void _check(String? error) {
    if (error != null) throw ValidationException(error);
  }

  static List<String>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      if (value is List) return value.whereType<String>().toList();
    } on FormatException {
      // Valor dañado: se reemplaza por las categorías iniciales.
    }
    return null;
  }

  static const _accents = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  /// Texto en minúsculas, sin acentos ni espacios a los lados.
  static String _normalize(String text) {
    final lower = text.trim().toLowerCase();
    final buffer = StringBuffer();
    for (final ch in lower.split('')) {
      buffer.write(_accents[ch] ?? ch);
    }
    return buffer.toString();
  }
}
