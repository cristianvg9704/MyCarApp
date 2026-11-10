import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_my_car_app/screens/onboarding/onboarding_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, __) => const OnboardingScreen()),
            GoRoute(
              path: '/login',
              builder: (_, __) => const Scaffold(body: Text('login')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<bool> completedFlag() async =>
      (await SharedPreferences.getInstance()).getBool('onboarding_completed') ??
      false;

  testWidgets('al terminar el onboarding se recuerda y se va al login', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    expect(await completedFlag(), isFalse);

    while (find.text('Comenzar').evaluate().isEmpty) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(await completedFlag(), isTrue);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('saltar el onboarding también lo da por visto', (tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.byType(TextButton).first);
    await tester.pumpAndSettle();

    expect(await completedFlag(), isTrue);
    expect(find.text('login'), findsOneWidget);
  });
}
