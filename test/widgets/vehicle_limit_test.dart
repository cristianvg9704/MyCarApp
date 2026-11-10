import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/utils/vehicle_modal_helper.dart';
import 'package:new_my_car_app/widgets/vehicle_limit_dialog.dart';

class _Cars extends CarProvider {
  final int count;
  final int? limit;

  _Cars(this.count, this.limit);

  @override
  List<Car> get cars => [
    for (var i = 0; i < count; i++)
      Car(id: 'c$i', userId: 'u1', brand: 'M', model: '$i', year: 2020),
  ];

  @override
  int? get vehicleLimit => limit;

  @override
  bool get canAddCar => limit == null || count < limit!;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async {}
}

void main() {
  Future<void> openAddVehicle(WidgetTester tester, CarProvider cars) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<CarProvider>.value(
        value: cars,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        VehicleModalHelper.showAddVehicleModal(context),
                    child: const Text('agregar'),
                  ),
                ),
              ),
              GoRoute(
                path: '/subscription',
                builder: (_, __) => const Scaffold(body: Text('planes')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('agregar'));
    await tester.pumpAndSettle();
  }

  group('agregar un vehículo con el plan mensual (tope 15)', () {
    testWidgets('en el tope no abre el formulario y avisa', (tester) async {
      await openAddVehicle(tester, _Cars(15, 15));

      expect(find.byType(VehicleLimitDialog), findsOneWidget);
      expect(find.text('Llegaste al límite de vehículos'), findsOneWidget);
      expect(find.textContaining('hasta 15 vehículos'), findsOneWidget);
      expect(find.textContaining('plan anual'), findsOneWidget);
      expect(find.text('Agregar Vehículo'), findsNothing);
    });

    testWidgets('"Ahora no" cierra el aviso', (tester) async {
      await openAddVehicle(tester, _Cars(15, 15));

      await tester.tap(find.byKey(const Key('vehicle_limit_dismiss')));
      await tester.pumpAndSettle();

      expect(find.byType(VehicleLimitDialog), findsNothing);
    });

    testWidgets('"Ver planes" lleva a la pantalla de planes', (tester) async {
      await openAddVehicle(tester, _Cars(15, 15));

      await tester.tap(find.byKey(const Key('vehicle_limit_see_plans')));
      await tester.pumpAndSettle();

      expect(find.text('planes'), findsOneWidget);
    });

    testWidgets('por debajo del tope sí abre el formulario', (tester) async {
      await openAddVehicle(tester, _Cars(14, 15));

      expect(find.byType(VehicleLimitDialog), findsNothing);
      expect(find.text('Agregar Vehículo'), findsOneWidget);
    });
  });

  testWidgets('plan anual: nunca hay aviso, aunque haya 40 vehículos', (
    tester,
  ) async {
    await openAddVehicle(tester, _Cars(40, null));

    expect(find.byType(VehicleLimitDialog), findsNothing);
    expect(find.text('Agregar Vehículo'), findsOneWidget);
  });
}
