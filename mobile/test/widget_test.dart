import 'package:flutter_test/flutter_test.dart';

import 'package:uleam_med/main.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const UleamMedApp());

    expect(find.text('Hola, Roberto 👋'), findsOneWidget);
    expect(find.text('Medicamentos'), findsOneWidget);
  });
}
