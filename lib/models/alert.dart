class Alert {
  final String? id; // UUID de Supabase
  final String userId; // UUID del usuario propietario
  final String carId; // UUID del vehículo (referencia a cars.id)
  final String title; // Nombre de la alerta
  final String? description; // Descripción opcional
  final DateTime alertDate; // Fecha del recordatorio
  final bool isRecurring; // Si la alerta se repite
  final String? recurrenceType; // 'daily', 'weekly', 'monthly', 'yearly', 'custom_days'
  final int? recurrenceValue; // Valor para recurrencia personalizada (ej: cada X días/meses)
  final int? recurrenceCount; // Cuántas veces se ejecutará la alerta
  final String? templateType; // 'soat', 'maintenance', 'technical_review', 'insurance', 'custom'
  final String? notificationTime; // Hora de notificación en formato "HH:mm" (ej: "08:00", "14:30")
  final int? notifyDaysBefore; // Días antes para notificar (1 o 3, null si no quiere notificaciones previas)
  final bool isCompleted; // Si la alerta fue completada
  final DateTime? completedAt; // Cuándo se completó
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Alert({
    this.id,
    required this.userId,
    required this.carId,
    required this.title,
    this.description,
    required this.alertDate,
    this.isRecurring = false,
    this.recurrenceType,
    this.recurrenceValue,
    this.recurrenceCount,
    this.templateType,
    this.notificationTime,
    this.notifyDaysBefore,
    this.isCompleted = false,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'car_id': carId,
      'title': title,
      'description': description,
      // Normalizar alertDate para guardar solo fecha (sin hora) y evitar problemas de zona horaria
      'alert_date': DateTime(alertDate.year, alertDate.month, alertDate.day).toIso8601String(),
      'is_recurring': isRecurring,
      'recurrence_type': recurrenceType,
      'recurrence_value': recurrenceValue,
      if (recurrenceCount != null) 'recurrence_count': recurrenceCount,
      'template_type': templateType,
      if (notificationTime != null) 'notification_time': notificationTime,
      if (notifyDaysBefore != null) 'notify_days_before': notifyDaysBefore,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      alertDate: () {
        final parsedDate = DateTime.parse(map['alert_date'] as String);
        // Normalizar la fecha para que solo tenga fecha (sin hora) para evitar problemas de zona horaria
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
      }(),
      isRecurring: map['is_recurring'] as bool? ?? false,
      recurrenceType: map['recurrence_type'] as String?,
      recurrenceValue: map['recurrence_value'] as int?,
      recurrenceCount: map['recurrence_count'] as int?,
      templateType: map['template_type'] as String?,
      notificationTime: map['notification_time'] as String?,
      notifyDaysBefore: map['notify_days_before'] as int?,
      isCompleted: map['is_completed'] as bool? ?? false,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Calcula la próxima fecha de recurrencia basada en el tipo y valor
  DateTime? getNextRecurrenceDate() {
    if (!isRecurring || recurrenceType == null) {
      return null;
    }

    switch (recurrenceType) {
      case 'daily':
        return alertDate.add(const Duration(days: 1));
      case 'weekly':
        return alertDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          alertDate.year,
          alertDate.month + 1,
          alertDate.day,
        );
      case 'yearly':
        return DateTime(
          alertDate.year + 1,
          alertDate.month,
          alertDate.day,
        );
      case 'custom_days':
        if (recurrenceValue != null && recurrenceValue! > 0) {
          return alertDate.add(Duration(days: recurrenceValue!));
        }
        return null;
      default:
        return null;
    }
  }

  /// Crea una copia de la alerta con los campos actualizados
  Alert copyWith({
    String? id,
    String? userId,
    String? carId,
    String? title,
    String? description,
    DateTime? alertDate,
    bool? isRecurring,
    String? recurrenceType,
    int? recurrenceValue,
    int? recurrenceCount,
    String? templateType,
    String? notificationTime,
    int? notifyDaysBefore,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Alert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      carId: carId ?? this.carId,
      title: title ?? this.title,
      description: description ?? this.description,
      alertDate: alertDate ?? this.alertDate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceValue: recurrenceValue ?? this.recurrenceValue,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      templateType: templateType ?? this.templateType,
      notificationTime: notificationTime ?? this.notificationTime,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
