import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:new_my_car_app/services/social_auth_service.dart';
import 'package:new_my_car_app/widgets/social_auth_buttons.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool showApple = true,
    bool enabled = true,
    required List<SocialProvider> taps,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialAuthButtons(
            showApple: showApple,
            enabled: enabled,
            onPressed: taps.add,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the divider and both buttons', (tester) async {
    await pump(tester, taps: []);

    expect(find.text('o continúa con'), findsOneWidget);
    expect(find.byType(SignInWithAppleButton), findsOneWidget);
    expect(find.text('Continuar con Apple'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('hides Apple where it is not available', (tester) async {
    await pump(tester, showApple: false, taps: []);

    expect(find.byType(SignInWithAppleButton), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('reports the chosen provider', (tester) async {
    final taps = <SocialProvider>[];
    await pump(tester, taps: taps);

    await tester.tap(find.text('Continuar con Google'));
    await tester.tap(find.byType(SignInWithAppleButton));

    expect(taps, [SocialProvider.google, SocialProvider.apple]);
  });

  testWidgets('does nothing while disabled', (tester) async {
    final taps = <SocialProvider>[];
    await pump(tester, enabled: false, taps: taps);

    await tester.tap(find.text('Continuar con Google'), warnIfMissed: false);
    await tester.tap(find.byType(SignInWithAppleButton), warnIfMissed: false);

    expect(taps, isEmpty);
  });
}
