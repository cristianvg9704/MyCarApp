// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/main.dart';

void main() {
  testWidgets('App should start and display navigation', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyCarApp());
    await tester.pumpAndSettle();

    // Verify that navigation items exist
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Ingresos'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
