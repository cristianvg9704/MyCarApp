import '../models/car_transaction.dart';
import '../models/maintenance_log.dart';
import '../models/mileage_reading.dart';

/// Un dato de odómetro con su fecha, venga de donde venga (lectura manual,
/// servicio registrado o movimiento de combustible/mantenimiento).
class OdometerPoint {
  final DateTime date;
  final double km;

  const OdometerPoint(this.date, this.km);
}

/// Rendimiento de combustible calculado con tanqueadas consecutivas.
class FuelEfficiency {
  final double kmPerLiter;
  final int samples; // pares de tanqueadas consecutivas usados
  final double totalKm;
  final double totalLiters;

  const FuelEfficiency({
    required this.kmPerLiter,
    required this.samples,
    required this.totalKm,
    required this.totalLiters,
  });
}

/// Resumen de uso y costos derivado únicamente de lo que registró el dueño.
/// Cada campo es null cuando todavía no hay datos suficientes.
class UsageInsights {
  final List<OdometerPoint> odometerPoints;
  final double? kmPerDay;
  final FuelEfficiency? fuelEfficiency;
  final double? costPerKm;
  final double? averageMaintenanceCost;
  final int maintenanceCount;

  const UsageInsights({
    this.odometerPoints = const [],
    this.kmPerDay,
    this.fuelEfficiency,
    this.costPerKm,
    this.averageMaintenanceCost,
    this.maintenanceCount = 0,
  });

  static const empty = UsageInsights();

  double? get kmPerMonth => kmPerDay == null ? null : kmPerDay! * 30;

  /// Último odómetro conocido (el mayor, ya filtrado por coherencia).
  double? get currentOdometerKm =>
      odometerPoints.isEmpty ? null : odometerPoints.last.km;

  bool get hasAnyData =>
      kmPerDay != null ||
      fuelEfficiency != null ||
      costPerKm != null ||
      averageMaintenanceCost != null;
}

/// Funciones puras para derivar uso, rendimiento y costos del historial.
class UsageAnalytics {
  UsageAnalytics._();

  /// Días mínimos entre el primer y el último dato de odómetro para estimar
  /// km/día. Con menos tiempo la tasa sería demasiado ruidosa para proyectar.
  static const int minSpanDaysForRate = 7;

  static UsageInsights compute({
    required List<MileageReading> readings,
    required List<MaintenanceLog> maintenanceLogs,
    required List<CarTransaction> transactions,
  }) {
    final points = collectOdometerPoints(
      readings: readings,
      maintenanceLogs: maintenanceLogs,
      transactions: transactions,
    );
    return UsageInsights(
      odometerPoints: points,
      kmPerDay: averageKmPerDay(points),
      fuelEfficiency: fuelEfficiency(transactions),
      costPerKm: costPerKm(transactions: transactions, points: points),
      averageMaintenanceCost: averageMaintenanceCost(transactions),
      maintenanceCount: maintenanceExpenses(transactions).length,
    );
  }

  /// Une todas las fuentes de odómetro en una línea de tiempo coherente:
  /// ordenada por fecha y sin valores que retrocedan (se descartan, suelen
  /// ser errores de captura). Datos iguales se conservan: un vehículo parado
  /// también cuenta como tiempo transcurrido.
  static List<OdometerPoint> collectOdometerPoints({
    required List<MileageReading> readings,
    required List<MaintenanceLog> maintenanceLogs,
    required List<CarTransaction> transactions,
  }) {
    final raw = <OdometerPoint>[
      for (final r in readings) OdometerPoint(_day(r.readingDate), r.odometerKm),
      for (final l in maintenanceLogs)
        OdometerPoint(_day(l.serviceDate), l.odometerKm),
      for (final t in transactions)
        if (t.isExpense &&
            (t.category == TransactionCategory.fuel ||
                t.category == TransactionCategory.maintenance) &&
            t.odometerKm != null &&
            t.odometerKm! > 0)
          OdometerPoint(_day(t.date), t.odometerKm!),
    ]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.km.compareTo(b.km);
      });

    final result = <OdometerPoint>[];
    for (final p in raw) {
      if (p.km < 0) continue;
      if (result.isNotEmpty && p.km < result.last.km) continue;
      result.add(p);
    }
    return result;
  }

  /// Km por día reales: (último km - primer km) / días entre ambos datos.
  /// Null si hay menos de 2 datos, el lapso es menor a [minSpanDaysForRate]
  /// o no hubo avance.
  static double? averageKmPerDay(List<OdometerPoint> points) {
    if (points.length < 2) return null;
    final first = points.first;
    final last = points.last;
    final days = last.date.difference(first.date).inHours / 24.0;
    final km = last.km - first.km;
    if (days < minSpanDaysForRate || km <= 0) return null;
    return km / days;
  }

  /// Km/L con tanqueadas consecutivas (ordenadas por odómetro): los km entre
  /// dos tanqueadas se dividen entre los litros de la segunda. Pares con
  /// odómetro que no avanza se ignoran.
  static FuelEfficiency? fuelEfficiency(List<CarTransaction> transactions) {
    final fills = transactions
        .where((t) =>
            t.isExpense &&
            t.category == TransactionCategory.fuel &&
            t.odometerKm != null &&
            t.odometerKm! > 0 &&
            t.liters != null &&
            t.liters! > 0)
        .toList()
      ..sort((a, b) {
        final byKm = a.odometerKm!.compareTo(b.odometerKm!);
        return byKm != 0 ? byKm : a.date.compareTo(b.date);
      });

    double totalKm = 0;
    double totalLiters = 0;
    var samples = 0;
    for (var i = 1; i < fills.length; i++) {
      final km = fills[i].odometerKm! - fills[i - 1].odometerKm!;
      if (km <= 0) continue;
      totalKm += km;
      totalLiters += fills[i].liters!;
      samples++;
    }
    if (samples == 0 || totalLiters <= 0) return null;
    return FuelEfficiency(
      kmPerLiter: totalKm / totalLiters,
      samples: samples,
      totalKm: totalKm,
      totalLiters: totalLiters,
    );
  }

  /// Costo operativo por km: egresos de combustible y mantenimiento fechados
  /// después del primer dato de odómetro (hasta el último) entre los km
  /// recorridos en ese lapso. Null sin km recorridos o sin gastos.
  static double? costPerKm({
    required List<CarTransaction> transactions,
    required List<OdometerPoint> points,
  }) {
    if (points.length < 2) return null;
    final first = points.first;
    final last = points.last;
    final km = last.km - first.km;
    if (km <= 0) return null;

    var total = 0.0;
    var count = 0;
    for (final t in transactions) {
      if (!t.isExpense) continue;
      if (t.category != TransactionCategory.fuel &&
          t.category != TransactionCategory.maintenance) {
        continue;
      }
      final day = _day(t.date);
      if (day.isAfter(first.date) && !day.isAfter(last.date)) {
        total += t.amount;
        count++;
      }
    }
    if (count == 0) return null;
    return total / km;
  }

  static List<CarTransaction> maintenanceExpenses(
    List<CarTransaction> transactions,
  ) =>
      transactions
          .where((t) =>
              t.isExpense && t.category == TransactionCategory.maintenance)
          .toList();

  /// Costo promedio de un mantenimiento registrado como egreso.
  static double? averageMaintenanceCost(List<CarTransaction> transactions) {
    final items = maintenanceExpenses(transactions);
    if (items.isEmpty) return null;
    return items.fold<double>(0, (sum, t) => sum + t.amount) / items.length;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
