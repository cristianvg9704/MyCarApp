class TripLog {
  final String? id;
  final String userId;
  final String carId;
  final double distanceKm;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final double? startOdometerKm;
  final double? endOdometerKm;
  final DateTime? createdAt;

  const TripLog({
    this.id,
    required this.userId,
    required this.carId,
    required this.distanceKm,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    this.startOdometerKm,
    this.endOdometerKm,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'car_id': carId,
      'distance_km': distanceKm,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      if (startOdometerKm != null) 'start_odometer_km': startOdometerKm,
      if (endOdometerKm != null) 'end_odometer_km': endOdometerKm,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory TripLog.fromMap(Map<String, dynamic> map) {
    return TripLog(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      distanceKm: (map['distance_km'] as num).toDouble(),
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: DateTime.parse(map['ended_at'] as String),
      durationSeconds: map['duration_seconds'] as int,
      startOdometerKm: map['start_odometer_km'] != null
          ? (map['start_odometer_km'] as num).toDouble()
          : null,
      endOdometerKm: map['end_odometer_km'] != null
          ? (map['end_odometer_km'] as num).toDouble()
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }
}
