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
    required this.payments,
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
    required this.debtsHeader,
    required this.noDebts,
    required this.addDebt,
    required this.debtDue,
    required this.debtPaid,
    required this.debtPending,
    required this.debtOverdue,
    required this.debtTitle,
    required this.newDebt,
    required this.editDebt,
    required this.debtName,
    required this.debtNameHint,
    required this.debtMonthly,
    required this.debtRemaining,
    required this.debtDueDate,
    required this.debtStatus,
    required this.save,
    required this.saveChanges,
    required this.debtSaved,
    required this.debtDeleted,
    required this.deleteDebtTitle,
    required this.deleteDebtBody,
    required this.edit,
    required this.remove,
    required this.saveError,
    required this.removeError,
    required this.debtGone,
    required this.payCard,
    required this.payDebt,
    required this.cardUsed,
    required this.payAmount,
    required this.payAll,
    required this.payDate,
    required this.payNote,
    required this.recordPayment,
    required this.paymentSaved,
    required this.paymentsHeader,
    required this.noPayments,
    required this.nothingToPay,
    required this.paymentsKept,
    required this.cancelPayment,
    required this.cancelPaymentTitle,
    required this.cancelPaymentBody,
    required this.paymentCanceled,
    required this.cancelPaymentError,
    required this.deleteMovement,
    required this.deleteMovementTitle,
    required this.movementDeleted,
    required this.deleteIncome,
    required this.deleteIncomeTitle,
    required this.incomeDeleted,
    required this.deleteRecordBody,
    required this.loginTitle,
    required this.loginSubtitle,
    required this.signIn,
    required this.noAccount,
    required this.sessionExpiredNotice,
    required this.registerTitle,
    required this.registerSubtitle,
    required this.nameLabel,
    required this.nameHint,
    required this.emailLabel,
    required this.emailHint,
    required this.passwordLabel,
    required this.passwordHint,
    required this.showPassword,
    required this.hidePassword,
    required this.createAccount,
    required this.haveAccount,
    required this.accountantsTitle,
    required this.accountantsSubtitle,
    required this.accountantsEmpty,
    required this.authorizeAccountant,
    required this.accountantEmailLabel,
    required this.accountantEmailHint,
    required this.continueLabel,
    required this.authorizeConfirmTitle,
    required this.authorizeConfirmBody,
    required this.confirm,
    required this.accountantAuthorized,
    required this.grantedOn,
    required this.revoke,
    required this.revokeTitle,
    required this.revokeBody,
    required this.accessRevoked,
    required this.retry,
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
  final String payments;
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

  // Deudas: sección de Inicio, formulario y detalle (S2-14).
  final String debtsHeader;
  final String noDebts;
  final String addDebt;
  final String debtDue;
  final String debtPaid;
  final String debtPending;
  final String debtOverdue;
  final String debtTitle;
  final String newDebt;
  final String editDebt;
  final String debtName;
  final String debtNameHint;
  final String debtMonthly;
  final String debtRemaining;
  final String debtDueDate;
  final String debtStatus;
  final String save;
  final String saveChanges;
  final String debtSaved;
  final String debtDeleted;
  final String deleteDebtTitle;
  final String deleteDebtBody;
  final String edit;
  final String remove;
  final String saveError;
  final String removeError;
  final String debtGone;

  // Pagos de tarjeta y deuda (S2-15).
  final String payCard;
  final String payDebt;
  final String cardUsed;
  final String payAmount;
  final String payAll;
  final String payDate;
  final String payNote;
  final String recordPayment;
  final String paymentSaved;
  final String paymentsHeader;
  final String noPayments;
  final String nothingToPay;
  final String paymentsKept;

  // Anular un pago y devolver el saldo (D-10, HU-16, HU-06).
  final String cancelPayment;
  final String cancelPaymentTitle;
  final String cancelPaymentBody;
  final String paymentCanceled;
  final String cancelPaymentError;

  // Eliminar un movimiento o ingreso desde su hoja de edición (#185, HU-06).
  final String deleteMovement;
  final String deleteMovementTitle;
  final String movementDeleted;
  final String deleteIncome;
  final String deleteIncomeTitle;
  final String incomeDeleted;
  final String deleteRecordBody;

  // Iniciar sesión (S3-11). Los errores de cada campo vienen del contrato
  // y están en español (AuthValidators).
  final String loginTitle;
  final String loginSubtitle;
  final String signIn;
  final String noAccount;
  final String sessionExpiredNotice;
  // Crear cuenta (S3-10). Los errores de cada campo vienen del contrato
  // de la API y están en español (AuthValidators).
  final String registerTitle;
  final String registerSubtitle;
  final String nameLabel;
  final String nameHint;
  final String emailLabel;
  final String emailHint;
  final String passwordLabel;
  final String passwordHint;
  final String showPassword;
  final String hidePassword;
  final String createAccount;
  final String haveAccount;
  // Contadores autorizados (S4-11, HU-38, HU-41).
  final String accountantsTitle;
  final String accountantsSubtitle;
  final String accountantsEmpty;
  final String authorizeAccountant;
  final String accountantEmailLabel;
  final String accountantEmailHint;
  final String continueLabel;
  final String authorizeConfirmTitle;
  final String authorizeConfirmBody;
  final String confirm;
  final String accountantAuthorized;
  final String grantedOn;
  final String revoke;
  final String revokeTitle;
  final String revokeBody;
  final String accessRevoked;
  final String retry;

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
    payments: 'Pagos',
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
    debtsHeader: 'DEUDAS',
    noDebts: 'Aún no registras deudas.',
    addDebt: 'Agregar deuda',
    debtDue: 'Vence el {a}',
    debtPaid: 'Pagada',
    debtPending: 'Pendiente',
    debtOverdue: 'Vencida',
    debtTitle: 'Deuda',
    newDebt: 'Nueva deuda',
    editDebt: 'Editar deuda',
    debtName: 'Nombre',
    debtNameHint: 'Ej. Préstamo auto',
    debtMonthly: 'Mensualidad',
    debtRemaining: 'Saldo restante',
    debtDueDate: 'Próximo vencimiento',
    debtStatus: 'Estado',
    save: 'Guardar',
    saveChanges: 'Guardar cambios',
    debtSaved: 'Deuda guardada',
    debtDeleted: 'Deuda eliminada',
    deleteDebtTitle: '¿Eliminar deuda?',
    deleteDebtBody: 'Se eliminará "{a}". Esta acción no se puede deshacer.',
    edit: 'Editar',
    remove: 'Eliminar',
    saveError: 'No se pudo guardar. Intenta de nuevo.',
    removeError: 'No se pudo eliminar. Intenta de nuevo.',
    debtGone: 'La deuda ya no existe.',
    payCard: 'Pagar tarjeta',
    payDebt: 'Pagar deuda',
    cardUsed: 'Saldo usado',
    payAmount: 'Monto',
    payAll: 'Pagar todo',
    payDate: 'Fecha',
    payNote: 'Nota (opcional)',
    recordPayment: 'Registrar pago',
    paymentSaved: 'Pago registrado',
    paymentsHeader: 'PAGOS',
    noPayments: 'Sin pagos registrados.',
    nothingToPay: 'No hay saldo por pagar.',
    paymentsKept: 'Sus pagos se conservan en Movimientos.',
    cancelPayment: 'Anular pago',
    cancelPaymentTitle: '¿Anular este pago?',
    cancelPaymentBody: 'El saldo vuelve a como estaba.',
    paymentCanceled: 'Pago anulado',
    cancelPaymentError: 'No se pudo anular el pago. Intenta de nuevo.',
    deleteMovement: 'Eliminar movimiento',
    deleteMovementTitle: '¿Eliminar movimiento?',
    movementDeleted: 'Movimiento eliminado',
    deleteIncome: 'Eliminar ingreso',
    deleteIncomeTitle: '¿Eliminar ingreso?',
    incomeDeleted: 'Ingreso eliminado',
    deleteRecordBody:
        'Se eliminará "{a}" y se recalculará el resumen. Esta acción no se puede deshacer.',
    loginTitle: 'Iniciar sesión',
    loginSubtitle: 'Entra a tu cuenta de KoPay.',
    signIn: 'Entrar',
    noAccount: '¿No tienes cuenta? Crea una',
    sessionExpiredNotice: 'Tu sesión terminó. Inicia sesión otra vez.',
    registerTitle: 'Crear cuenta',
    registerSubtitle: 'Guarda tus finanzas en tu cuenta de KoPay.',
    nameLabel: 'Nombre',
    nameHint: 'Ej. Ana López',
    emailLabel: 'Correo',
    emailHint: 'tu@correo.com',
    passwordLabel: 'Contraseña',
    passwordHint: '8 o más, con letras y números',
    showPassword: 'Mostrar contraseña',
    hidePassword: 'Ocultar contraseña',
    createAccount: 'Crear cuenta',
    haveAccount: '¿Ya tienes cuenta? Inicia sesión',
    accountantsTitle: 'Contadores autorizados',
    accountantsSubtitle:
        'Pueden ver tu resumen y tu historial, sin cambiar nada.',
    accountantsEmpty: 'Todavía no autorizas a ningún contador.',
    authorizeAccountant: 'Autorizar contador',
    accountantEmailLabel: 'Correo del contador',
    accountantEmailHint: 'contador@correo.com',
    continueLabel: 'Continuar',
    authorizeConfirmTitle: '¿Autorizar a {a}?',
    authorizeConfirmBody:
        'Podrá ver tu resumen del mes y tu historial de movimientos. Es solo lectura: no podrá crear, editar ni borrar nada. Puedes retirarle el acceso cuando quieras.',
    confirm: 'Confirmar',
    accountantAuthorized: 'Contador autorizado',
    grantedOn: 'Autorizado el {a}',
    revoke: 'Revocar',
    revokeTitle: '¿Retirar el acceso a {a}?',
    revokeBody: 'Desde este momento no podrá ver tu resumen ni tu historial.',
    accessRevoked: 'Acceso retirado',
    retry: 'Reintentar',
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
    payments: 'Payments',
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
    debtsHeader: 'DEBTS',
    noDebts: 'No debts yet.',
    addDebt: 'Add debt',
    debtDue: 'Due {a}',
    debtPaid: 'Paid',
    debtPending: 'Pending',
    debtOverdue: 'Overdue',
    debtTitle: 'Debt',
    newDebt: 'New debt',
    editDebt: 'Edit debt',
    debtName: 'Name',
    debtNameHint: 'e.g. Car loan',
    debtMonthly: 'Monthly payment',
    debtRemaining: 'Remaining balance',
    debtDueDate: 'Next due date',
    debtStatus: 'Status',
    save: 'Save',
    saveChanges: 'Save changes',
    debtSaved: 'Debt saved',
    debtDeleted: 'Debt deleted',
    deleteDebtTitle: 'Delete debt?',
    deleteDebtBody: '"{a}" will be deleted. This cannot be undone.',
    edit: 'Edit',
    remove: 'Delete',
    saveError: 'Could not save. Try again.',
    removeError: 'Could not delete. Try again.',
    debtGone: 'This debt no longer exists.',
    payCard: 'Pay card',
    payDebt: 'Pay debt',
    cardUsed: 'Used balance',
    payAmount: 'Amount',
    payAll: 'Pay all',
    payDate: 'Date',
    payNote: 'Note (optional)',
    recordPayment: 'Record payment',
    paymentSaved: 'Payment recorded',
    paymentsHeader: 'PAYMENTS',
    noPayments: 'No payments yet.',
    nothingToPay: 'Nothing left to pay.',
    paymentsKept: 'Its payments stay in Activity.',
    cancelPayment: 'Void payment',
    cancelPaymentTitle: 'Void this payment?',
    cancelPaymentBody: 'The balance goes back to what it was.',
    paymentCanceled: 'Payment voided',
    cancelPaymentError: 'Could not void the payment. Try again.',
    deleteMovement: 'Delete movement',
    deleteMovementTitle: 'Delete movement?',
    movementDeleted: 'Movement deleted',
    deleteIncome: 'Delete income',
    deleteIncomeTitle: 'Delete income?',
    incomeDeleted: 'Income deleted',
    deleteRecordBody:
        '"{a}" will be deleted and the summary recalculated. This cannot be undone.',
    loginTitle: 'Sign in',
    loginSubtitle: 'Sign in to your KoPay account.',
    signIn: 'Sign in',
    noAccount: 'No account yet? Create one',
    sessionExpiredNotice: 'Your session ended. Please sign in again.',
    registerTitle: 'Create account',
    registerSubtitle: 'Keep your finances in your KoPay account.',
    nameLabel: 'Name',
    nameHint: 'e.g. Ana López',
    emailLabel: 'Email',
    emailHint: 'you@email.com',
    passwordLabel: 'Password',
    passwordHint: '8 or more, with letters and numbers',
    showPassword: 'Show password',
    hidePassword: 'Hide password',
    createAccount: 'Create account',
    haveAccount: 'Already have an account? Sign in',
    accountantsTitle: 'Authorized accountants',
    accountantsSubtitle:
        'They can see your summary and history, without changing anything.',
    accountantsEmpty: "You haven't authorized any accountant yet.",
    authorizeAccountant: 'Authorize accountant',
    accountantEmailLabel: "Accountant's email",
    accountantEmailHint: 'accountant@email.com',
    continueLabel: 'Continue',
    authorizeConfirmTitle: 'Authorize {a}?',
    authorizeConfirmBody:
        'They will see your monthly summary and your movement history. It is read-only: they cannot create, edit or delete anything. You can revoke access at any time.',
    confirm: 'Confirm',
    accountantAuthorized: 'Accountant authorized',
    grantedOn: 'Authorized on {a}',
    revoke: 'Revoke',
    revokeTitle: 'Revoke access for {a}?',
    revokeBody:
        'From now on they will not be able to see your summary or history.',
    accessRevoked: 'Access revoked',
    retry: 'Try again',
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
