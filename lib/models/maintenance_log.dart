class MaintenanceLog {
  final String? id;
  final String userId;
  final String carId;
  final String serviceType;
  final double odometerKm;
  final DateTime serviceDate;
  final String? notes;
  final DateTime? createdAt;

  const MaintenanceLog({
    this.id,
    required this.userId,
    required this.carId,
    required this.serviceType,
    required this.odometerKm,
    required this.serviceDate,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'car_id': carId,
      'service_type': serviceType,
      'odometer_km': odometerKm,
      'service_date': _formatDate(serviceDate),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory MaintenanceLog.fromMap(Map<String, dynamic> map) {
    return MaintenanceLog(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      serviceType: map['service_type'] as String,
      odometerKm: (map['odometer_km'] as num).toDouble(),
      serviceDate: _parseDate(map['service_date'] as String),
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  static String _formatDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }

  static DateTime _parseDate(String value) {
    final dateOnly = value.length >= 10 ? value.substring(0, 10) : value;
    final parts = dateOnly.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
