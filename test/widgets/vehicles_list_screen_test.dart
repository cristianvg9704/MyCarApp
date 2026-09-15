import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/screens/vehicles_list_screen.dart';
import 'package:new_my_car_app/providers/car_provider.dart';

void main() {
  Widget buildTestableScreen() {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => CarProvider(),
              child: const VehiclesListScreen(),
            ),
          ),
        ],
      ),
    );
  }

  group('VehiclesListScreen Widget Tests', () {
    testWidgets('should display the app bar title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('Vehículos'), findsOneWidget);
    });

    testWidgets('should display the empty state when there are no cars', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.text('No hay vehículos registrados'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    });

    testWidgets('should show a back button that pops the route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });
}
