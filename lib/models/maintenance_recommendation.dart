/// Estado de un servicio. [needsHistory] significa que el dueño aún no ha
/// registrado suficientes veces ese servicio para derivar un intervalo.
enum MaintenanceStatus { ok, soon, overdue, needsHistory }

/// Recomendación para un tipo de servicio que el dueño ya registró al menos
/// una vez. Los intervalos salen de su propio historial; no hay valores
/// predefinidos.
class MaintenanceRecommendation {
  final String serviceType;
  final String title;
  final MaintenanceStatus status;

  /// Cuántas veces se ha registrado este servicio.
  final int recordCount;

  final double lastServiceKm;
  final DateTime lastServiceDate;
  final double kmSinceService;
  final int daysSinceService;

  /// Intervalo propio (mediana de sus servicios consecutivos). Null si el
  /// historial no alcanza.
  final double? intervalKm;
  final int? intervalDays;

  final double? kmRemaining;
  final int? daysRemaining;

  /// Fecha estimada del próximo servicio (lo primero que ocurra entre el
  /// intervalo en días y el intervalo en km según los km/día reales).
  final DateTime? estimatedDueDate;

  const MaintenanceRecommendation({
    required this.serviceType,
    required this.title,
    required this.status,
    required this.recordCount,
    required this.lastServiceKm,
    required this.lastServiceDate,
    required this.kmSinceService,
    required this.daysSinceService,
    this.intervalKm,
    this.intervalDays,
    this.kmRemaining,
    this.daysRemaining,
    this.estimatedDueDate,
  });

  bool get isOverdue => status == MaintenanceStatus.overdue;
  bool get isSoon => status == MaintenanceStatus.soon;
  bool get needsHistory => status == MaintenanceStatus.needsHistory;
  bool get hasInterval => intervalKm != null || intervalDays != null;

  /// Avance hacia el próximo servicio (0..1), el mayor entre km y días.
  /// Null si no hay intervalo.
  double? get progress {
    final ratios = <double>[
      if (intervalKm != null && intervalKm! > 0) kmSinceService / intervalKm!,
      if (intervalDays != null && intervalDays! > 0)
        daysSinceService / intervalDays!,
    ];
    if (ratios.isEmpty) return null;
    return ratios.reduce((a, b) => a > b ? a : b).clamp(0.0, 1.0);
  }

  String get statusLabel {
    switch (status) {
      case MaintenanceStatus.overdue:
        return 'Vencido';
      case MaintenanceStatus.soon:
        return 'Próximo';
      case MaintenanceStatus.ok:
        return 'Al día';
      case MaintenanceStatus.needsHistory:
        return 'Falta historial';
    }
  }
}
