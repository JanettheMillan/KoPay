// S3-11 · Pantalla de inicio de sesión en la app real (HU-31).
//
// Corre a 390 × 844 pt con el tema de KoPay, FakeAuthApi y la sesión en
// memoria: campos vacíos, credenciales incorrectas (401), sin red, envío y
// login correcto. Guarda una captura por paso y falla si hay un desborde.
//
//   flutter test integration_test/s3_11_login_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/screens/login_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s3_11')
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

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('login-email')), email);
    await tester.enterText(find.byKey(const Key('login-password')), password);
  }

  testWidgets('S3-11 · Login con validaciones, errores y envío', (
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

    final api = FakeAuthApi(delay: const Duration(milliseconds: 600));
    await api.register(
      name: 'Ana López',
      email: 'ana@mail.com',
      password: 'kopay2026',
    );
    final session = SessionProvider(api: api, store: MemorySessionStore());
    var signedIn = false;

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(
          providers: [
            Provider<AuthApi>.value(value: api),
            ChangeNotifierProvider<SessionProvider>.value(value: session),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildKopayTheme(),
            home: LoginScreen(onSignedIn: () => signedIn = true),
          ),
        ),
      ),
    );
    await shot(tester, '1-login-vacio');

    await tester.tap(find.byKey(const Key('login-submit')));
    await shot(tester, '2-campos-obligatorios');

    await fill(tester, 'ana@mail.com', 'otra2026');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Correo o contraseña incorrectos'), findsOneWidget);
    await shot(tester, '3-credenciales-incorrectas');

    api.failNextWith(const NetworkException());
    await fill(tester, 'ana@mail.com', 'kopay2026');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.text(NetworkException.message), findsOneWidget);
    await shot(tester, '4-sin-red');

    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, '5-entrando', settle: false);
    await tester.pumpAndSettle();
    expect(signedIn, isTrue);
    expect(session.isSignedIn, isTrue);

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
