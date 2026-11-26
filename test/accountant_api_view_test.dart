// S5-09 · Vista de contador conectada con la API (HU-37, HU-39, HU-40,
// HU-41, HU-42).
//
// Pantallas reales con ApiAccountantData, una sesión de contador
// (SessionProvider) y una /api/clients en memoria que guarda cada petición
// y responde 403 cuando la persona revoca. El plan de pruebas no tiene
// casos de esto; ACV-01 a ACV-08 son pruebas nuevas, anotadas en el PR.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/models/accountant_client.dart';
import 'package:kopay/models/movement_model.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/screens/accountant_clients_screen.dart';
import 'package:kopay/screens/accountant_summary_screen.dart';
import 'package:kopay/screens/session_gate.dart';
import 'package:kopay/services/accountant_data.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/clients_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/app_strings.dart';
import 'package:kopay/utils/format_utils.dart';
import 'package:provider/provider.dart';

/// /api/clients en memoria. Responde `403` para quien no está en
/// [granted], como la API después de revocar (§3.10).
class _FakeClientsApi implements ClientsApi {
  final Map<String, ClientInfo> granted = {};
  final Map<String, List<Movement>> data = {};

  /// Cada petición: `list`, `summary u1 2026-11`, `movements u1 2026-11`.
  final List<String> calls = [];
  Object? failWith;

  static const _forbidden = ApiException(
    403,
    'FORBIDDEN',
    'No tienes acceso a los datos de esta persona',
  );

  void _check(String token) {
    expect(token, 'acc');
    final error = failWith;
    if (error != null) throw error;
  }

  List<Movement> _month(String id, DateTime month) =>
      (data[id] ?? const [])
          .where((m) => FormatUtils.isSameMonth(m.date, month))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<List<ClientInfo>> list(String token) async {
    calls.add('list');
    _check(token);
    return granted.values.toList();
  }

  @override
  Future<PeriodSummary> summary(String token, String id, DateTime m) async {
    calls.add('summary $id ${HttpClientsApi.monthParam(m)}');
    _check(token);
    if (!granted.containsKey(id)) throw _forbidden;
    return PeriodSummary.of(_month(id, m), m);
  }

  @override
  Future<List<Movement>> movements(String token, String id, DateTime m) async {
    calls.add('movements $id ${HttpClientsApi.monthParam(m)}');
    _check(token);
    if (!granted.containsKey(id)) throw _forbidden;
    return _month(id, m);
  }
}

class _ContadorAuth extends FakeAuthApi {
  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession(
    accessToken: 'acc',
    tokenType: 'Bearer',
    expiresIn: 900,
    user: AuthUser(
      id: 'c1',
      name: 'Carla',
      email: email,
      role: 'accountant',
      createdAt: DateTime.utc(2026, 11, 26),
    ),
  );
}

void main() {
  final noviembre = DateTime(2026, 11);

  late _FakeClientsApi api;
  late SessionProvider session;

  Movement gasto(String d, double amount, DateTime date) =>
      Movement(amount: -amount, description: d, category: 'Comida', date: date);

  setUp(() {
    api = _FakeClientsApi();
    api.granted['u1'] = ClientInfo(
      id: 'u1',
      name: 'Ana Real',
      email: 'ana@mail.com',
      grantedAt: DateTime(2026, 11, 20),
    );
    api.granted['u2'] = ClientInfo(
      id: 'u2',
      name: 'Beto Real',
      email: 'beto@mail.com',
      grantedAt: DateTime(2026, 11, 22),
    );
    api.data['u1'] = [
      Movement(
        amount: 15000,
        description: 'Nómina',
        category: 'Ingreso',
        date: DateTime(2026, 11, 1),
      ),
      gasto('Súper', 1820.5, DateTime(2026, 11, 4)),
      Movement(
        amount: -2000,
        description: 'Pago tarjeta',
        category: 'Pago',
        date: DateTime(2026, 11, 8),
        type: MovementType.payment,
      ),
      gasto('Renta octubre', 5500, DateTime(2026, 10, 5)),
    ];
    api.data['u2'] = [gasto('Cine de Beto', 320, DateTime(2026, 11, 14))];
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    session = SessionProvider(
      api: _ContadorAuth(),
      store: MemorySessionStore(),
    );
    await tester.runAsync(
      () => session.login(email: 'carla@conta.mx', password: 'x'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AccountantClientsScreen(
          data: ApiAccountantData(session: session, api: api),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('ACV-01 · HU-39 · la lista viene de la API, sin aviso de datos '
      'de ejemplo', (tester) async {
    await open(tester);

    expect(find.text('Ana Real'), findsOneWidget);
    expect(find.text('beto@mail.com'), findsOneWidget);
    expect(find.byKey(const Key('sample-data-banner')), findsNothing);
    expect(api.calls, ['list']);
  });

  testWidgets('ACV-02 · HU-40 · el resumen pide solo ese cliente y el mes que '
      'se ve', (tester) async {
    await open(tester);
    final mesActual = DateTime(DateTime.now().year, DateTime.now().month);
    await tap(tester, 'client-u1');

    expect(
      api.calls.last,
      'summary u1 ${HttpClientsApi.monthParam(mesActual)}',
    );
    expect(api.calls.where((c) => c.contains('u2')), isEmpty);
    expect(api.calls.where((c) => c.startsWith('movements')), isEmpty);
  });

  testWidgets('ACV-03 · HU-40 · HU-42 · resumen e historial de un mes, de '
      'solo lectura', (tester) async {
    await open(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountantSummaryScreen(
          client: api.granted['u1']!,
          data: ApiAccountantData(session: session, api: api),
          initialMonth: noviembre,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(text(tester, 'summary-income'), FormatUtils.money(15000));
    expect(text(tester, 'summary-expenses'), FormatUtils.money(1820.5));
    expect(text(tester, 'summary-payments'), FormatUtils.money(2000));

    await tap(tester, 'summary-prev-month');
    expect(text(tester, 'summary-expenses'), FormatUtils.money(5500));
    expect(api.calls.last, 'summary u1 2026-10');

    await tap(tester, 'summary-next-month');
    await tap(tester, 'summary-view-movements');
    expect(api.calls.last, 'movements u1 2026-11');
    expect(
      text(tester, 'history-period'),
      'Ana Real · ${FormatUtils.monthYear(noviembre)}',
    );
    expect(find.text('Pago tarjeta'), findsOneWidget);
    expect(find.text('Súper'), findsOneWidget);
    expect(find.text('Nómina'), findsOneWidget);
    expect(find.text('Renta octubre'), findsNothing);
    expect(find.byKey(const Key('history-row-3')), findsNothing);
    expect(find.byKey(const Key('history-read-only')), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('ACV-04 · HU-41 · si revocó mientras se veía su resumen, avisa, '
      'regresa a la lista y la persona ya no aparece', (tester) async {
    await open(tester);
    await tap(tester, 'client-u1');

    api.granted.remove('u1');
    await tap(tester, 'summary-prev-month');

    expect(find.byKey(const Key('access-revoked-dialog')), findsOneWidget);
    expect(
      find.text(
        AppStrings.fill(AppStrings.es.clientAccessRevoked, ['Ana Real']),
      ),
      findsOneWidget,
    );
    await tap(tester, 'access-revoked-ok');

    expect(find.text(AppStrings.es.clientsTitle), findsOneWidget);
    expect(find.text('Ana Real'), findsNothing);
    expect(find.text('Beto Real'), findsOneWidget);
    expect(api.calls.last, 'list');
  });

  testWidgets('ACV-05 · HU-41 · si revocó antes de abrir el historial, avisa '
      'una sola vez y regresa a la lista', (tester) async {
    await open(tester);
    await tap(tester, 'client-u1');

    api.granted.remove('u1');
    await tap(tester, 'summary-view-movements');

    expect(find.byKey(const Key('access-revoked-dialog')), findsOneWidget);
    await tap(tester, 'access-revoked-ok');

    expect(find.byKey(const Key('access-revoked-dialog')), findsNothing);
    expect(find.text(AppStrings.es.clientsTitle), findsOneWidget);
    expect(find.text('Ana Real'), findsNothing);
    expect(find.text('Súper'), findsNothing);
  });

  testWidgets('ACV-06 · HU-39 · sin red muestra el mensaje y Reintentar vuelve '
      'a pedir la lista', (tester) async {
    api.failWith = const NetworkException();
    await open(tester);

    expect(text(tester, 'accountant-load-error'), NetworkException.message);
    expect(find.text('Ana Real'), findsNothing);

    api.failWith = null;
    await tap(tester, 'accountant-retry');

    expect(find.text('Ana Real'), findsOneWidget);
    expect(api.calls, ['list', 'list']);
  });

  testWidgets('ACV-07 · HU-39 · sin clientes vigentes muestra el mensaje '
      'vacío', (tester) async {
    api.granted.clear();
    await open(tester);

    expect(find.byKey(const Key('clients-empty')), findsOneWidget);
    expect(find.byKey(const Key('sample-data-banner')), findsNothing);
  });

  testWidgets('ACV-08 · HU-37 · una sesión de contador entra a Clientes '
      'autorizados con los datos de la API', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    session = SessionProvider(
      api: _ContadorAuth(),
      store: MemorySessionStore(),
    );
    await tester.runAsync(
      () => session.login(email: 'carla@conta.mx', password: 'x'),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionProvider>.value(value: session),
          Provider<ClientsApi>.value(value: api),
        ],
        child: const MaterialApp(
          home: SessionGate(home: Text('Inicio de usuario')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.es.clientsTitle), findsOneWidget);
    expect(find.text('Ana Real'), findsOneWidget);
    expect(find.byKey(const Key('sample-data-banner')), findsNothing);
    expect(find.text('Inicio de usuario'), findsNothing);
  });
}
