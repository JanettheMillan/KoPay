// S2-06 · Exportar XLSX e importar CSV desde Ajustes (HU-26, HU-27).
//
// Recorre la app completa. La base es una versión en memoria para que la
// interfaz no espere a SQLite, y los selectores del sistema se
// reemplazan con [FakeBackupPlatform].

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/models/income_model.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/services/backup_platform.dart';
import 'package:kopay/services/backup_service.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Movimientos, ingresos y ajustes en memoria.
class MemoryDb extends DatabaseHelper {
  MemoryDb() : super.withFactory(databaseFactoryFfi, ':memory:');

  final Map<String, String> settings = Map.of(DatabaseHelper.defaultSettings);
  List<Movement> movements = [];
  List<Income> incomes = [];
  bool failReplace = false;

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async =>
      settings[key] = value;

  @override
  Future<List<Movement>> getMovements({DateTime? month}) async =>
      [...movements]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<List<Income>> getIncomes({DateTime? month}) async =>
      [...incomes]..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> replaceFinancialData(
    List<Movement> newMovements,
    List<Income> newIncomes,
  ) async {
    if (failReplace) throw Exception('disco lleno');
    var id = 1;
    movements = [for (final m in newMovements) m.copyWith(id: id++)];
    incomes = [for (final i in newIncomes) i.copyWith(id: id++)];
  }
}

class FakeBackupPlatform implements BackupPlatform {
  Uint8List? csv;
  Object? pickError;
  Object? shareError;
  Uint8List? sharedBytes;
  String? sharedName;

  @override
  Future<Uint8List?> pickCsv() async {
    if (pickError != null) throw pickError!;
    return csv;
  }

  @override
  Future<void> shareXlsx(Uint8List bytes, String fileName) async {
    if (shareError != null) throw shareError!;
    sharedBytes = bytes;
    sharedName = fileName;
  }
}

void main() {
  late MemoryDb db;
  late FakeBackupPlatform platform;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime d) => d.toIso8601String().substring(0, 10);

  setUp(() {
    db = MemoryDb()
      ..movements = [
        Movement(
          id: 1,
          amount: -99,
          description: 'Dato viejo',
          category: 'Otros',
          date: today,
        ),
      ];
    platform = FakeBackupPlatform();
    BackupPlatform.instance = platform;
  });

  tearDown(() => BackupPlatform.instance = DeviceBackupPlatform());

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider(database: db);
    final categories = CategoryProvider(database: db);
    final movements = MovementProvider(database: db);
    final incomes = IncomeProvider(database: db);
    await settings.load();
    await categories.load();
    await movements.load();
    await incomes.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseHelper>.value(value: db),
          ChangeNotifierProvider.value(value: movements),
          ChangeNotifierProvider.value(value: incomes),
          ChangeNotifierProvider.value(value: categories),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: const KopayApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Uint8List csvBytes(String text) => Uint8List.fromList(utf8.encode(text));

  final validCsv =
      'tipo,fecha,importe,descripcion,categoria,nota\n'
      'movimiento,${iso(today)},-250.50,Súper,Comida,\n'
      'movimiento,${iso(today)},-80,Cine,Diversión nueva,\n'
      'ingreso,${iso(today)},12000,Quincena,,\n';

  testWidgets('UI-RES-01 · HU-26 · exportar comparte un XLSX con los '
      'registros', (tester) async {
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-export');

    expect(platform.sharedName, BackupService.fileName(DateTime.now()));
    final book = Excel.decodeBytes(platform.sharedBytes!);
    expect(book[BackupService.movementsSheet].maxRows, 2);
    expect(
      find.text('No hay registros; el archivo solo tiene encabezados'),
      findsNothing,
    );
  });

  testWidgets('UI-RES-02 · HU-26 · sin registros avisa; si falla muestra '
      'error', (tester) async {
    db.movements = [];
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-export');
    expect(platform.sharedBytes, isNotNull);
    expect(
      find.text('No hay registros; el archivo solo tiene encabezados'),
      findsOneWidget,
    );

    platform.shareError = Exception('sin espacio');
    ScaffoldMessenger.of(
      tester.element(find.byType(NavigationBar)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await tapKey(tester, 'settings-export');
    expect(
      find.text('No se pudo crear el archivo. Intenta de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('IMP-01 · IMP-08 · HU-27 · confirmar reemplaza, muestra los '
      'datos y agrega la categoría nueva', (tester) async {
    platform.csv = csvBytes(validCsv);
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-import');

    expect(
      find.text(
        'Se reemplazarán tus 1 movimientos e 0 ingresos por 2 movimientos '
        'y 1 ingresos del archivo. Esta acción no se puede deshacer.',
      ),
      findsOneWidget,
    );
    await tapKey(tester, 'import-confirm');

    expect(
      find.text('Se importaron 2 movimientos y 1 ingresos'),
      findsOneWidget,
    );
    expect(db.movements.map((m) => m.description), ['Súper', 'Cine']);
    expect(db.incomes.single.name, 'Quincena');

    final categories = Provider.of<CategoryProvider>(
      tester.element(find.byType(NavigationBar)),
      listen: false,
    );
    expect(categories.categories, contains('Diversión nueva'));

    await goTo(tester, 'Movimientos');
    expect(find.text('Súper'), findsOneWidget);
    expect(find.text('Dato viejo'), findsNothing);
  });

  testWidgets('IMP-03 · HU-27 · cancelar la confirmación conserva los '
      'datos', (tester) async {
    platform.csv = csvBytes(validCsv);
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-import');
    await tapKey(tester, 'import-cancel');

    expect(db.movements.map((m) => m.description), ['Dato viejo']);
    await goTo(tester, 'Movimientos');
    expect(find.text('Dato viejo'), findsOneWidget);
  });

  testWidgets('IMP-04 · HU-27 · un archivo con errores muestra fila y '
      'motivo y no cambia nada', (tester) async {
    platform.csv = csvBytes(
      'tipo,fecha,importe,descripcion,categoria,nota\n'
      'movimiento,2026-02-30,-80,Camión,Transporte,\n',
    );
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-import');

    expect(find.text('No se puede importar'), findsOneWidget);
    expect(find.textContaining('Fila 2: fecha imposible'), findsOneWidget);
    expect(find.byKey(const Key('import-confirm')), findsNothing);
    expect(db.movements.map((m) => m.description), ['Dato viejo']);
  });

  testWidgets('IMP-09 · HU-27 · si falla la escritura avisa y los datos no '
      'cambian', (tester) async {
    platform.csv = csvBytes(validCsv);
    db.failReplace = true;
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-import');
    await tapKey(tester, 'import-confirm');

    expect(
      find.text('No se pudo importar. Tus datos no cambiaron.'),
      findsOneWidget,
    );
    expect(db.movements.map((m) => m.description), ['Dato viejo']);
  });

  testWidgets('HU-27 · cerrar el selector sin elegir no hace nada', (
    tester,
  ) async {
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-import');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('HU-27 · archivo de más de 5 MB avisa', (tester) async {
    platform.pickError = const FileTooLargeException();
    await openApp(tester);
    await goTo(tester, 'Ajustes');
    await tapKey(tester, 'settings-import');
    expect(find.text('El archivo pesa más de 5 MB.'), findsOneWidget);
  });
}
