import '../models/maintenance_log.dart';
import '../models/maintenance_recommendation.dart';
import '../models/mileage_reading.dart';

/// Recomendaciones de mantenimiento derivadas del historial del dueño.
///
/// No existen intervalos predefinidos: solo se recomienda para los tipos de
/// servicio que el dueño ya registró, y el intervalo es la mediana de sus
/// propios servicios consecutivos (km y días).
class MaintenanceRecommendationService {
  MaintenanceRecommendationService._();

  /// Un servicio pasa a "próximo" cuando le queda este porcentaje (o menos)
  /// de su propio intervalo, en km o en días.
  static const double soonFraction = 0.2;

  /// Nombres para mostrar. Son solo etiquetas: no llevan intervalos.
  static const Map<String, String> serviceTypeLabels = {
    'oil_change': 'Cambio de aceite',
    'tire_rotation': 'Rotación de llantas',
    'air_filter': 'Filtro de aire',
    'brake_check': 'Revisión de frenos',
    'tire_change': 'Cambio de llantas',
    'coolant': 'Refrigerante',
    'general_maintenance': 'Mantenimiento general',
  };

  /// Etiqueta de un tipo; para tipos desconocidos humaniza la clave.
  static String labelFor(String serviceType) {
    final known = serviceTypeLabels[serviceType];
    if (known != null) return known;
    final words = serviceType.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Servicio';
    return words[0].toUpperCase() + words.substring(1);
  }

  /// Calcula km recorridos entre lecturas consecutivas del odómetro.
  static double calculateTrackedKm(List<MileageReading> readings) {
    if (readings.length < 2) return 0;

    final sorted = List<MileageReading>.from(readings)
      ..sort((a, b) => a.readingDate.compareTo(b.readingDate));

    double total = 0;
    for (var i = 1; i < sorted.length; i++) {
      final delta = sorted[i].odometerKm - sorted[i - 1].odometerKm;
      if (delta > 0) total += delta;
    }
    return total;
  }

  /// Mediana (promedio de los dos centrales si es par). Null si está vacía.
  static double? median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Una recomendación por cada tipo de servicio registrado.
  ///
  /// - 1 registro: estado [MaintenanceStatus.needsHistory] (sin intervalo).
  /// - 2 o más: intervalo propio (mediana de km y de días entre servicios
  ///   consecutivos) y proyección con [kmPerDay] si se conoce.
  /// - Sin registros de un tipo: no se genera recomendación.
  static List<MaintenanceRecommendation> buildRecommendations({
    required double currentOdometerKm,
    required List<MaintenanceLog> maintenanceLogs,
    required DateTime now,
    double? kmPerDay,
  }) {
    final today = _day(now);

    final byType = <String, List<MaintenanceLog>>{};
    for (final log in maintenanceLogs) {
      byType.putIfAbsent(log.serviceType, () => []).add(log);
    }

    final result = <MaintenanceRecommendation>[
      for (final entry in byType.entries)
        _buildForType(
          serviceType: entry.key,
          logs: entry.value,
          currentOdometerKm: currentOdometerKm,
          today: today,
          kmPerDay: kmPerDay,
        ),
    ];

    const priority = {
      MaintenanceStatus.overdue: 0,
      MaintenanceStatus.soon: 1,
      MaintenanceStatus.ok: 2,
      MaintenanceStatus.needsHistory: 3,
    };
    result.sort((a, b) {
      final byStatus = priority[a.status]!.compareTo(priority[b.status]!);
      if (byStatus != 0) return byStatus;
      return _dueDays(a, today).compareTo(_dueDays(b, today));
    });
    return result;
  }

  static int _dueDays(MaintenanceRecommendation r, DateTime today) {
    final due = r.estimatedDueDate;
    if (due == null) return 1 << 30;
    return due.difference(today).inDays;
  }

  static MaintenanceRecommendation _buildForType({
    required String serviceType,
    required List<MaintenanceLog> logs,
    required double currentOdometerKm,
    required DateTime today,
    required double? kmPerDay,
  }) {
    final sorted = List<MaintenanceLog>.from(logs)
      ..sort((a, b) {
        final byDate = a.serviceDate.compareTo(b.serviceDate);
        return byDate != 0 ? byDate : a.odometerKm.compareTo(b.odometerKm);
      });
    final last = sorted.last;
    final lastDay = _day(last.serviceDate);

    final kmSince = (currentOdometerKm - last.odometerKm)
        .clamp(0.0, double.infinity)
        .toDouble();
    final daysSince = today.difference(lastDay).inDays.clamp(0, 1 << 30);

    final kmDeltas = <double>[];
    final dayDeltas = <double>[];
    for (var i = 1; i < sorted.length; i++) {
      final km = sorted[i].odometerKm - sorted[i - 1].odometerKm;
      final days = _day(sorted[i].serviceDate)
          .difference(_day(sorted[i - 1].serviceDate))
          .inDays;
      if (km > 0) kmDeltas.add(km);
      if (days > 0) dayDeltas.add(days.toDouble());
    }

    final intervalKm = median(kmDeltas);
    final intervalDaysRaw = median(dayDeltas);
    final intervalDays = intervalDaysRaw?.round();

    if (intervalKm == null && intervalDays == null) {
      return MaintenanceRecommendation(
        serviceType: serviceType,
        title: labelFor(serviceType),
        status: MaintenanceStatus.needsHistory,
        recordCount: sorted.length,
        lastServiceKm: last.odometerKm,
        lastServiceDate: lastDay,
        kmSinceService: kmSince,
        daysSinceService: daysSince,
      );
    }

    final kmRemaining = intervalKm == null ? null : intervalKm - kmSince;
    final daysRemaining =
        intervalDays == null ? null : intervalDays - daysSince;

    final status = _resolveStatus(
      kmRemaining: kmRemaining,
      daysRemaining: daysRemaining,
      intervalKm: intervalKm,
      intervalDays: intervalDays,
    );

    return MaintenanceRecommendation(
      serviceType: serviceType,
      title: labelFor(serviceType),
      status: status,
      recordCount: sorted.length,
      lastServiceKm: last.odometerKm,
      lastServiceDate: lastDay,
      kmSinceService: kmSince,
      daysSinceService: daysSince,
      intervalKm: intervalKm,
      intervalDays: intervalDays,
      kmRemaining: kmRemaining,
      daysRemaining: daysRemaining,
      estimatedDueDate: _estimateDueDate(
        today: today,
        kmRemaining: kmRemaining,
        daysRemaining: daysRemaining,
        kmPerDay: kmPerDay,
      ),
    );
  }

  /// Lo primero que ocurra entre: se cumplen los días del intervalo, o se
  /// recorren los km restantes al ritmo real [kmPerDay]. Vencido → hoy.
  static DateTime? _estimateDueDate({
    required DateTime today,
    required double? kmRemaining,
    required int? daysRemaining,
    required double? kmPerDay,
  }) {
    final candidates = <int>[
      if (daysRemaining != null) daysRemaining,
      if (kmRemaining != null && kmRemaining <= 0) 0,
      if (kmRemaining != null && kmPerDay != null && kmPerDay > 0)
        (kmRemaining / kmPerDay).ceil(),
    ];
    if (candidates.isEmpty) return null;
    final days = candidates.reduce((a, b) => a < b ? a : b);
    return today.add(Duration(days: days < 0 ? 0 : days));
  }

  static MaintenanceStatus _resolveStatus({
    required double? kmRemaining,
    required int? daysRemaining,
    required double? intervalKm,
    required int? intervalDays,
  }) {
    if ((kmRemaining != null && kmRemaining <= 0) ||
        (daysRemaining != null && daysRemaining <= 0)) {
      return MaintenanceStatus.overdue;
    }

    final kmSoon = kmRemaining != null &&
        intervalKm != null &&
        kmRemaining <= intervalKm * soonFraction;
    final daysSoon = daysRemaining != null &&
        intervalDays != null &&
        daysRemaining <= intervalDays * soonFraction;

    return (kmSoon || daysSoon) ? MaintenanceStatus.soon : MaintenanceStatus.ok;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
}
