import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/providers/car_provider.dart';
import 'package:new_my_car_app/models/car.dart';

void main() {
  group('CarProvider Tests', () {
    test('should start with an empty car list, not loading, no error', () {
      final provider = CarProvider();

      expect(provider.cars, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('loadCars should toggle isLoading and recover to an empty list when '
        'there is no authenticated user', () async {
      final provider = CarProvider();

      final loadFuture = provider.loadCars();
      expect(provider.isLoading, isTrue);

      await loadFuture;

      expect(provider.isLoading, isFalse);
      expect(provider.cars, isEmpty);
    });

    test(
      'loadCars should set errorMessage when it fails to reach the backend',
      () async {
        final provider = CarProvider();

        await provider.loadCars();

        expect(provider.errorMessage, isNotNull);
      },
    );

    test(
      'loadCars should clear a previous errorMessage at the start of a new attempt',
      () async {
        final provider = CarProvider();
        await provider.loadCars();
        expect(provider.errorMessage, isNotNull);

        final retryFuture = provider.loadCars();
        expect(provider.errorMessage, isNull);

        await retryFuture;
      },
    );

    test(
      'loadCars should notify listeners on start and on completion',
      () async {
        final provider = CarProvider();
        var notifications = 0;
        provider.addListener(() => notifications++);

        await provider.loadCars();

        expect(notifications, greaterThanOrEqualTo(2));
      },
    );
  });
  group('CarProvider.hasLoaded', () {
    test('empieza en false: aún no se ha cargado nada', () {
      expect(CarProvider(fetchCars: () async => <Car>[]).hasLoaded, isFalse);
    });

    test('es true tras cargar aunque no haya vehículos', () async {
      final provider = CarProvider(fetchCars: () async => <Car>[]);

      await provider.loadCars();

      expect(provider.cars, isEmpty);
      expect(provider.hasLoaded, isTrue);
      expect(provider.errorMessage, isNull);
    });

    test('es true tras un error de carga y deja el mensaje de error', () async {
      final provider = CarProvider(fetchCars: () async => throw Exception('x'));

      await provider.loadCars();

      expect(provider.hasLoaded, isTrue);
      expect(provider.errorMessage, isNotNull);
    });

    test('sigue en false mientras la primera carga está en curso', () async {
      final provider = CarProvider(fetchCars: () async => <Car>[]);

      final future = provider.loadCars();
      expect(provider.isLoading, isTrue);
      expect(provider.hasLoaded, isFalse);

      await future;
    });

    test('usa los vehículos que devuelve fetchCars', () async {
      final provider = CarProvider(
        fetchCars: () async => [
          Car(id: 'c1', userId: 'u1', brand: 'Mazda', model: '3', year: 2020),
        ],
      );

      await provider.loadCars();

      expect(provider.cars.single.brand, 'Mazda');
    });
  });

  group('límite de vehículos del plan', () {
    List<Car> cars(int n) => [
      for (var i = 0; i < n; i++)
        Car(id: 'c$i', userId: 'u1', brand: 'Marca', model: 'M$i', year: 2020),
    ];
    final newCar = Car(userId: 'u1', brand: 'Nueva', model: 'X', year: 2024);

    Future<CarProvider> loaded(int count, int? Function()? limit) async {
      final provider = CarProvider(
        fetchCars: () async => cars(count),
        vehicleLimit: limit,
      );
      await provider.loadCars();
      return provider;
    }

    test('sin límite configurado se puede agregar siempre', () async {
      final provider = await loaded(50, null);

      expect(provider.vehicleLimit, isNull);
      expect(provider.canAddCar, isTrue);
    });

    test('plan mensual: se puede agregar hasta llegar a 15', () async {
      expect((await loaded(0, () => 15)).canAddCar, isTrue);
      expect((await loaded(14, () => 15)).canAddCar, isTrue);
      expect((await loaded(15, () => 15)).canAddCar, isFalse);
      expect((await loaded(20, () => 15)).canAddCar, isFalse);
    });

    test('plan anual (límite null): sin tope', () async {
      final provider = await loaded(500, () => null);

      expect(provider.canAddCar, isTrue);
    });

    test(
      'addCar con el tope alcanzado lanza VehicleLimitReachedException',
      () async {
        final provider = await loaded(15, () => 15);

        await expectLater(
          provider.addCar(newCar),
          throwsA(
            isA<VehicleLimitReachedException>().having(
              (e) => e.limit,
              'limit',
              15,
            ),
          ),
        );
        // No se agregó nada.
        expect(provider.cars, hasLength(15));
      },
    );

    test(
      'con espacio disponible addCar sigue al guardado (no es el límite)',
      () async {
        final provider = await loaded(14, () => 15);

        // Sin backend el guardado falla, pero no por el límite.
        await expectLater(
          provider.addCar(newCar),
          throwsA(isNot(isA<VehicleLimitReachedException>())),
        );
      },
    );

    test(
      'el límite se lee en cada uso: cambiar de plan lo actualiza',
      () async {
        var limit = 15;
        final provider = await loaded(15, () => limit);
        expect(provider.canAddCar, isFalse);

        limit = 40; // por ejemplo, otro tope
        expect(provider.canAddCar, isTrue);
      },
    );

    test('el mensaje explica el tope', () {
      expect(
        const VehicleLimitReachedException(15).toString(),
        contains('15 vehículos'),
      );
    });
  });
}
