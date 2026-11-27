// S3-18 · Registro e inicio de sesión de punta a punta (HU-30 y HU-31).
//
// Casos nuevos (E2E-AUTH-xx): la app (KopayApp) con su cliente HTTP real
// habla con la API Node en ejecución, que guarda en PostgreSQL; lo guardado
// se revisa con psql. Corre en `flutter test`, sin dispositivo: SQLite va
// en memoria y el almacén seguro del sistema se simula.
//
// Se omiten si no se pasan los datos de la API y la base. Cómo
// prepararlas está en docs/casos-s3-18.md.
//
//   flutter test test/e2e_auth_api_test.dart \
//     --dart-define=API_URL=http://127.0.0.1:3000 \
//     --dart-define=E2E_DB=postgres://usuario:clave@localhost:5432/kopay_e2e

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/screens/register_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/http_auth_api.dart';
import 'package:kopay/services/incomes_api.dart';
import 'package:kopay/services/movements_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:kopay/utils/auth_validators.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _database = String.fromEnvironment('E2E_DB');

/// Ruta de psql, por si no está en el PATH.
const _psql = String.fromEnvironment('PSQL', defaultValue: 'psql');

const _password = 'kopay2026';
const _badCredentials = 'Correo o contraseña incorrectos';
const _tooMany =
    'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

class _SpanishSettings extends SettingsProvider {
  _SpanishSettings({super.database});

  @override
  String get language => 'es';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  // Cada ejecución usa correos propios; no hace falta vaciar la base.
  final run = DateTime.now().millisecondsSinceEpoch;
  String mail(String name) => 'e2e.$name.$run@mail.com';

  group(
    'Registro e inicio de sesión contra la API y PostgreSQL',
    skip: _database.isEmpty
        ? 'Necesita la API y PostgreSQL: pasa API_URL y E2E_DB '
              '(docs/casos-s3-18.md)'
        : false,
    () {
      late DatabaseHelper db;

      setUp(() {
        // flutter_test bloquea la red; aquí se necesita la real.
        HttpOverrides.global = null;
        FlutterSecureStorage.setMockInitialValues({});
        db = DatabaseHelper.withFactory(
          databaseFactoryFfiNoIsolate,
          inMemoryDatabasePath,
        );
      });

      /// Consulta PostgreSQL y devuelve una línea por fila.
      Future<List<String>> sql(WidgetTester tester, String query) async {
        // Las opciones van antes que la consulta (psql en Windows ignora lo
        // que sigue a un argumento sin opción). -w: nunca pide contraseña.
        final result = await tester.runAsync(
          () => Process.run(
            _psql,
            [
              '-X',
              '-w',
              '-v',
              'ON_ERROR_STOP=1',
              '-d',
              _database,
              '-tAc',
              query,
            ],
            environment: {'PGCLIENTENCODING': 'UTF8'},
            stdoutEncoding: utf8,
            stderrEncoding: const SystemEncoding(),
          ),
        );
        expect(result!.exitCode, 0, reason: '${result.stderr}');
        return (result.stdout as String)
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }

      Future<int> sessionsOf(WidgetTester tester, String email) async =>
          int.parse(
            (await sql(
              tester,
              'SELECT count(*) FROM sessions s JOIN users u '
              "ON u.id = s.user_id WHERE u.email = '$email'",
            )).single,
          );

      /// Sesión que la app dejó guardada. Se lee fuera del reloj simulado:
      /// si no, la espera no termina.
      Future<StoredSession?> storedSession(WidgetTester tester) async =>
          tester.runAsync<StoredSession?>(() => SecureSessionStore().read());

      /// La red responde con el reloj real y la pantalla avanza con el
      /// simulado, así que se alternan hasta que aparece [target].
      Future<void> waitFor(WidgetTester tester, Finder target) async {
        for (var i = 0; i < 300 && target.evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(target, findsWidgets);
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      /// Abre la app como la arma `main`, con SQLite en memoria.
      Future<SessionProvider> startApp(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1170, 2532); // 390 × 844 pt
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        late SessionProvider session;
        await tester.pumpWidget(
          MultiProvider(
            key: UniqueKey(),
            providers: [
              Provider<DatabaseHelper>.value(value: db),
              Provider<AuthApi>(
                create: (_) => HttpAuthApi(),
                dispose: (_, api) => (api as HttpAuthApi).close(),
              ),
              ChangeNotifierProvider(
                create: (context) => session = SessionProvider(
                  api: context.read<AuthApi>(),
                  store: SecureSessionStore(),
                )..restore(),
              ),
              ChangeNotifierProxyProvider<SessionProvider, MovementProvider>(
                create: (_) =>
                    MovementProvider(database: db, api: HttpMovementsApi())
                      ..load(),
                update: (_, s, movements) => movements!..bindSession(s),
              ),
              ChangeNotifierProxyProvider<SessionProvider, IncomeProvider>(
                create: (_) =>
                    IncomeProvider(database: db, api: HttpIncomesApi())..load(),
                update: (_, s, incomes) => incomes!..bindSession(s),
              ),
              ChangeNotifierProvider(
                create: (_) => CardProvider(database: db)..load(),
              ),
              ChangeNotifierProvider(
                create: (_) => DebtProvider(database: db)..load(),
              ),
              ChangeNotifierProvider(
                create: (_) => CategoryProvider(database: db)..load(),
              ),
              ChangeNotifierProvider<SettingsProvider>(
                create: (_) => _SpanishSettings(database: db),
              ),
            ],
            child: const KopayApp(),
          ),
        );
        await tester.pump();
        return session;
      }

      /// Deja correr los dos relojes para que termine lo que quedó
      /// pendiente (la sincronización usa la red y SQLite).
      Future<void> drain(WidgetTester tester) async {
        for (var i = 0; i < 25; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      /// Desmonta la app y deja vencer los temporizadores de la red.
      Future<void> closeApp(WidgetTester tester) async {
        await drain(tester);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 1));
        await drain(tester);
      }

      /// Cierra la app y la base de la prueba. La base se cierra aquí y no
      /// en `tearDown`: ahí el reloj simulado ya no avanza y la espera no
      /// termina.
      Future<void> finish(WidgetTester tester) async {
        await closeApp(tester);
        var closed = false;
        unawaited(db.close().then((_) => closed = true));
        for (var i = 0; i < 20 && !closed; i++) {
          await drain(tester);
        }
        expect(closed, isTrue, reason: 'la base no se pudo cerrar');
      }

      Future<void> type(WidgetTester tester, String key, String text) =>
          tester.enterText(find.byKey(Key(key)), text);

      Future<void> tap(WidgetTester tester, String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pump();
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      /// Crea la cuenta desde la pantalla de registro.
      Future<void> fillRegister(WidgetTester tester, String email) async {
        await tap(tester, 'login-to-register');
        await tester.pump(const Duration(seconds: 1));
        await type(tester, 'register-name', 'Ana López');
        await type(tester, 'register-email', email);
        await type(tester, 'register-password', _password);
        await tap(tester, 'register-submit');
      }

      Future<void> register(WidgetTester tester, String email) async {
        await fillRegister(tester, email);
        await waitFor(tester, find.byKey(const Key('login-submit')));
        for (
          var i = 0;
          i < 100 && find.byType(RegisterScreen).evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.byType(RegisterScreen), findsNothing);
      }

      Future<void> login(
        WidgetTester tester,
        String email,
        String password,
      ) async {
        await type(tester, 'login-email', email);
        await type(tester, 'login-password', password);
        await tap(tester, 'login-submit');
      }

      testWidgets('E2E-AUTH-01 · HU-30 · registrar desde la app crea una '
          'cuenta de usuario sin guardar la contraseña en claro', (
        tester,
      ) async {
        final email = mail('alta');
        final session = await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));

        await register(tester, '  ${email.toUpperCase()} ');

        expect(find.text(email), findsOneWidget);
        expect(session.isSignedIn, isFalse);
        expect(
          await sql(
            tester,
            "SELECT name || '|' || role || '|' || "
            "(password_hash LIKE 'scrypt\$%') || '|' || "
            "(position('$_password' IN password_hash) = 0) "
            "FROM users WHERE email = '$email'",
          ),
          ['Ana López|user|true|true'],
        );
        expect(await sessionsOf(tester, email), 0);
        await finish(tester);
      });

      testWidgets('E2E-AUTH-02 · HU-31 · entrar abre la vista de usuario y '
          'la base guarda solo los hashes de los tokens', (tester) async {
        final email = mail('entrar');
        final session = await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        await register(tester, email);

        await login(tester, email, _password);
        await waitFor(tester, find.byKey(const Key('add-button')));

        expect(session.user!.email, email);
        final stored = (await storedSession(tester))!;
        expect(stored.refreshToken, isNotNull);
        expect(await sessionsOf(tester, email), 1);
        for (final token in [stored.accessToken, stored.refreshToken!]) {
          expect(
            await sql(
              tester,
              "SELECT count(*) FROM sessions WHERE token_hash = '$token' "
              "OR refresh_token_hash = '$token'",
            ),
            ['0'],
          );
        }
        await finish(tester);
      });

      testWidgets('E2E-AUTH-03 · HU-30 · el mismo correo en mayúsculas se '
          'rechaza y no crea otra cuenta', (tester) async {
        final email = mail('repetido');
        await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        await register(tester, email);

        await fillRegister(tester, email.toUpperCase());
        await waitFor(tester, find.text('Ya existe una cuenta con ese correo'));

        expect(find.byType(RegisterScreen), findsOneWidget);
        expect(
          await sql(
            tester,
            "SELECT count(*) FROM users WHERE lower(email) = '$email'",
          ),
          ['1'],
        );
        await finish(tester);
      });

      testWidgets('E2E-AUTH-04 · HU-31 · contraseña incorrecta y correo sin '
          'cuenta dan el mismo aviso y no abren sesión', (tester) async {
        final email = mail('mala');
        final session = await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        await register(tester, email);

        for (final account in [email, mail('nadie')]) {
          await login(tester, account, 'otra2026');
          await waitFor(tester, find.text(_badCredentials));
          expect(session.isSignedIn, isFalse, reason: account);
        }

        expect(await sessionsOf(tester, email), 0);
        await finish(tester);
      });

      testWidgets('E2E-AUTH-05 · HU-30 · datos inválidos no crean ninguna '
          'cuenta', (tester) async {
        Future<List<String>> accounts() =>
            sql(tester, 'SELECT count(*) FROM users');
        await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        final before = await accounts();

        await tap(tester, 'login-to-register');
        await tester.pump(const Duration(seconds: 1));
        await tap(tester, 'register-submit');
        await tester.pump(const Duration(seconds: 1));

        expect(find.text(AuthValidators.nameRequired), findsOneWidget);
        expect(await accounts(), before);
        await finish(tester);
      });

      testWidgets('E2E-AUTH-06 · HU-31 · al volver a abrir la app, la API '
          'confirma la sesión y no pide entrar otra vez', (tester) async {
        final email = mail('reabrir');
        await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        await register(tester, email);
        await login(tester, email, _password);
        await waitFor(tester, find.byKey(const Key('add-button')));
        await closeApp(tester);

        final session = await startApp(tester);
        await waitFor(tester, find.byKey(const Key('add-button')));

        expect(find.byKey(const Key('login-title')), findsNothing);
        expect(session.user!.email, email);
        expect(session.offline, isFalse);
        await finish(tester);
      });

      testWidgets('E2E-AUTH-07 · HU-31 · una sesión revocada en la base '
          'regresa a Iniciar sesión', (tester) async {
        final email = mail('revocada');
        await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        await register(tester, email);
        await login(tester, email, _password);
        await waitFor(tester, find.byKey(const Key('add-button')));
        await closeApp(tester);

        await sql(
          tester,
          'UPDATE sessions SET revoked_at = now() WHERE user_id = '
          "(SELECT id FROM users WHERE email = '$email')",
        );
        final session = await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-expired')));

        expect(session.isSignedIn, isFalse);
        expect(await storedSession(tester), isNull);
        await finish(tester);
      });

      testWidgets('E2E-AUTH-08 · HU-31 · después de 10 fallos la API '
          'responde 429, aun con la contraseña correcta, y el botón se '
          'desactiva', (tester) async {
        final email = mail('limite');
        final session = await startApp(tester);
        await waitFor(tester, find.byKey(const Key('login-title')));
        await register(tester, email);

        // Los 10 fallos van directo a la API; el 11.º, desde la pantalla.
        await tester.runAsync(() async {
          final api = HttpAuthApi();
          for (var i = 0; i < 10; i++) {
            await expectLater(
              api.login(email: email, password: 'otra2026'),
              throwsA(
                isA<ApiException>().having((e) => e.status, 'status', 401),
              ),
            );
          }
          api.close();
        });

        await login(tester, email, _password);
        await waitFor(tester, find.text(_tooMany));

        final button = tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(const Key('login-submit')),
            matching: find.byType(FilledButton),
          ),
        );
        expect(button.onPressed, isNull);
        expect(session.isSignedIn, isFalse);
        expect(await sessionsOf(tester, email), 0);
        await finish(tester);
      });
    },
  );
}
