import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../utils/format_utils.dart';
import '../utils/validators.dart';

/// Moneda e idioma elegidos en Ajustes.
///
/// Se guardan en la tabla `settings` (claves `currency` y `language`),
/// así que se conservan al volver a abrir la app. Cada cambio actualiza
/// [FormatUtils] para que montos y fechas usen la nueva configuración.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({DatabaseHelper? database})
    : _db = database ?? DatabaseHelper.instance;

  static const String currencyKey = 'currency';
  static const String languageKey = 'language';

  final DatabaseHelper _db;

  String _currency = FormatUtils.defaultCurrency;
  String _language = FormatUtils.defaultLanguage;
  bool _loaded = false;

  /// Moneda activa: `MXN`, `USD` o `EUR`.
  String get currency => _currency;

  /// Idioma activo: `es` o `en`.
  String get language => _language;

  /// `true` después de la primera carga.
  bool get isLoaded => _loaded;

  /// Lee la moneda y el idioma guardados. Un valor desconocido se
  /// reemplaza por el predeterminado.
  Future<void> load() async {
    final currency = await _db.getSetting(currencyKey);
    final language = await _db.getSetting(languageKey);
    _currency = FormatUtils.currencySymbols.containsKey(currency)
        ? currency!
        : FormatUtils.defaultCurrency;
    _language = FormatUtils.languages.contains(language)
        ? language!
        : FormatUtils.defaultLanguage;
    _loaded = true;
    _apply();
  }

  /// Guarda la moneda. Lanza [ValidationException] si no es MXN, USD
  /// ni EUR.
  Future<void> setCurrency(String value) async {
    if (!FormatUtils.currencySymbols.containsKey(value)) {
      throw ValidationException('Moneda no disponible: $value');
    }
    if (value == _currency) return;
    await _db.setSetting(currencyKey, value);
    _currency = value;
    _apply();
  }

  /// Guarda el idioma. Lanza [ValidationException] si no es `es` ni `en`.
  Future<void> setLanguage(String value) async {
    if (!FormatUtils.languages.contains(value)) {
      throw ValidationException('Idioma no disponible: $value');
    }
    if (value == _language) return;
    await _db.setSetting(languageKey, value);
    _language = value;
    _apply();
  }

  void _apply() {
    FormatUtils.configure(currency: _currency, language: _language);
    notifyListeners();
  }
}
