import '../models/income.dart';

/// Períodos disponibles para filtrar los gráficos de ingresos.
enum ChartPeriod {
  sevenDays(days: 7),
  thirtyDays(days: 30),
  all(days: null);

  final int? days;
  const ChartPeriod({required this.days});
}

/// Agrupa los ingresos por día (sumando montos) dentro del período indicado.
///
/// El resultado está ordenado por fecha ascendente. [now] permite fijar
/// "hoy" en los tests.
List<MapEntry<DateTime, double>> groupIncomesByDay(
  List<Income> incomes,
  ChartPeriod period, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final days = period.days;
  final from = days == null ? null : today.subtract(Duration(days: days - 1));

  final grouped = <DateTime, double>{};
  for (final income in incomes) {
    final day = DateTime(income.date.year, income.date.month, income.date.day);
    if (from != null && (day.isBefore(from) || day.isAfter(today))) continue;
    grouped[day] = (grouped[day] ?? 0) + income.amount;
  }

  return grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
}
