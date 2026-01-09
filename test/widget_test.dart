// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:churros/main.dart';

void main() {
  testWidgets('Login page displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ChurrosApp());

    // Verify that the login page displays the correct elements.
    expect(find.text('Churros POS'), findsOneWidget);
    expect(find.text('Bienvenido, inicia tu turno.'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
    expect(find.text('Correo o Usuario'), findsOneWidget);
    expect(find.text('PIN de Acceso'), findsOneWidget);
  });
}
