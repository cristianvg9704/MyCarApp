import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/providers/car_provider.dart';

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

    test('loadCars should set errorMessage when it fails to reach the backend', () async {
      final provider = CarProvider();

      await provider.loadCars();

      expect(provider.errorMessage, isNotNull);
    });

    test('loadCars should clear a previous errorMessage at the start of a new attempt', () async {
      final provider = CarProvider();
      await provider.loadCars();
      expect(provider.errorMessage, isNotNull);

      final retryFuture = provider.loadCars();
      expect(provider.errorMessage, isNull);

      await retryFuture;
    });

    test('loadCars should notify listeners on start and on completion', () async {
      final provider = CarProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.loadCars();

      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
