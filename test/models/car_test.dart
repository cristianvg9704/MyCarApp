import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car.dart';

void main() {
  // UUIDs de prueba para mantener consistencia
  const String testUserId = 'test-user-uuid-123';
  const String testCarId = 'test-car-uuid-456';

  group('Car Model Tests', () {
    test('should create a Car with required fields', () {
      final car = Car(
        userId: testUserId,
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
      );

      expect(car.brand, 'Toyota');
      expect(car.model, 'Corolla');
      expect(car.year, 2020);
      expect(car.userId, testUserId);
      expect(car.id, isNull);
      expect(car.plateNumber, isNull);
      expect(car.color, isNull);
      expect(car.purchaseDate, isNull);
      expect(car.purchasePrice, isNull);
      expect(car.notes, isNull);
    });

    test('should create a Car with all fields', () {
      final purchaseDate = DateTime(2020, 1, 15);
      final car = Car(
        id: testCarId,
        userId: testUserId,
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        plateNumber: 'ABC123',
        color: 'Red',
        purchaseDate: purchaseDate,
        purchasePrice: 25000.50,
        notes: 'Great condition',
      );

      expect(car.id, testCarId);
      expect(car.userId, testUserId);
      expect(car.brand, 'Toyota');
      expect(car.model, 'Corolla');
      expect(car.year, 2020);
      expect(car.plateNumber, 'ABC123');
      expect(car.color, 'Red');
      expect(car.purchaseDate, purchaseDate);
      expect(car.purchasePrice, 25000.50);
      expect(car.notes, 'Great condition');
    });

    test('should convert Car to Map correctly', () {
      final purchaseDate = DateTime(2020, 1, 15);
      final car = Car(
        id: testCarId,
        userId: testUserId,
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        plateNumber: 'ABC123',
        color: 'Red',
        purchaseDate: purchaseDate,
        purchasePrice: 25000.50,
        notes: 'Great condition',
      );

      final map = car.toMap();

      expect(map['id'], testCarId);
      expect(map['user_id'], testUserId);
      expect(map['brand'], 'Toyota');
      expect(map['model'], 'Corolla');
      expect(map['year'], 2020);
      expect(map['plate_number'], 'ABC123');
      expect(map['color'], 'Red');
      expect(map['purchase_date'], purchaseDate.toIso8601String());
      expect(map['purchase_price'], 25000.50);
      expect(map['notes'], 'Great condition');
    });

    test('should convert Car to Map with null values', () {
      final car = Car(
        userId: testUserId,
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
      );

      final map = car.toMap();

      expect(map['id'], isNull);
      expect(map['user_id'], testUserId);
      expect(map['plate_number'], isNull);
      expect(map['color'], isNull);
      expect(map['purchase_date'], isNull);
      expect(map['purchase_price'], isNull);
      expect(map['notes'], isNull);
    });

    test('should create Car from Map correctly', () {
      final purchaseDate = DateTime(2020, 1, 15);
      final map = {
        'id': testCarId,
        'user_id': testUserId,
        'brand': 'Toyota',
        'model': 'Corolla',
        'year': 2020,
        'plate_number': 'ABC123',
        'color': 'Red',
        'purchase_date': purchaseDate.toIso8601String(),
        'purchase_price': 25000.50,
        'notes': 'Great condition',
      };

      final car = Car.fromMap(map);

      expect(car.id, testCarId);
      expect(car.userId, testUserId);
      expect(car.brand, 'Toyota');
      expect(car.model, 'Corolla');
      expect(car.year, 2020);
      expect(car.plateNumber, 'ABC123');
      expect(car.color, 'Red');
      expect(car.purchaseDate, purchaseDate);
      expect(car.purchasePrice, 25000.50);
      expect(car.notes, 'Great condition');
    });

    test('should create Car from Map with null values', () {
      final map = {
        'id': testCarId,
        'user_id': testUserId,
        'brand': 'Toyota',
        'model': 'Corolla',
        'year': 2020,
        'plate_number': null,
        'color': null,
        'purchase_date': null,
        'purchase_price': null,
        'notes': null,
      };

      final car = Car.fromMap(map);

      expect(car.id, testCarId);
      expect(car.userId, testUserId);
      expect(car.brand, 'Toyota');
      expect(car.model, 'Corolla');
      expect(car.year, 2020);
      expect(car.plateNumber, isNull);
      expect(car.color, isNull);
      expect(car.purchaseDate, isNull);
      expect(car.purchasePrice, isNull);
      expect(car.notes, isNull);
    });

    test('should handle integer purchase_price conversion', () {
      final map = {
        'id': testCarId,
        'user_id': testUserId,
        'brand': 'Toyota',
        'model': 'Corolla',
        'year': 2020,
        'purchase_price': 25000, // Integer instead of double
      };

      final car = Car.fromMap(map);

      expect(car.purchasePrice, 25000.0);
      expect(car.purchasePrice, isA<double>());
    });

    test('should round-trip convert Car to Map and back', () {
      final purchaseDate = DateTime(2020, 1, 15);
      final originalCar = Car(
        id: testCarId,
        userId: testUserId,
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        plateNumber: 'ABC123',
        color: 'Red',
        purchaseDate: purchaseDate,
        purchasePrice: 25000.50,
        notes: 'Great condition',
      );

      final map = originalCar.toMap();
      final convertedCar = Car.fromMap(map);

      expect(convertedCar.id, originalCar.id);
      expect(convertedCar.userId, originalCar.userId);
      expect(convertedCar.brand, originalCar.brand);
      expect(convertedCar.model, originalCar.model);
      expect(convertedCar.year, originalCar.year);
      expect(convertedCar.plateNumber, originalCar.plateNumber);
      expect(convertedCar.color, originalCar.color);
      expect(convertedCar.purchaseDate, originalCar.purchaseDate);
      expect(convertedCar.purchasePrice, originalCar.purchasePrice);
      expect(convertedCar.notes, originalCar.notes);
    });
  });
}
