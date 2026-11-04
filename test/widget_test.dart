import 'package:flutter_test/flutter_test.dart';

import 'package:kopay/main.dart';

void main() {
  testWidgets('La app inicia y muestra el nombre', (tester) async {
    await tester.pumpWidget(const KopayApp());
    expect(find.text('kopay'), findsOneWidget);
  });
}
