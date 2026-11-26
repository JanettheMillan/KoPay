// S3-10 · Pantalla de registro en la app real (HU-30).
//
// Corre a 390 × 844 pt con el tema de KoPay y FakeAuthApi (todavía no hay
// cliente HTTP, S4-07): errores locales, envío, correo repetido (409),
// sin red y registro correcto. Guarda una captura por paso y falla si
// aparece un desborde. No escribe en la base.
//
//   flutter test integration_test/s3_10_registro_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/main.dart';
import 'package:kopay/screens/register_screen.dart';
import 'package:kopay/services/auth_api.dart';
import 'package:kopay/services/fake_auth_api.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s3_10')
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

  Future<void> fill(WidgetTester tester, String email) async {
    await tester.enterText(find.byKey(const Key('register-name')), 'Ana López');
    await tester.enterText(find.byKey(const Key('register-email')), email);
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'kopay2026',
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
  }

  testWidgets('S3-10 · Registro con validaciones y estados de envío', (
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
      name: 'Ana',
      email: 'usada@mail.com',
      password: 'kopay2026',
    );
    String? returned;

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildKopayTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open'),
                  onPressed: () async =>
                      returned = await Navigator.of(context).push<String>(
                        MaterialPageRoute(
                          builder: (_) => RegisterScreen(api: api),
                        ),
                      ),
                  child: const Text('Crear cuenta'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await shot(tester, '1-registro-vacio');

    // 2. Errores locales: los tres campos a la vez.
    await submit(tester);
    await shot(tester, '2-errores');

    // 3. Enviando.
    await fill(tester, 'usada@mail.com');
    await submit(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, '3-enviando', settle: false);

    // 4. 409: correo ya registrado.
    await tester.pumpAndSettle();
    expect(find.text('Ya existe una cuenta con ese correo'), findsOneWidget);
    await shot(tester, '4-correo-repetido');

    // 5. Sin red.
    api.failNextWith(const NetworkException());
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'ana@mail.com',
    );
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text(NetworkException.message), findsOneWidget);
    await shot(tester, '5-sin-red');

    // 6. Reintento correcto: vuelve con el correo.
    await submit(tester);
    await tester.pumpAndSettle();
    expect(returned, 'ana@mail.com');

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
