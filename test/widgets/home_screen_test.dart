import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/screens/home_screen.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/user_provider.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('should display app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider(create: (_) => CarProvider()),
                    ChangeNotifierProvider(create: (_) => UserProvider()),
                  ],
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
      // Sin usuario cargado, UserProvider expone el nombre por defecto
      expect(find.text('Usuario'), findsOneWidget);
    });

    testWidgets('should display empty state when no cars', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider(create: (_) => CarProvider()),
                    ChangeNotifierProvider(create: (_) => UserProvider()),
                  ],
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
                builder: (context, state) => MultiProvider(
                  providers: [
                    ChangeNotifierProvider(create: (_) => CarProvider()),
                    ChangeNotifierProvider(create: (_) => UserProvider()),
                  ],
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
