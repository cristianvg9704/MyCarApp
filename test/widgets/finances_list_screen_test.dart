import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:new_my_car_app/screens/finances_list_screen.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/services/transaction_repository.dart';
import 'package:new_my_car_app/models/car_transaction.dart';

void main() {
  Widget buildTestableScreen() {
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => CarProvider(),
              child: const FinancesListScreen(),
            ),
          ),
        ],
      ),
    );
  }

  group('FinancesListScreen Widget Tests', () {
    testWidgets('should display the app bar title and add transaction button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestableScreen());
      await tester.pump();

      expect(find.text('Finanzas'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets(
      'should display an error state with a retry button when cars fail to load',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestableScreen());

        // Sin un usuario autenticado, el intento automático de
        // carProvider.loadCars() falla, y la pantalla debe mostrar un estado
        // de error (no el estado "vacío") junto con un botón para reintentar.
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('No hay vehículos'), findsNothing);
      },
    );
  });
  group(
    'FinancesListScreen con vehículos cargados desde un provider falso',
    () {
      Widget buildWith(
        CarProvider provider, {
        TransactionRepository? repository,
      }) {
        return MaterialApp.router(
          routerConfig: _buildRouter(provider, repository),
        );
      }

      testWidgets(
        'sin vehículos carga una sola vez y deja visible "Agregar Vehículo" '
        '(no parpadea ni vuelve a cargar)',
        (WidgetTester tester) async {
          var fetches = 0;
          final provider = CarProvider(
            fetchCars: () async {
              fetches++;
              return <Car>[];
            },
          );

          await tester.pumpWidget(buildWith(provider));
          // Varios fotogramas: si la pantalla re-pidiera la carga en cada
          // rebuild, fetches seguiría creciendo y el spinner reaparecería.
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          expect(fetches, 1);
          expect(provider.hasLoaded, isTrue);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.text('No hay vehículos'), findsOneWidget);
          expect(find.text('Agregar Vehículo'), findsOneWidget);
        },
      );

      testWidgets('no vuelve a cargar si los vehículos ya estaban cargados', (
        WidgetTester tester,
      ) async {
        var fetches = 0;
        final provider = CarProvider(
          fetchCars: () async {
            fetches++;
            return <Car>[];
          },
        );
        await provider.loadCars();
        expect(fetches, 1);

        await tester.pumpWidget(buildWith(provider));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(fetches, 1);
        expect(find.text('Agregar Vehículo'), findsOneWidget);
      });

      testWidgets('con vehículos muestra la lista y su balance', (
        WidgetTester tester,
      ) async {
        final provider = CarProvider(
          fetchCars: () async => [
            Car(id: 'c1', userId: 'u1', brand: 'Mazda', model: '3', year: 2020),
          ],
        );

        await tester.pumpWidget(buildWith(provider, repository: _FakeRepo()));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('Mazda 3'), findsOneWidget);
        expect(find.text('No hay vehículos'), findsNothing);
      });

      testWidgets('un error de carga muestra Reintentar y no reintenta solo', (
        WidgetTester tester,
      ) async {
        var fetches = 0;
        final provider = CarProvider(
          fetchCars: () async {
            fetches++;
            throw Exception('sin red');
          },
        );

        await tester.pumpWidget(buildWith(provider));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(fetches, 1);
        expect(find.text('Reintentar'), findsOneWidget);
      });
    },
  );
}

GoRouter _buildRouter(CarProvider provider, TransactionRepository? repo) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => ChangeNotifierProvider<CarProvider>.value(
          value: provider,
          child: FinancesListScreen(repository: repo),
        ),
      ),
    ],
  );
}

class _FakeRepo implements TransactionRepository {
  @override
  Future<List<CarTransaction>> getByCar(String carId) async => [];

  @override
  Future<String> add(CarTransaction transaction) async => 'id';

  @override
  Future<void> update(CarTransaction transaction) async {}

  @override
  Future<void> delete(String id) async {}
}
