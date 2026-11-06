// Cerrar la hoja y ocultar el teclado en los formularios.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kopay/widgets/ui_kit.dart';

void main() {
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showKopaySheet<void>(
                  context,
                  const KopaySheet(
                    title: 'Prueba',
                    child: TextField(key: Key('campo')),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('el botón de cerrar cierra la hoja', (tester) async {
    await openSheet(tester);
    expect(find.text('Prueba'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sheet-close')));
    await tester.pumpAndSettle();

    expect(find.text('Prueba'), findsNothing);
  });

  testWidgets('tocar un área vacía oculta el teclado', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const Key('campo')));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasPrimaryFocus, isTrue);
    expect(find.byType(EditableText), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.tapAt(const Offset(200, 20)); // título, sin campo
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });
}
