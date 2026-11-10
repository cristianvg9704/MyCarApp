import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:new_my_car_app/models/car.dart';
import 'package:new_my_car_app/models/trip_log.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/providers/mileage_provider.dart';
import 'package:new_my_car_app/providers/trip_provider.dart';
import 'package:new_my_car_app/services/trip_tracking_service.dart';
import 'package:new_my_car_app/widgets/home_trip_card.dart';

class _FakeCarProvider extends CarProvider {
  final List<Car> fakeCars;

  _FakeCarProvider(this.fakeCars);

  @override
  List<Car> get cars => fakeCars;

  @override
  bool get isLoading => false;

  @override
  Future<void> loadCars() async {}
}

class _FakeTripProvider extends TripProvider {
  final List<String> started = [];
  final List<bool> stoppedWithOdometerUpdate = [];
  bool startSucceeds = true;
  ActiveTripState? live;
  double distanceKm = 0;
  Duration duration = Duration.zero;
  String? error;

  @override
  ActiveTripState? get liveTrip => live;

  @override
  bool get isTracking => live != null;

  @override
  double get liveDistanceKm => distanceKm;

  @override
  Duration get liveDuration => duration;

  @override
  String? get errorMessage => error;

  @override
  Future<bool> startTrip(String carId) async {
    started.add(carId);
    if (!startSucceeds) {
      error = 'No se pudo iniciar el GPS.';
      return false;
    }
    live = ActiveTripState(
      carId: carId,
      startedAt: DateTime.now(),
      distanceMeters: 0,
    );
    notifyListeners();
    return true;
  }

  @override
  Future<TripLog?> stopTrip({
    required MileageProvider mileageProvider,
    required bool updateOdometer,
  }) async {
    stoppedWithOdometerUpdate.add(updateOdometer);
    final carId = live!.carId;
    live = null;
    notifyListeners();
    return TripLog(
      userId: 'u1',
      carId: carId,
      distanceKm: distanceKm,
      startedAt: DateTime.now(),
      endedAt: DateTime.now(),
      durationSeconds: 0,
    );
  }
}

class _FakeMileageProvider extends MileageProvider {
  final List<String> loadedFor = [];

  @override
  double? get currentOdometerKm => 45000;

  @override
  Future<void> loadForCar(String carId) async => loadedFor.add(carId);
}

Car _car(String id, String model, {String? plate}) => Car(
  id: id,
  userId: 'u1',
  brand: 'Toyota',
  model: model,
  year: 2020,
  plateNumber: plate,
);

void main() {
  late _FakeTripProvider trips;
  late _FakeMileageProvider mileage;

  setUp(() {
    trips = _FakeTripProvider();
    mileage = _FakeMileageProvider();
  });

  Future<void> pumpCard(WidgetTester tester, List<Car> cars) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<CarProvider>.value(
            value: _FakeCarProvider(cars),
          ),
          ChangeNotifierProvider<TripProvider>.value(value: trips),
          ChangeNotifierProvider<MileageProvider>.value(value: mileage),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const Scaffold(body: HomeTripCard()),
              ),
              GoRoute(
                path: '/car-detail',
                builder: (_, state) => Text(
                  'detalle ${state.uri.queryParameters['carId']}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// La tarjeta activa tiene un timer de 1 s: se desmonta para cancelarlo.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('sin vehículos no se muestra', (tester) async {
    await pumpCard(tester, []);

    expect(find.byKey(const Key('home_trip_card_idle')), findsNothing);
    expect(find.byKey(const Key('home_trip_card_active')), findsNothing);
  });

  testWidgets('con un viaje inactivo ofrece iniciarlo', (tester) async {
    await pumpCard(tester, [_car('c1', 'Corolla')]);

    expect(find.byKey(const Key('home_trip_card_idle')), findsOneWidget);
    expect(find.text('Registrar un viaje'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('con un solo vehículo inicia el viaje de ese vehículo', (
    tester,
  ) async {
    await pumpCard(tester, [_car('c1', 'Corolla')]);

    await tester.tap(find.byKey(const Key('home_trip_start_button')));
    await tester.pump();
    await tester.pump();

    expect(trips.started, ['c1']);
    expect(
      find.text(
        'Viaje iniciado. Puedes minimizar la app o apagar la pantalla.',
      ),
      findsOneWidget,
    );
    // Pasa a mostrar el viaje en curso.
    expect(find.byKey(const Key('home_trip_card_active')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('con varios vehículos pregunta con cuál viajar', (tester) async {
    await pumpCard(tester, [
      _car('c1', 'Corolla', plate: 'AAA111'),
      _car('c2', 'Yaris', plate: 'BBB222'),
    ]);

    await tester.tap(find.byKey(const Key('home_trip_start_button')));
    await tester.pumpAndSettle();

    expect(find.text('¿Con qué vehículo vas a viajar?'), findsOneWidget);
    expect(find.text('Toyota Corolla'), findsOneWidget);
    expect(find.text('Toyota Yaris'), findsOneWidget);
    expect(trips.started, isEmpty);

    await tester.tap(find.text('Toyota Yaris'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(trips.started, ['c2']);
    await unmount(tester);
  });

  testWidgets('cerrar la elección de vehículo no inicia ningún viaje', (
    tester,
  ) async {
    await pumpCard(tester, [_car('c1', 'Corolla'), _car('c2', 'Yaris')]);

    await tester.tap(find.byKey(const Key('home_trip_start_button')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // toca fuera de la hoja
    await tester.pumpAndSettle();

    expect(trips.started, isEmpty);
    expect(find.byKey(const Key('home_trip_card_idle')), findsOneWidget);
  });

  testWidgets('si no se puede iniciar el GPS muestra el motivo', (
    tester,
  ) async {
    trips.startSucceeds = false;
    await pumpCard(tester, [_car('c1', 'Corolla')]);

    await tester.tap(find.byKey(const Key('home_trip_start_button')));
    await tester.pump();
    await tester.pump();

    expect(find.text('No se pudo iniciar el GPS.'), findsOneWidget);
    expect(find.byKey(const Key('home_trip_card_idle')), findsOneWidget);
  });

  testWidgets('con un viaje en curso muestra vehículo, distancia y duración', (
    tester,
  ) async {
    trips
      ..live = ActiveTripState(
        carId: 'c2',
        startedAt: DateTime.now(),
        distanceMeters: 12300,
      )
      ..distanceKm = 12.3
      ..duration = const Duration(minutes: 5, seconds: 7);
    await pumpCard(tester, [_car('c1', 'Corolla'), _car('c2', 'Yaris')]);

    expect(find.text('Viaje en curso'), findsOneWidget);
    expect(find.text('Toyota Yaris'), findsOneWidget);
    expect(find.text('12.3 km'), findsOneWidget);
    expect(find.text('05:07'), findsOneWidget);
    expect(find.text('Detener viaje'), findsOneWidget);
    expect(find.byKey(const Key('home_trip_start_button')), findsNothing);
    await unmount(tester);
  });

  testWidgets('detener sin distancia guarda y avisa', (tester) async {
    trips.live = ActiveTripState(
      carId: 'c1',
      startedAt: DateTime.now(),
      distanceMeters: 0,
    );
    await pumpCard(tester, [_car('c1', 'Corolla')]);

    await tester.tap(find.byKey(const Key('home_trip_stop_button')));
    await tester.pump();
    await tester.pump();

    expect(mileage.loadedFor, ['c1']);
    expect(trips.stoppedWithOdometerUpdate, [false]);
    expect(
      find.text('Viaje detenido (sin distancia registrada)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home_trip_card_idle')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('detener con distancia pregunta si se actualiza el odómetro', (
    tester,
  ) async {
    trips
      ..live = ActiveTripState(
        carId: 'c1',
        startedAt: DateTime.now(),
        distanceMeters: 10000,
      )
      ..distanceKm = 10;
    await pumpCard(tester, [_car('c1', 'Corolla')]);

    await tester.tap(find.byKey(const Key('home_trip_stop_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Finalizar viaje'), findsOneWidget);
    expect(find.textContaining('de 45000 km a 45010 km'), findsOneWidget);

    await tester.tap(find.text('Actualizar odómetro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(trips.stoppedWithOdometerUpdate, [true]);
    expect(find.text('Viaje guardado: 10.0 km'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tocar la tarjeta del viaje en curso abre el vehículo', (
    tester,
  ) async {
    trips.live = ActiveTripState(
      carId: 'c2',
      startedAt: DateTime.now(),
      distanceMeters: 0,
    );
    await pumpCard(tester, [_car('c1', 'Corolla'), _car('c2', 'Yaris')]);

    await tester.tap(find.text('Viaje en curso'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('detalle c2'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('la duración se actualiza sola cada segundo', (tester) async {
    trips
      ..live = ActiveTripState(
        carId: 'c1',
        startedAt: DateTime.now(),
        distanceMeters: 0,
      )
      ..duration = const Duration(seconds: 1);
    await pumpCard(tester, [_car('c1', 'Corolla')]);
    await tester.pump(); // arranca el timer tras el primer frame
    expect(find.text('00:01'), findsOneWidget);

    trips.duration = const Duration(seconds: 2);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('00:02'), findsOneWidget);
    await unmount(tester);
  });
}
