// S2-19 · Maqueta de la vista de contador con datos de ejemplo
// (HU-39, HU-40, HU-42).
//
// El plan de pruebas no tiene casos para la maqueta; estos son casos
// nuevos (UT-CON-xx y UI-CON-xx). UT-CON-02 sigue la idea de UT-57
// (orden del más reciente al más antiguo) sobre los datos de ejemplo.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/data/accountant_sample_data.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/screens/accountant_clients_screen.dart';
import 'package:kopay/screens/accountant_summary_screen.dart';
import 'package:kopay/screens/settings_screen.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/format_utils.dart';

void main() {
  final now = DateTime(2026, 11, 26);
  final month = DateTime(2026, 11);
  final previous = DateTime(2026, 10);

  group('Datos de ejemplo', () {
    test('UT-CON-01 · HU-40 · Resumen del periodo separa ingresos, gastos y '
        'pagos de tarjeta', () {
      final moves = [
        Movement(
          amount: 1000,
          description: 'Nómina',
          category: 'Ingreso',
          date: DateTime(2026, 11, 1),
        ),
        Movement(
          amount: -300,
          description: 'Súper',
          category: 'Comida',
          date: DateTime(2026, 11, 3),
        ),
        Movement(
          amount: -200,
          description: 'Pago tarjeta',
          category: 'Pago de tarjeta',
          date: DateTime(2026, 11, 8),
          type: MovementType.payment,
        ),
        // Otro mes: no cuenta.
        Movement(
          amount: -999,
          description: 'Renta',
          category: 'Vivienda',
          date: DateTime(2026, 10, 5),
        ),
      ];
      final summary = PeriodSummary.of(moves, month);
      expect(summary.income, 1000);
      expect(summary.expenses, 300);
      expect(summary.cardPayments, 200);
      expect(summary.balance, 500);
    });

    test('UT-CON-02 · HU-40 · Cada cliente solo muestra sus movimientos del '
        'mes, del más reciente al más antiguo', () {
      final clients = accountantSampleClients(now: now);
      expect(clients, hasLength(2));
      for (final client in clients) {
        final moves = client.movementsFor(month);
        expect(moves, isNotEmpty);
        expect(
          moves.every((m) => FormatUtils.isSameMonth(m.date, month)),
          isTrue,
        );
        for (var i = 1; i < moves.length; i++) {
          expect(moves[i - 1].date.isBefore(moves[i].date), isFalse);
        }
      }
      // Los dos clientes no comparten movimientos.
      final a = clients[0].movements.toSet();
      expect(clients[1].movements.any(a.contains), isFalse);
    });

    test('UT-CON-03 · HU-39 · Los clientes de ejemplo se identifican como '
        'tales', () {
      for (final client in accountantSampleClients(now: now)) {
        expect(client.email, endsWith('@ejemplo.com'));
        expect(client.id, startsWith('ejemplo-'));
      }
    });
  });

  group('Pantallas', () {
    Future<void> open(WidgetTester tester, Widget home) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: home));
      await tester.pumpAndSettle();
    }

    testWidgets('UI-CON-01 · HU-39 · Ajustes abre la maqueta y la lista de '
        'clientes avisa que son datos de ejemplo', (tester) async {
      await open(tester, const Scaffold(body: SettingsScreen()));
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-accountant-preview')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('settings-accountant-preview')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.es.clientsTitle), findsOneWidget);
      expect(find.byKey(const Key('sample-data-banner')), findsOneWidget);
      expect(find.text(AppStrings.es.sampleBanner), findsOneWidget);
      expect(find.text('Ana Ejemplo'), findsOneWidget);
      expect(find.text('luis@ejemplo.com'), findsOneWidget);
    });

    testWidgets('UI-CON-02 · HU-40 · Elegir un cliente abre su resumen del '
        'mes', (tester) async {
      // Como en la app: datos y mes de hoy.
      final clients = accountantSampleClients();
      await open(
        tester,
        AccountantClientsScreen(data: SampleAccountantData(clients)),
      );
      await tester.tap(find.byKey(const Key('client-ejemplo-1')));
      await tester.pumpAndSettle();

      final summary = PeriodSummary.of(
        clients.first.movements,
        DateTime(DateTime.now().year, DateTime.now().month),
      );
      expect(find.text('Ana Ejemplo'), findsOneWidget);
      expect(find.byKey(const Key('sample-data-banner')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-income'))).data,
        FormatUtils.money(summary.income),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-payments'))).data,
        FormatUtils.money(summary.cardPayments),
      );
    });

    testWidgets('UI-CON-03 · HU-40 · Cambiar el periodo cambia el resumen', (
      tester,
    ) async {
      final client = accountantSampleClients(now: now).first;
      await open(
        tester,
        AccountantSummaryScreen(
          client: client.info,
          data: SampleAccountantData([client]),
          initialMonth: month,
        ),
      );
      String income() =>
          tester.widget<Text>(find.byKey(const Key('summary-income'))).data!;

      expect(
        income(),
        FormatUtils.money(PeriodSummary.of(client.movements, month).income),
      );
      await tester.tap(find.byKey(const Key('summary-prev-month')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-month'))).data,
        FormatUtils.monthYear(previous),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('summary-expenses'))).data,
        FormatUtils.money(
          PeriodSummary.of(client.movements, previous).expenses,
        ),
      );
    });

    testWidgets('UI-CON-04 · HU-40 · HU-42 · El historial conserva el mes y es '
        'de solo lectura', (tester) async {
      final client = accountantSampleClients(now: now).first;
      await open(
        tester,
        AccountantSummaryScreen(
          client: client.info,
          data: SampleAccountantData([client]),
          initialMonth: month,
        ),
      );
      await tester.tap(find.byKey(const Key('summary-prev-month')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('summary-view-movements')),
      );
      await tester.tap(find.byKey(const Key('summary-view-movements')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('history-period'))).data,
        'Ana Ejemplo · ${FormatUtils.monthYear(previous)}',
      );
      final count = client.movementsFor(previous).length;
      for (var i = 0; i < count; i++) {
        expect(find.byKey(Key('history-row-$i')), findsOneWidget);
      }
      expect(find.byKey(Key('history-row-$count')), findsNothing);
      expect(find.byKey(const Key('history-read-only')), findsOneWidget);
      expect(find.byKey(const Key('sample-data-banner')), findsOneWidget);

      // Sin controles de edición: ni botón +, ni filas que respondan.
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      final rows = tester.widgetList<InkWell>(
        find.descendant(
          of: find.byKey(const Key('history-row-0')),
          matching: find.byType(InkWell),
        ),
      );
      expect(rows.every((w) => w.onTap == null), isTrue);
    });

    testWidgets('UI-CON-05 · HU-39 · Sin clientes muestra el mensaje vacío', (
      tester,
    ) async {
      await open(
        tester,
        AccountantClientsScreen(data: SampleAccountantData(const [])),
      );
      expect(find.byKey(const Key('clients-empty')), findsOneWidget);
      expect(find.byKey(const Key('sample-data-banner')), findsOneWidget);
    });
  });
}
