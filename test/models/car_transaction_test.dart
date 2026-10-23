import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';

void main() {
  const userId = 'test-user-uuid-123';
  const carId = 'test-car-uuid-456';
  const transactionId = 'test-transaction-uuid-789';
  final date = DateTime(2024, 1, 15);

  CarTransaction income() => CarTransaction(
    userId: userId,
    carId: carId,
    description: 'Taxi ride',
    amount: 50000,
    date: date,
  );

  group('CarTransaction', () {
    test('defaults to an income without optional fields', () {
      final t = income();

      expect(t.type, TransactionType.income);
      expect(t.isIncome, isTrue);
      expect(t.isExpense, isFalse);
      expect(t.id, isNull);
      expect(t.category, isNull);
      expect(t.notes, isNull);
      expect(t.liters, isNull);
      expect(t.odometerKm, isNull);
    });

    test('signedAmount is positive for income and negative for expense', () {
      final expense = CarTransaction(
        userId: userId,
        carId: carId,
        type: TransactionType.expense,
        description: 'Tanqueo',
        amount: 30000,
        date: date,
      );

      expect(income().signedAmount, 50000);
      expect(expense.signedAmount, -30000);
    });

    test('toMap serializes an expense with fuel data', () {
      final t = CarTransaction(
        id: transactionId,
        userId: userId,
        carId: carId,
        type: TransactionType.expense,
        description: 'Tanqueo',
        amount: 30000,
        date: date,
        category: TransactionCategory.fuel,
        liters: 10.5,
        odometerKm: 45200,
        notes: 'Terpel',
      );

      final map = t.toMap();

      expect(map['id'], transactionId);
      expect(map['user_id'], userId);
      expect(map['car_id'], carId);
      expect(map['type'], 'expense');
      expect(map['category'], 'fuel');
      expect(map['amount'], 30000);
      expect(map['liters'], 10.5);
      expect(map['odometer_km'], 45200);
      expect(map['date'], date.toIso8601String());
      expect(map['notes'], 'Terpel');
    });

    test('toMap omits id when null and keeps nulls for optional fields', () {
      final map = income().toMap();

      expect(map.containsKey('id'), isFalse);
      expect(map['type'], 'income');
      expect(map['category'], isNull);
      expect(map['liters'], isNull);
      expect(map['odometer_km'], isNull);
    });

    test('fromMap treats rows without type as income (legacy rows)', () {
      final t = CarTransaction.fromMap({
        'id': transactionId,
        'user_id': userId,
        'car_id': carId,
        'description': 'Taxi ride',
        'amount': 50,
        'date': date.toIso8601String(),
        'category': 'Transport',
      });

      expect(t.type, TransactionType.income);
      expect(t.amount, 50.0);
      expect(t.amount, isA<double>());
      expect(t.category, isNull); // texto libre antiguo no es una categoría
    });

    test('fromMap parses numeric columns of any num type', () {
      final t = CarTransaction.fromMap({
        'user_id': userId,
        'car_id': carId,
        'type': 'expense',
        'description': 'Tanqueo',
        'amount': 30000,
        'date': date.toIso8601String(),
        'category': 'fuel',
        'liters': 10,
        'odometer_km': 45200,
      });

      expect(t.type, TransactionType.expense);
      expect(t.category, TransactionCategory.fuel);
      expect(t.liters, 10.0);
      expect(t.odometerKm, 45200.0);
    });

    test('round-trips through toMap and fromMap', () {
      final original = CarTransaction(
        id: transactionId,
        userId: userId,
        carId: carId,
        type: TransactionType.expense,
        description: 'Cambio de aceite',
        amount: 120000,
        date: date,
        category: TransactionCategory.maintenance,
        odometerKm: 50000,
        notes: 'Taller central',
      );

      final copy = CarTransaction.fromMap(original.toMap());

      expect(copy.id, original.id);
      expect(copy.type, original.type);
      expect(copy.description, original.description);
      expect(copy.amount, original.amount);
      expect(copy.date, original.date);
      expect(copy.category, original.category);
      expect(copy.odometerKm, original.odometerKm);
      expect(copy.notes, original.notes);
    });

    test('handles large amounts', () {
      final t = CarTransaction(
        userId: userId,
        carId: carId,
        description: 'Long trip',
        amount: 999999999.99,
        date: date,
      );

      expect(CarTransaction.fromMap(t.toMap()).amount, 999999999.99);
    });
  });

  group('enums', () {
    test('TransactionType.fromDb falls back to income', () {
      expect(TransactionType.fromDb('expense'), TransactionType.expense);
      expect(TransactionType.fromDb(null), TransactionType.income);
      expect(TransactionType.fromDb('???'), TransactionType.income);
    });

    test('TransactionCategory.fromDb returns null for unknown values', () {
      expect(
        TransactionCategory.fromDb('maintenance'),
        TransactionCategory.maintenance,
      );
      expect(TransactionCategory.fromDb(null), isNull);
      expect(TransactionCategory.fromDb('Transport'), isNull);
    });
  });
}
