import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'format_utils.dart';

/// Textos de navegación, Inicio, Movimientos y Ajustes en español e
/// inglés (HU-25, HU-28).
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
    required this.cardsHeader,
    required this.noCards,
    required this.addCard,
    required this.cardAvailable,
    required this.emptyHistory,
    required this.incomeKind,
    required this.settingsTitle,
    required this.preferences,
    required this.currency,
    required this.language,
    required this.currencyNames,
    required this.languageNames,
    required this.settingsSaveError,
    required this.dataSection,
    required this.exportXlsx,
    required this.importCsv,
    required this.exportEmpty,
    required this.exportError,
    required this.importInvalidTitle,
    required this.importConfirmTitle,
    required this.importConfirmBody,
    required this.cancel,
    required this.replace,
    required this.importDone,
    required this.importError,
    required this.importTooLarge,
    required this.close,
    required this.deleteData,
    required this.deleteDataTitle,
    required this.deleteDataBody,
    required this.delete,
    required this.dataDeleted,
    required this.deleteDataError,
    required this.accountantSection,
    required this.accountantPreview,
    required this.accountantPreviewValue,
    required this.sampleBanner,
    required this.clientsTitle,
    required this.authorizedOn,
    required this.noClients,
    required this.cardPayments,
    required this.viewMovements,
    required this.historyTitle,
    required this.readOnly,
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

  /// Sección de tarjetas en Inicio (S2-13).
  final String cardsHeader;
  final String noCards;
  final String addCard;

  /// Texto tras el crédito disponible de cada tarjeta.
  final String cardAvailable;
  final String emptyHistory;
  final String incomeKind;
  final String settingsTitle;
  final String preferences;
  final String currency;
  final String language;
  final Map<String, String> currencyNames;
  final Map<String, String> languageNames;
  final String settingsSaveError;

  // Respaldo (HU-26, HU-27). Los textos con {a}, {b}… se completan con
  // [fill].
  final String dataSection;
  final String exportXlsx;
  final String importCsv;
  final String exportEmpty;
  final String exportError;
  final String importInvalidTitle;
  final String importConfirmTitle;
  final String importConfirmBody;
  final String cancel;
  final String replace;
  final String importDone;
  final String importError;
  final String importTooLarge;
  final String close;

  // Borrar datos (HU-28).
  final String deleteData;
  final String deleteDataTitle;
  final String deleteDataBody;
  final String delete;
  final String dataDeleted;
  final String deleteDataError;

  // Maqueta de la vista de contador con datos de ejemplo (S2-19).
  final String accountantSection;
  final String accountantPreview;
  final String accountantPreviewValue;
  final String sampleBanner;
  final String clientsTitle;
  final String authorizedOn;
  final String noClients;
  final String cardPayments;
  final String viewMovements;
  final String historyTitle;
  final String readOnly;

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
    cardsHeader: 'TARJETAS',
    noCards: 'Aún no registras tarjetas.',
    addCard: 'Agregar tarjeta',
    cardAvailable: 'disponible',
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
    dataSection: 'DATOS',
    exportXlsx: 'Exportar a Excel',
    importCsv: 'Importar CSV',
    exportEmpty: 'No hay registros; el archivo solo tiene encabezados',
    exportError: 'No se pudo crear el archivo. Intenta de nuevo.',
    importInvalidTitle: 'No se puede importar',
    importConfirmTitle: '¿Reemplazar tus datos?',
    importConfirmBody:
        'Se reemplazarán tus {a} movimientos e {b} ingresos por {c} movimientos y {d} ingresos del archivo. Esta acción no se puede deshacer.',
    cancel: 'Cancelar',
    replace: 'Reemplazar',
    importDone: 'Se importaron {a} movimientos y {b} ingresos',
    importError: 'No se pudo importar. Tus datos no cambiaron.',
    importTooLarge: 'El archivo pesa más de 5 MB.',
    close: 'Cerrar',
    deleteData: 'Borrar datos',
    deleteDataTitle: '¿Borrar todos tus datos?',
    deleteDataBody:
        'Se eliminarán movimientos, ingresos, tarjetas y deudas de este '
        'dispositivo. Tus categorías y ajustes se conservan. Esta acción '
        'no se puede deshacer.',
    delete: 'Borrar',
    dataDeleted: 'Datos borrados',
    deleteDataError: 'No se pudieron borrar los datos. No se borró nada.',
    accountantSection: 'CONTADOR',
    accountantPreview: 'Vista de contador',
    accountantPreviewValue: 'Maqueta',
    sampleBanner:
        'Maqueta con datos de ejemplo. No está conectada a cuentas reales.',
    clientsTitle: 'Clientes autorizados',
    authorizedOn: 'Autorizó el {a}',
    noClients: 'Aún no tienes clientes autorizados.',
    cardPayments: 'Pagos de tarjeta',
    viewMovements: 'Ver movimientos',
    historyTitle: 'Movimientos',
    readOnly: 'Solo lectura: no se puede crear, editar ni borrar.',
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
    cardsHeader: 'CARDS',
    noCards: 'No cards yet.',
    addCard: 'Add card',
    cardAvailable: 'available',
    emptyHistory: 'No activity yet.\nTap + to add one.',
    incomeKind: 'income',
    settingsTitle: 'Settings',
    preferences: 'PREFERENCES',
    currency: 'Currency',
    language: 'Language',
    currencyNames: {'MXN': 'Mexican peso', 'USD': 'US dollar', 'EUR': 'Euro'},
    languageNames: {'es': 'Español', 'en': 'English'},
    settingsSaveError: 'Could not save the setting. Try again.',
    dataSection: 'DATA',
    exportXlsx: 'Export to Excel',
    importCsv: 'Import CSV',
    exportEmpty: 'No records; the file only has headers',
    exportError: 'Could not create the file. Try again.',
    importInvalidTitle: 'Cannot import',
    importConfirmTitle: 'Replace your data?',
    importConfirmBody:
        'Your {a} movements and {b} incomes will be replaced by {c} movements and {d} incomes from the file. This cannot be undone.',
    cancel: 'Cancel',
    replace: 'Replace',
    importDone: 'Imported {a} movements and {b} incomes',
    importError: 'Could not import. Your data did not change.',
    importTooLarge: 'The file is larger than 5 MB.',
    close: 'Close',
    deleteData: 'Delete data',
    deleteDataTitle: 'Delete all your data?',
    deleteDataBody:
        'Activity, income, cards and debts will be removed from this '
        'device. Your categories and settings are kept. This cannot be '
        'undone.',
    delete: 'Delete',
    dataDeleted: 'Data deleted',
    deleteDataError: 'Could not delete the data. Nothing was deleted.',
    accountantSection: 'ACCOUNTANT',
    accountantPreview: 'Accountant view',
    accountantPreviewValue: 'Mock-up',
    sampleBanner: 'Mock-up with sample data. Not connected to real accounts.',
    clientsTitle: 'Authorized clients',
    authorizedOn: 'Authorized on {a}',
    noClients: 'You have no authorized clients yet.',
    cardPayments: 'Card payments',
    viewMovements: 'View activity',
    historyTitle: 'Activity',
    readOnly: 'Read only: nothing can be created, edited or deleted.',
  );

  /// Reemplaza `{a}`, `{b}`, `{c}`, `{d}` de [template] por [values].
  static String fill(String template, List<Object> values) {
    var out = template;
    const keys = ['{a}', '{b}', '{c}', '{d}'];
    for (var i = 0; i < values.length && i < keys.length; i++) {
      out = out.replaceAll(keys[i], '${values[i]}');
    }
    return out;
  }

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
