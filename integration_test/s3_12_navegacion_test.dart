// S3-12 · Entrada a la app según la sesión (HU-31, HU-33, HU-34).
//
// Corre la app completa a 390 × 844 pt con FakeAuthApi y la sesión en
// memoria (sin servidor): Splash, acceso, login con error, login correcto
// que abre Inicio, y cierre de sesión que regresa al acceso. Guarda una
// captura por paso y falla si hay un desborde.
//
//   flutter test integration_test/s3_12_navegacion_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/database/database_helper.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/card_provider.dart';
import 'package:kopay/providers/debt_provider.dart';
import 'package:kopay/providers/category_provider.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/providers/settings_provider.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s3_12')
    ..createSync(recursive: true);
  final overflows = <String>[];

  Future<void> shot(
    WidgetTester tester,
    String name, {
    bool settle = true,
  }) async {
    if (settle) await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${outDir.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('S3-12 · Splash, acceso, login y cierre de sesión', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed')) {
        overflows.add(text.split('\n').first);
      } else {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);

    final api = FakeAuthApi(delay: const Duration(milliseconds: 500));
    await api.register(
      name: 'Ana López',
      email: 'ana@mail.com',
      password: 'kopay2026',
    );
    final session = SessionProvider(api: api, store: MemorySessionStore());

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(
          providers: [
            Provider<DatabaseHelper>.value(value: DatabaseHelper.instance),
            Provider<AuthApi>.value(value: api),
            ChangeNotifierProvider<SessionProvider>.value(value: session),
            ChangeNotifierProvider(create: (_) => MovementProvider()..load()),
            ChangeNotifierProvider(create: (_) => IncomeProvider()..load()),
            ChangeNotifierProvider(create: (_) => CardProvider()..load()),
            ChangeNotifierProvider(create: (_) => DebtProvider()..load()),
            ChangeNotifierProvider(create: (_) => CategoryProvider()..load()),
            ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
          ],
          child: const KopayApp(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('splash')), findsOneWidget);
    await shot(tester, '1-splash', settle: false);

    await session.restore();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    await shot(tester, '2-acceso');

    await tester.enterText(
      find.byKey(const Key('login-email')),
      'ana@mail.com',
    );
    await tester.enterText(find.byKey(const Key('login-password')), 'otra2026');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    await shot(tester, '3-credenciales-incorrectas');

    await tester.enterText(
      find.byKey(const Key('login-password')),
      'kopay2026',
    );
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await shot(tester, '4-inicio-tras-login');

    await session.logout();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-title')), findsOneWidget);
    await shot(tester, '5-tras-cerrar-sesion');

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
