import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kopay/main.dart';
import 'package:kopay/providers/income_provider.dart';
import 'package:kopay/providers/movement_provider.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('La navegación inferior muestra Inicio, Movimientos y Ajustes', (
    tester,
  ) async {
    // Providers sin cargar: no abren la base de datos.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MovementProvider()),
          ChangeNotifierProvider(create: (_) => IncomeProvider()),
        ],
        child: const KopayApp(),
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Movimientos'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
