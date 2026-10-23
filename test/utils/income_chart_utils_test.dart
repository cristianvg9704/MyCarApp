import 'package:flutter_test/flutter_test.dart';
import 'package:new_my_car_app/models/income.dart';
import 'package:new_my_car_app/utils/income_chart_utils.dart';

Income _income(DateTime date, double amount) => Income(
  userId: 'u1',
  carId: 'c1',
  description: 'Viaje',
  amount: amount,
  date: date,
);

void main() {
  final now = DateTime(2026, 10, 23, 15, 30);

  group('groupIncomesByDay', () {
    test('returns empty list when there are no incomes', () {
      expect(groupIncomesByDay([], ChartPeriod.all, now: now), isEmpty);
    });

    test('sums incomes from the same day regardless of time', () {
      final result = groupIncomesByDay([
        _income(DateTime(2026, 10, 20, 8), 100),
        _income(DateTime(2026, 10, 20, 21), 50),
      ], ChartPeriod.all, now: now);

      expect(result, hasLength(1));
      expect(result.single.key, DateTime(2026, 10, 20));
      expect(result.single.value, 150);
    });

    test('sorts days ascending', () {
      final result = groupIncomesByDay([
        _income(DateTime(2026, 10, 22), 10),
        _income(DateTime(2026, 10, 1), 20),
        _income(DateTime(2026, 10, 10), 30),
      ], ChartPeriod.all, now: now);

      expect(result.map((e) => e.key.day), [1, 10, 22]);
    });

    test('seven days includes today and the 6 previous days only', () {
      final result = groupIncomesByDay([
        _income(DateTime(2026, 10, 16), 1), // 7 days ago -> excluded
        _income(DateTime(2026, 10, 17), 2), // 6 days ago -> included
        _income(DateTime(2026, 10, 23, 23, 59), 3), // today -> included
      ], ChartPeriod.sevenDays, now: now);

      expect(result.map((e) => e.value), [2, 3]);
    });

    test('thirty days excludes older incomes', () {
      final result = groupIncomesByDay([
        _income(DateTime(2026, 9, 24), 1), // 29 days ago -> included
        _income(DateTime(2026, 9, 23), 2), // 30 days ago -> excluded
      ], ChartPeriod.thirtyDays, now: now);

      expect(result.map((e) => e.value), [1]);
    });

    test('period filters ignore future incomes, all does not', () {
      final future = _income(DateTime(2026, 10, 30), 5);

      expect(
        groupIncomesByDay([future], ChartPeriod.sevenDays, now: now),
        isEmpty,
      );
      expect(groupIncomesByDay([future], ChartPeriod.all, now: now), hasLength(1));
    });
  });
}
