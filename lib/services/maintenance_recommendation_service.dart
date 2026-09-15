import '../models/maintenance_log.dart';
import '../models/maintenance_recommendation.dart';
import '../models/mileage_reading.dart';

class MaintenanceRule {
  final String serviceType;
  final String title;
  final String description;
  final int intervalKm;
  final int intervalMonths;

  const MaintenanceRule({
    required this.serviceType,
    required this.title,
    required this.description,
    required this.intervalKm,
    required this.intervalMonths,
  });
}

class MaintenanceRecommendationService {
  static const List<MaintenanceRule> defaultRules = [
    MaintenanceRule(
      serviceType: 'oil_change',
      title: 'Cambio de aceite',
      description: 'Mantén el motor lubricado y en buen estado',
      intervalKm: 5000,
      intervalMonths: 6,
    ),
    MaintenanceRule(
      serviceType: 'tire_rotation',
      title: 'Rotación de llantas',
      description: 'Desgaste uniforme y mayor duración',
      intervalKm: 10000,
      intervalMonths: 12,
    ),
    MaintenanceRule(
      serviceType: 'air_filter',
      title: 'Filtro de aire',
      description: 'Mejor rendimiento y consumo de combustible',
      intervalKm: 15000,
      intervalMonths: 12,
    ),
    MaintenanceRule(
      serviceType: 'brake_check',
      title: 'Revisión de frenos',
      description: 'Seguridad en carretera',
      intervalKm: 20000,
      intervalMonths: 12,
    ),
    MaintenanceRule(
      serviceType: 'tire_change',
      title: 'Cambio de llantas',
      description: 'Reemplazar cuando el desgaste lo requiera',
      intervalKm: 40000,
      intervalMonths: 24,
    ),
    MaintenanceRule(
      serviceType: 'coolant',
      title: 'Refrigerante',
      description: 'Evita sobrecalentamiento del motor',
      intervalKm: 40000,
      intervalMonths: 24,
    ),
    MaintenanceRule(
      serviceType: 'general_maintenance',
      title: 'Mantenimiento general',
      description: 'Revisión preventiva completa',
      intervalKm: 10000,
      intervalMonths: 6,
    ),
  ];

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

  static List<MaintenanceRecommendation> buildRecommendations({
    required double currentOdometerKm,
    required List<MaintenanceLog> maintenanceLogs,
    DateTime? baselineDate,
  }) {
    final now = DateTime.now();
    final baseline = baselineDate ?? now;

    return defaultRules.map((rule) {
      final logs = maintenanceLogs
          .where((log) => log.serviceType == rule.serviceType)
          .toList()
        ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

      final lastLog = logs.isNotEmpty ? logs.first : null;
      final lastServiceKm = lastLog?.odometerKm ?? 0;
      final lastServiceDate = lastLog?.serviceDate ?? baseline;

      final kmSinceService =
          (currentOdometerKm - lastServiceKm).clamp(0.0, double.infinity).toDouble();
      final monthsSinceService = _monthsBetween(lastServiceDate, now);

      final kmRemaining = (rule.intervalKm - kmSinceService).toDouble();
      final monthsRemaining = rule.intervalMonths - monthsSinceService;

      final status = _resolveStatus(
        kmRemaining: kmRemaining,
        monthsRemaining: monthsRemaining,
        intervalKm: rule.intervalKm,
        intervalMonths: rule.intervalMonths,
      );

      return MaintenanceRecommendation(
        serviceType: rule.serviceType,
        title: rule.title,
        description: rule.description,
        intervalKm: rule.intervalKm,
        intervalMonths: rule.intervalMonths,
        kmSinceService: kmSinceService,
        monthsSinceService: monthsSinceService,
        kmRemaining: kmRemaining,
        monthsRemaining: monthsRemaining,
        status: status,
        lastServiceKm: lastLog?.odometerKm,
        lastServiceDate: lastLog?.serviceDate,
      );
    }).toList()
      ..sort((a, b) {
        final priority = {
          MaintenanceStatus.overdue: 0,
          MaintenanceStatus.soon: 1,
          MaintenanceStatus.ok: 2,
        };
        final byStatus = priority[a.status]!.compareTo(priority[b.status]!);
        if (byStatus != 0) return byStatus;
        return a.kmRemaining.compareTo(b.kmRemaining);
      });
  }

  static MaintenanceStatus _resolveStatus({
    required double kmRemaining,
    required int monthsRemaining,
    required int intervalKm,
    required int intervalMonths,
  }) {
    final kmOverdue = kmRemaining <= 0;
    final monthsOverdue = monthsRemaining <= 0;

    if (kmOverdue || monthsOverdue) {
      return MaintenanceStatus.overdue;
    }

    final kmSoon = kmRemaining <= intervalKm * 0.2 || kmRemaining <= 500;
    final monthsSoon = monthsRemaining <= (intervalMonths * 0.2).ceil().clamp(1, 999);

    if (kmSoon || monthsSoon) {
      return MaintenanceStatus.soon;
    }

    return MaintenanceStatus.ok;
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }
}
