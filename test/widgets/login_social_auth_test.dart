import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/supabase_test_init.dart';
import 'package:new_my_car_app/providers/auth_provider.dart';
import 'package:new_my_car_app/screens/auth/login_screen.dart';
import 'package:new_my_car_app/services/social_auth_service.dart';

class _FakeSocialAuthService implements SocialAuthService {
  SocialSignInResult result = SocialSignInResult.signedIn;
  Object? error;
  bool appleAvailable = true;
  final List<SocialProvider> calls = [];

  @override
  bool isAvailable(SocialProvider provider) =>
      provider == SocialProvider.google || appleAvailable;

  @override
  Future<SocialSignInResult> signIn(SocialProvider provider) async {
    calls.add(provider);
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initSupabaseForTests();
  });

  late _FakeSocialAuthService social;

  setUp(() => social = _FakeSocialAuthService());

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => ChangeNotifierProvider(
                create: (_) => AuthProvider(socialAuthService: social),
                child: const LoginScreen(),
              ),
            ),
            GoRoute(
              path: '/subscription',
              builder: (_, _) =>
                  const Scaffold(body: Text('Subscription screen')),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home screen')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('offers Apple and Google when both are available', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.text('Continuar con Apple'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('hides Apple when the platform does not support it', (
    tester,
  ) async {
    social.appleAvailable = false;
    await pumpLogin(tester);

    expect(find.text('Continuar con Apple'), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('a successful Google sign-in leaves the login screen', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(social.calls, [SocialProvider.google]);
    expect(find.text('Subscription screen'), findsOneWidget);
  });

  testWidgets('a successful Apple sign-in leaves the login screen', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Continuar con Apple'));
    await tester.pumpAndSettle();

    expect(social.calls, [SocialProvider.apple]);
    expect(find.text('Subscription screen'), findsOneWidget);
  });

  testWidgets('cancelling stays on the login screen without an error', (
    tester,
  ) async {
    social.result = SocialSignInResult.cancelled;
    await pumpLogin(tester);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Subscription screen'), findsNothing);
  });

  testWidgets('a failure shows its message and stays on the screen', (
    tester,
  ) async {
    social.error = const SocialAuthException(
      'El inicio de sesión con Google aún no está configurado.',
    );
    await pumpLogin(tester);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('El inicio de sesión con Google aún no está configurado.'),
      findsOneWidget,
    );
    expect(find.text('Subscription screen'), findsNothing);
  });
}
