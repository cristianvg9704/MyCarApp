import '../models/car_transaction.dart';

/// Períodos disponibles para filtrar los gráficos.
enum ChartPeriod {
  sevenDays(days: 7),
  thirtyDays(days: 30),
  all(days: null);

  final int? days;
  const ChartPeriod({required this.days});
}

/// Totales de un día: ingresos y egresos por separado.
class DayTotals {
  final DateTime day;
  final double income;
  final double expense;

  const DayTotals({
    required this.day,
    required this.income,
    required this.expense,
  });

  double get balance => income - expense;
}

/// Resumen de un conjunto de movimientos.
class TransactionSummary {
  final double income;
  final double expense;
  final Map<TransactionCategory, double> expenseByCategory;

  const TransactionSummary({
    required this.income,
    required this.expense,
    required this.expenseByCategory,
  });

  double get balance => income - expense;

  factory TransactionSummary.of(Iterable<CarTransaction> transactions) {
    var income = 0.0;
    var expense = 0.0;
    final byCategory = <TransactionCategory, double>{};
    for (final t in transactions) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expense += t.amount;
        final category = t.category ?? TransactionCategory.other;
        byCategory[category] = (byCategory[category] ?? 0) + t.amount;
      }
    }
    return TransactionSummary(
      income: income,
      expense: expense,
      expenseByCategory: byCategory,
    );
  }
}

/// Movimientos dentro del período indicado. [now] permite fijar "hoy" en tests.
List<CarTransaction> filterByPeriod(
  List<CarTransaction> transactions,
  ChartPeriod period, {
  DateTime? now,
}) {
  final days = period.days;
  if (days == null) return transactions;

  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final from = today.subtract(Duration(days: days - 1));

  return transactions.where((t) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    return !day.isBefore(from) && !day.isAfter(today);
  }).toList();
}

/// Agrupa los movimientos por día dentro del período, ordenado ascendente.
List<DayTotals> groupTransactionsByDay(
  List<CarTransaction> transactions,
  ChartPeriod period, {
  DateTime? now,
}) {
  final income = <DateTime, double>{};
  final expense = <DateTime, double>{};

  for (final t in filterByPeriod(transactions, period, now: now)) {
    final day = DateTime(t.date.year, t.date.month, t.date.day);
    final target = t.isIncome ? income : expense;
    target[day] = (target[day] ?? 0) + t.amount;
  }

  final days = {...income.keys, ...expense.keys}.toList()..sort();
  return [
    for (final day in days)
      DayTotals(
        day: day,
        income: income[day] ?? 0,
        expense: expense[day] ?? 0,
      ),
  ];
}
