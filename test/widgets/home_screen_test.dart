import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/screens/home_screen.dart';
import 'package:new_my_car_app/providers/car_provider.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('should display app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (_) => CarProvider(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that the app bar contains user greeting
      expect(find.text('Hola,'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('should display empty state when no cars', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (_) => CarProvider(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Wait for loading to complete
      await tester.pump(const Duration(seconds: 1));

      // Verify empty state message
      expect(find.text('No tienes vehículos'), findsOneWidget);
      expect(find.text('Agrega tu primer vehículo para comenzar\na gestionar tus ingresos'), findsOneWidget);
      expect(find.text('Agregar Vehículo'), findsOneWidget);
    });

    testWidgets('should display add vehicle button in app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (_) => CarProvider(),
                  child: const HomeScreen(),
                ),
              ),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify add button exists (by icon)
      expect(find.byIcon(Icons.add), findsWidgets);
    });
  });
}
