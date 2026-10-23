import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/income.dart';
import 'package:new_my_car_app/screens/car_detail_screen.dart';

void main() {
  final car = Car(
    id: 'c1',
    userId: 'u1',
    brand: 'Toyota',
    model: 'Corolla',
    year: 2020,
    plateNumber: 'ABC123',
    color: 'Rojo',
    notes: 'Cambio de aceite pendiente',
  );

  final incomes = [
    Income(
      id: 'i1',
      userId: 'u1',
      carId: 'c1',
      description: 'Viaje aeropuerto',
      amount: 120000,
      date: DateTime.now(),
    ),
  ];

  Widget buildScreen({
    Future<Car?> Function(String)? carLoader,
    Future<List<Income>> Function(String)? incomesLoader,
  }) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => CarDetailScreen(
              carId: 'c1',
              carLoader: carLoader ?? (_) async => car,
              incomesLoader: incomesLoader ?? (_) async => incomes,
            ),
          ),
        ],
      ),
    );
  }

  group('CarDetailScreen', () {
    testWidgets('shows a loader while the car is loading', (tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows not found when the car does not exist', (tester) async {
      await tester.pumpWidget(buildScreen(carLoader: (_) async => null));
      await tester.pumpAndSettle();

      expect(find.text('Vehículo no encontrado'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('shows the four tabs with the car name as title', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Toyota Corolla'), findsOneWidget);
      for (final label in ['Detalle', 'Ingresos', 'Gráficos', 'Kilometraje']) {
        expect(find.widgetWithText(Tab, label), findsOneWidget);
      }
    });

    testWidgets('Detalle tab is selected first and shows only car info', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Rojo'), findsOneWidget);
      expect(find.text('Cambio de aceite pendiente'), findsOneWidget);
      expect(find.text('Viaje aeropuerto'), findsNothing);
    });

    testWidgets('Ingresos tab shows incomes and hides car info', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Ingresos'));
      await tester.pumpAndSettle();

      expect(find.text('Viaje aeropuerto'), findsOneWidget);
      expect(find.text('ABC123'), findsNothing);
    });

    testWidgets('Ingresos tab shows empty state without incomes', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(incomesLoader: (_) async => []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Ingresos'));
      await tester.pumpAndSettle();

      expect(find.text('No hay ingresos'), findsOneWidget);
    });

    testWidgets('Gráficos tab shows period selector and stats', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Gráficos'));
      await tester.pumpAndSettle();

      expect(find.text('7 días'), findsOneWidget);
      expect(find.text('30 días'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Promedio'), findsOneWidget);
    });

    testWidgets('Gráficos tab shows empty state without incomes', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(incomesLoader: (_) async => []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Gráficos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Debes agregar ingresos para ver los gráficos'),
        findsOneWidget,
      );
    });
  });
}
