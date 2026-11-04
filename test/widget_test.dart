import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kopay/main.dart';

void main() {
  testWidgets('La navegación inferior muestra Inicio, Movimientos y Ajustes',
      (tester) async {
    await tester.pumpWidget(const KopayApp());
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Movimientos'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
