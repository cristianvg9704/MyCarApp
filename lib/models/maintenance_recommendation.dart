enum MaintenanceStatus { ok, soon, overdue }

class MaintenanceRecommendation {
  final String serviceType;
  final String title;
  final String description;
  final int intervalKm;
  final int intervalMonths;
  final double kmSinceService;
  final int monthsSinceService;
  final double kmRemaining;
  final int monthsRemaining;
  final MaintenanceStatus status;
  final double? lastServiceKm;
  final DateTime? lastServiceDate;

  const MaintenanceRecommendation({
    required this.serviceType,
    required this.title,
    required this.description,
    required this.intervalKm,
    required this.intervalMonths,
    required this.kmSinceService,
    required this.monthsSinceService,
    required this.kmRemaining,
    required this.monthsRemaining,
    required this.status,
    this.lastServiceKm,
    this.lastServiceDate,
  });

  bool get isOverdue => status == MaintenanceStatus.overdue;
  bool get isSoon => status == MaintenanceStatus.soon;

  String get statusLabel {
    switch (status) {
      case MaintenanceStatus.overdue:
        return 'Vencido';
      case MaintenanceStatus.soon:
        return 'Próximo';
      case MaintenanceStatus.ok:
        return 'Al día';
    }
  }
}
