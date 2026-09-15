import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_my_car_app/screens/auth/login_screen.dart';
import 'package:new_my_car_app/providers/auth_provider.dart';
import 'package:new_my_car_app/config/supabase_config.dart';

void main() {
  // AuthProvider construye un SupabaseClient en su inicializador de campo,
  // así que Supabase debe estar inicializado antes de poder crearlo en un test.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  });

  Widget buildTestableLogin() {
    return MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => AuthProvider(),
              child: const LoginScreen(),
            ),
          ),
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) =>
                const Scaffold(body: Text('Forgot password screen')),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) =>
                const Scaffold(body: Text('Register screen')),
          ),
        ],
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('should display the main login form elements', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Correo electrónico *'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Contraseña *'),
        findsOneWidget,
      );
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('should show validation errors when submitting an empty form', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Por favor ingresa tu correo'), findsOneWidget);
      expect(find.text('Por favor ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('should show a validation error for an invalid email', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresa un correo válido'), findsOneWidget);
    });

    testWidgets('should show a validation error for a short password', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'user@example.com');
      await tester.enterText(fields.last, '123');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(
        find.text('La contraseña debe tener al menos 6 caracteres'),
        findsOneWidget,
      );
    });

    testWidgets('should toggle password visibility', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    });

    testWidgets('should navigate to the forgot password screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      expect(find.text('Forgot password screen'), findsOneWidget);
    });

    testWidgets('should navigate to the register screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableLogin());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();

      expect(find.text('Register screen'), findsOneWidget);
    });
  });
}
