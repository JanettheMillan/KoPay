import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'format_utils.dart';

/// Textos de navegación, Inicio, Movimientos y Ajustes en español e
/// inglés (HU-25).
///
/// `AppStrings.of(context)` devuelve los del idioma elegido en Ajustes y
/// hace que el widget se redibuje cuando el idioma cambia.
class AppStrings {
  const AppStrings._({
    required this.navHome,
    required this.navMovements,
    required this.navSettings,
    required this.add,
    required this.addTitle,
    required this.addMovement,
    required this.addMovementHint,
    required this.addIncome,
    required this.addIncomeHint,
    required this.expenseSaved,
    required this.entrySaved,
    required this.incomeSaved,
    required this.monthBalance,
    required this.income,
    required this.expenses,
    required this.movementsHeader,
    required this.noMovementsMonth,
    required this.emptyHistory,
    required this.incomeKind,
    required this.settingsTitle,
    required this.preferences,
    required this.currency,
    required this.language,
    required this.currencyNames,
    required this.languageNames,
    required this.settingsSaveError,
  });

  final String navHome;
  final String navMovements;
  final String navSettings;
  final String add;
  final String addTitle;
  final String addMovement;
  final String addMovementHint;
  final String addIncome;
  final String addIncomeHint;
  final String expenseSaved;
  final String entrySaved;
  final String incomeSaved;
  final String monthBalance;
  final String income;
  final String expenses;
  final String movementsHeader;
  final String noMovementsMonth;
  final String emptyHistory;
  final String incomeKind;
  final String settingsTitle;
  final String preferences;
  final String currency;
  final String language;
  final Map<String, String> currencyNames;
  final Map<String, String> languageNames;
  final String settingsSaveError;

  static const AppStrings es = AppStrings._(
    navHome: 'Inicio',
    navMovements: 'Movimientos',
    navSettings: 'Ajustes',
    add: 'Agregar',
    addTitle: '¿Qué quieres registrar?',
    addMovement: 'Gasto o movimiento',
    addMovementHint: 'Compras, pagos',
    addIncome: 'Ingreso',
    addIncomeHint: 'Salario, bonos, ventas',
    expenseSaved: 'Gasto guardado',
    entrySaved: 'Entrada guardada',
    incomeSaved: 'Ingreso guardado',
    monthBalance: 'BALANCE DEL MES',
    income: 'Ingresos',
    expenses: 'Gastos',
    movementsHeader: 'MOVIMIENTOS',
    noMovementsMonth: 'Sin movimientos este mes.',
    emptyHistory: 'Aún no hay movimientos.\nToca + para registrar uno.',
    incomeKind: 'ingreso',
    settingsTitle: 'Ajustes',
    preferences: 'PREFERENCIAS',
    currency: 'Moneda',
    language: 'Idioma',
    currencyNames: {
      'MXN': 'Peso mexicano',
      'USD': 'Dólar estadounidense',
      'EUR': 'Euro',
    },
    languageNames: {'es': 'Español', 'en': 'English'},
    settingsSaveError: 'No se pudo guardar el ajuste. Intenta de nuevo.',
  );

  static const AppStrings en = AppStrings._(
    navHome: 'Home',
    navMovements: 'Activity',
    navSettings: 'Settings',
    add: 'Add',
    addTitle: 'What do you want to record?',
    addMovement: 'Expense or movement',
    addMovementHint: 'Purchases, payments',
    addIncome: 'Income',
    addIncomeHint: 'Salary, bonuses, sales',
    expenseSaved: 'Expense saved',
    entrySaved: 'Entry saved',
    incomeSaved: 'Income saved',
    monthBalance: 'MONTH BALANCE',
    income: 'Income',
    expenses: 'Expenses',
    movementsHeader: 'ACTIVITY',
    noMovementsMonth: 'No activity this month.',
    emptyHistory: 'No activity yet.\nTap + to add one.',
    incomeKind: 'income',
    settingsTitle: 'Settings',
    preferences: 'PREFERENCES',
    currency: 'Currency',
    language: 'Language',
    currencyNames: {'MXN': 'Mexican peso', 'USD': 'US dollar', 'EUR': 'Euro'},
    languageNames: {'es': 'Español', 'en': 'English'},
    settingsSaveError: 'Could not save the setting. Try again.',
  );

  /// Textos para un código de idioma; cualquier otro usa español.
  static AppStrings forLanguage(String language) => language == 'en' ? en : es;

  /// Textos del idioma activo. Si hay [SettingsProvider], el widget se
  /// redibuja al cambiar el idioma.
  static AppStrings of(BuildContext context) {
    final settings = context.watch<SettingsProvider?>();
    return forLanguage(settings?.language ?? FormatUtils.language);
  }

  /// Textos del idioma activo sin escuchar cambios, para usar dentro de
  /// manejadores de eventos (`onPressed`, `onTap`).
  static AppStrings read(BuildContext context) {
    final settings = Provider.of<SettingsProvider?>(context, listen: false);
    return forLanguage(settings?.language ?? FormatUtils.language);
  }
}
