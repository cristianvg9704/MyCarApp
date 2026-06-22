import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/income.dart';

void main() {
  // UUIDs de prueba para mantener consistencia
  const String testUserId = 'test-user-uuid-123';
  const String testCarId = 'test-car-uuid-456';
  const String testIncomeId = 'test-income-uuid-789';

  group('Income Model Tests', () {
    test('should create an Income with required fields', () {
      final date = DateTime(2024, 1, 15);
      final income = Income(
        userId: testUserId,
        carId: testCarId,
        description: 'Taxi ride',
        amount: 50.00,
        date: date,
      );

      expect(income.userId, testUserId);
      expect(income.carId, testCarId);
      expect(income.description, 'Taxi ride');
      expect(income.amount, 50.00);
      expect(income.date, date);
      expect(income.id, isNull);
      expect(income.category, isNull);
      expect(income.notes, isNull);
    });

    test('should create an Income with all fields', () {
      final date = DateTime(2024, 1, 15);
      final income = Income(
        id: testIncomeId,
        userId: testUserId,
        carId: testCarId,
        description: 'Taxi ride',
        amount: 50.00,
        date: date,
        category: 'Transport',
        notes: 'Airport to downtown',
      );

      expect(income.id, testIncomeId);
      expect(income.userId, testUserId);
      expect(income.carId, testCarId);
      expect(income.description, 'Taxi ride');
      expect(income.amount, 50.00);
      expect(income.date, date);
      expect(income.category, 'Transport');
      expect(income.notes, 'Airport to downtown');
    });

    test('should convert Income to Map correctly', () {
      final date = DateTime(2024, 1, 15);
      final income = Income(
        id: testIncomeId,
        userId: testUserId,
        carId: testCarId,
        description: 'Taxi ride',
        amount: 50.00,
        date: date,
        category: 'Transport',
        notes: 'Airport to downtown',
      );

      final map = income.toMap();

      expect(map['id'], testIncomeId);
      expect(map['user_id'], testUserId);
      expect(map['car_id'], testCarId);
      expect(map['description'], 'Taxi ride');
      expect(map['amount'], 50.00);
      expect(map['date'], date.toIso8601String());
      expect(map['category'], 'Transport');
      expect(map['notes'], 'Airport to downtown');
    });

    test('should convert Income to Map with null values', () {
      final date = DateTime(2024, 1, 15);
      final income = Income(
        userId: testUserId,
        carId: testCarId,
        description: 'Taxi ride',
        amount: 50.00,
        date: date,
      );

      final map = income.toMap();

      expect(map['id'], isNull);
      expect(map['user_id'], testUserId);
      expect(map['car_id'], testCarId);
      expect(map['category'], isNull);
      expect(map['notes'], isNull);
    });

    test('should create Income from Map correctly', () {
      final date = DateTime(2024, 1, 15);
      final map = {
        'id': testIncomeId,
        'user_id': testUserId,
        'car_id': testCarId,
        'description': 'Taxi ride',
        'amount': 50.00,
        'date': date.toIso8601String(),
        'category': 'Transport',
        'notes': 'Airport to downtown',
      };

      final income = Income.fromMap(map);

      expect(income.id, testIncomeId);
      expect(income.userId, testUserId);
      expect(income.carId, testCarId);
      expect(income.description, 'Taxi ride');
      expect(income.amount, 50.00);
      expect(income.date, date);
      expect(income.category, 'Transport');
      expect(income.notes, 'Airport to downtown');
    });

    test('should create Income from Map with null values', () {
      final date = DateTime(2024, 1, 15);
      final map = {
        'id': testIncomeId,
        'user_id': testUserId,
        'car_id': testCarId,
        'description': 'Taxi ride',
        'amount': 50.00,
        'date': date.toIso8601String(),
        'category': null,
        'notes': null,
      };

      final income = Income.fromMap(map);

      expect(income.id, testIncomeId);
      expect(income.userId, testUserId);
      expect(income.carId, testCarId);
      expect(income.description, 'Taxi ride');
      expect(income.amount, 50.00);
      expect(income.date, date);
      expect(income.category, isNull);
      expect(income.notes, isNull);
    });

    test('should handle integer amount conversion', () {
      final date = DateTime(2024, 1, 15);
      final map = {
        'id': testIncomeId,
        'user_id': testUserId,
        'car_id': testCarId,
        'description': 'Taxi ride',
        'amount': 50, // Integer instead of double
        'date': date.toIso8601String(),
      };

      final income = Income.fromMap(map);

      expect(income.amount, 50.0);
      expect(income.amount, isA<double>());
    });

    test('should round-trip convert Income to Map and back', () {
      final date = DateTime(2024, 1, 15);
      final originalIncome = Income(
        id: testIncomeId,
        userId: testUserId,
        carId: testCarId,
        description: 'Taxi ride',
        amount: 50.00,
        date: date,
        category: 'Transport',
        notes: 'Airport to downtown',
      );

      final map = originalIncome.toMap();
      final convertedIncome = Income.fromMap(map);

      expect(convertedIncome.id, originalIncome.id);
      expect(convertedIncome.userId, originalIncome.userId);
      expect(convertedIncome.carId, originalIncome.carId);
      expect(convertedIncome.description, originalIncome.description);
      expect(convertedIncome.amount, originalIncome.amount);
      expect(convertedIncome.date, originalIncome.date);
      expect(convertedIncome.category, originalIncome.category);
      expect(convertedIncome.notes, originalIncome.notes);
    });

    test('should handle large amounts correctly', () {
      final date = DateTime(2024, 1, 15);
      final income = Income(
        userId: testUserId,
        carId: testCarId,
        description: 'Long distance trip',
        amount: 999999.99,
        date: date,
      );

      expect(income.amount, 999999.99);
      final map = income.toMap();
      expect(map['amount'], 999999.99);
    });
  });
}
