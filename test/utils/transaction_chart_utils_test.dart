import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/car_transaction.dart';
import 'package:new_my_car_app/utils/transaction_chart_utils.dart';

CarTransaction _tx(
  DateTime date,
  double amount, {
  TransactionType type = TransactionType.income,
  TransactionCategory? category,
}) => CarTransaction(
  userId: 'u1',
  carId: 'c1',
  type: type,
  description: 'x',
  amount: amount,
  date: date,
  category: category,
);

CarTransaction _expense(
  DateTime date,
  double amount, {
  TransactionCategory? category,
}) => _tx(date, amount, type: TransactionType.expense, category: category);

void main() {
  final now = DateTime(2026, 10, 23, 15, 30);

  group('groupTransactionsByDay', () {
    test('returns empty list when there are no transactions', () {
      expect(groupTransactionsByDay([], ChartPeriod.all, now: now), isEmpty);
    });

    test('sums income and expense separately for the same day', () {
      final result = groupTransactionsByDay([
        _tx(DateTime(2026, 10, 20, 8), 100),
        _tx(DateTime(2026, 10, 20, 21), 50),
        _expense(DateTime(2026, 10, 20, 12), 30),
      ], ChartPeriod.all, now: now);

      expect(result, hasLength(1));
      expect(result.single.day, DateTime(2026, 10, 20));
      expect(result.single.income, 150);
      expect(result.single.expense, 30);
      expect(result.single.balance, 120);
    });

    test('includes days that only have expenses, sorted ascending', () {
      final result = groupTransactionsByDay([
        _tx(DateTime(2026, 10, 22), 10),
        _expense(DateTime(2026, 10, 1), 20),
        _tx(DateTime(2026, 10, 10), 30),
      ], ChartPeriod.all, now: now);

      expect(result.map((e) => e.day.day), [1, 10, 22]);
      expect(result.first.income, 0);
      expect(result.first.expense, 20);
    });

    test('seven days includes today and the 6 previous days only', () {
      final result = groupTransactionsByDay([
        _tx(DateTime(2026, 10, 16), 1), // 7 days ago -> excluded
        _tx(DateTime(2026, 10, 17), 2), // 6 days ago -> included
        _tx(DateTime(2026, 10, 23, 23, 59), 3), // today -> included
      ], ChartPeriod.sevenDays, now: now);

      expect(result.map((e) => e.income), [2, 3]);
    });

    test('thirty days excludes older transactions', () {
      final result = groupTransactionsByDay([
        _tx(DateTime(2026, 9, 24), 1), // 29 days ago -> included
        _expense(DateTime(2026, 9, 23), 2), // 30 days ago -> excluded
      ], ChartPeriod.thirtyDays, now: now);

      expect(result.map((e) => e.income), [1]);
      expect(result.single.expense, 0);
    });

    test('period filters ignore future transactions, all does not', () {
      final future = _tx(DateTime(2026, 10, 30), 5);

      expect(
        groupTransactionsByDay([future], ChartPeriod.sevenDays, now: now),
        isEmpty,
      );
      expect(
        groupTransactionsByDay([future], ChartPeriod.all, now: now),
        hasLength(1),
      );
    });
  });

  group('TransactionSummary', () {
    test('is zero for an empty list', () {
      final summary = TransactionSummary.of([]);

      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.balance, 0);
      expect(summary.expenseByCategory, isEmpty);
    });

    test('computes totals, balance and expenses by category', () {
      final summary = TransactionSummary.of([
        _tx(DateTime(2026, 10, 1), 200000),
        _expense(
          DateTime(2026, 10, 2),
          30000,
          category: TransactionCategory.fuel,
        ),
        _expense(
          DateTime(2026, 10, 3),
          20000,
          category: TransactionCategory.fuel,
        ),
        _expense(
          DateTime(2026, 10, 4),
          80000,
          category: TransactionCategory.maintenance,
        ),
        _expense(DateTime(2026, 10, 5), 5000), // sin categoría -> other
      ]);

      expect(summary.income, 200000);
      expect(summary.expense, 135000);
      expect(summary.balance, 65000);
      expect(summary.expenseByCategory, {
        TransactionCategory.fuel: 50000,
        TransactionCategory.maintenance: 80000,
        TransactionCategory.other: 5000,
      });
    });

    test('balance can be negative', () {
      final summary = TransactionSummary.of([
        _tx(DateTime(2026, 10, 1), 10),
        _expense(DateTime(2026, 10, 2), 25),
      ]);

      expect(summary.balance, -15);
    });
  });

  group('filterByPeriod', () {
    test('all returns the list unchanged', () {
      final list = [_tx(DateTime(2020, 1, 1), 1)];

      expect(filterByPeriod(list, ChartPeriod.all, now: now), list);
    });
  });
}
