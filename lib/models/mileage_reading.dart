class MileageReading {
  final String? id;
  final String userId;
  final String carId;
  final double odometerKm;
  final DateTime readingDate;
  final String? notes;
  final DateTime? createdAt;

  const MileageReading({
    this.id,
    required this.userId,
    required this.carId,
    required this.odometerKm,
    required this.readingDate,
    this.notes,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'car_id': carId,
      'odometer_km': odometerKm,
      'reading_date': _formatDate(readingDate),
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory MileageReading.fromMap(Map<String, dynamic> map) {
    return MileageReading(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      odometerKm: (map['odometer_km'] as num).toDouble(),
      readingDate: _parseDate(map['reading_date'] as String),
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