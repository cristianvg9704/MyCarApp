import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
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

  final transactions = [
    CarTransaction(
      id: 'i1',
      userId: 'u1',
      carId: 'c1',
      description: 'Viaje aeropuerto',
      amount: 120000,
      date: DateTime.now(),
    ),
    CarTransaction(
      id: 'e1',
      userId: 'u1',
      carId: 'c1',
      type: TransactionType.expense,
      description: 'Tanqueo Terpel',
      amount: 40000,
      date: DateTime.now(),
      category: TransactionCategory.fuel,
    ),
  ];

  Widget buildScreen({
    Future<Car?> Function(String)? carLoader,
    Future<List<CarTransaction>> Function(String)? transactionsLoader,
  }) {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => CarDetailScreen(
              carId: 'c1',
              carLoader: carLoader ?? (_) async => car,
              transactionsLoader:
                  transactionsLoader ?? (_) async => transactions,
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
      for (final label in ['Detalle', 'Movimientos', 'Gráficos', 'Kilometraje']) {
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

    testWidgets('Movimientos tab shows incomes and expenses, hides car info', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Movimientos'));
      await tester.pumpAndSettle();

      expect(find.text('Viaje aeropuerto'), findsOneWidget);
      expect(find.text('+\$120.000'), findsOneWidget);
      expect(find.text('Tanqueo Terpel'), findsOneWidget);
      expect(find.text('-\$40.000'), findsOneWidget);
      expect(find.text('ABC123'), findsNothing);
    });

    testWidgets('Movimientos tab filters by type', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Movimientos'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Egresos'));
      await tester.pumpAndSettle();
      expect(find.text('Tanqueo Terpel'), findsOneWidget);
      expect(find.text('Viaje aeropuerto'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ingresos'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje aeropuerto'), findsOneWidget);
      expect(find.text('Tanqueo Terpel'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Todos'));
      await tester.pumpAndSettle();
      expect(find.text('Viaje aeropuerto'), findsOneWidget);
      expect(find.text('Tanqueo Terpel'), findsOneWidget);
    });

    testWidgets('Movimientos tab shows empty state without transactions', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(transactionsLoader: (_) async => []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Movimientos'));
      await tester.pumpAndSettle();

      expect(find.text('No hay movimientos'), findsOneWidget);
    });

    testWidgets('Gráficos tab shows period selector and totals', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Gráficos'));
      await tester.pumpAndSettle();

      expect(find.text('7 días'), findsOneWidget);
      expect(find.text('30 días'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Ingresos'), findsWidgets);
      expect(find.text('Egresos'), findsWidgets);
      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('\$80.000'), findsOneWidget); // 120.000 - 40.000
      expect(find.text('Egresos por categoría'), findsOneWidget);
    });

    testWidgets('Gráficos tab shows empty state without incomes', (
      tester,
    ) async {
      await tester.pumpWidget(buildScreen(transactionsLoader: (_) async => []));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(Tab, 'Gráficos'));
      await tester.pumpAndSettle();

      expect(
        find.text('Debes registrar movimientos para ver los gráficos'),
        findsOneWidget,
      );
    });
  });
}
