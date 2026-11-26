// S4-11 · Autorizar y revocar contador en la app real (HU-38, HU-41).
//
// Corre a 390 × 844 pt con el tema de KoPay, FakeAuthApi,
// FakeAccountantsApi y la sesión en memoria: lista vacía, correo sin
// contador, diálogo de consentimiento, permiso creado, confirmación de
// revocar y acceso retirado. Guarda una captura por paso y falla si hay
// un desborde.
//
//   flutter test integration_test/s4_11_contadores_test.dart -d macos

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kopay/main.dart';
import 'package:kopay/providers/session_provider.dart';
import 'package:kopay/screens/accountants_screen.dart';
import 'package:kopay/services/accountants_api.dart';
import 'package:kopay/services/fake_accountants_api.dart';
import 'package:kopay/services/fake_auth_api.dart';
import 'package:kopay/services/session_store.dart';
import 'package:provider/provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.testTextInput.register();

  final boundary = GlobalKey();
  final outDir = Directory('${Directory.systemTemp.path}/kopay_s4_11')
    ..createSync(recursive: true);
  final overflows = <String>[];

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${outDir.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Future<void> tap(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('S4-11 · Autorizar, cancelar, confirmar y revocar contador', (
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

    final auth = FakeAuthApi();
    await auth.register(
      name: 'Ana López',
      email: 'ana@mail.com',
      password: 'kopay2026',
    );
    final session = SessionProvider(api: auth, store: MemorySessionStore());
    await session.login(email: 'ana@mail.com', password: 'kopay2026');
    final api = FakeAccountantsApi(
      accountants: {'carla@conta.mx': 'Carla Contadora'},
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionProvider>.value(value: session),
            Provider<AccountantsApi>.value(value: api),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildKopayTheme(),
            home: const AccountantsScreen(),
          ),
        ),
      ),
    );
    await shot(tester, '1-sin-contadores');

    await tap(tester, 'accountants-authorize');
    await tester.enterText(
      find.byKey(const Key('authorize-email')),
      'nadie@conta.mx',
    );
    await tap(tester, 'authorize-continue');
    await tap(tester, 'authorize-confirm');
    expect(find.text('No hay un contador con ese correo'), findsOneWidget);
    await shot(tester, '2-correo-sin-contador');

    await tester.enterText(
      find.byKey(const Key('authorize-email')),
      'carla@conta.mx',
    );
    await tap(tester, 'authorize-continue');
    expect(find.byKey(const Key('authorize-confirm-dialog')), findsOneWidget);
    await shot(tester, '3-consentimiento');

    await tap(tester, 'authorize-confirm');
    expect(find.text('Carla Contadora'), findsOneWidget);
    await shot(tester, '4-contador-autorizado');

    await tap(tester, 'accountant-revoke-g-1');
    await shot(tester, '5-confirmar-revocar');

    await tap(tester, 'accountant-revoke-confirm');
    expect(find.text('Carla Contadora'), findsNothing);
    expect(api.grants, isEmpty);
    await shot(tester, '6-acceso-retirado');

    // ignore: avoid_print
    print('OVERFLOWS=${overflows.isEmpty ? 'ninguno' : overflows.join(' | ')}');
    // ignore: avoid_print
    print('CAPTURAS=${outDir.path}');
    expect(overflows, isEmpty);
  });
}
