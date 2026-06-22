import '../models/alert.dart';

/// Plantillas predefinidas para crear alertas comunes
class AlertTemplates {
  /// Plantilla para SOAT (Seguro Obligatorio de Accidentes de Tránsito)
  /// Se renueva anualmente
  static Alert createSOAT({
    required String userId,
    required String carId,
    required DateTime startDate,
    String? description,
  }) {
    return Alert(
      userId: userId,
      carId: carId,
      title: 'Renovación SOAT',
      description: description ?? 'Recordatorio para renovar el SOAT del vehículo',
      alertDate: startDate,
      isRecurring: true,
      recurrenceType: 'yearly',
      templateType: 'soat',
    );
  }

  /// Plantilla para Mantenimiento General
  /// Recurrencia configurable (por defecto cada 3 meses)
  static Alert createMaintenance({
    required String userId,
    required String carId,
    required DateTime startDate,
    String? description,
    int? monthsInterval,
  }) {
    final interval = monthsInterval ?? 3;
    return Alert(
      userId: userId,
      carId: carId,
      title: 'Mantenimiento General',
      description: description ?? 'Mantenimiento preventivo del vehículo',
      alertDate: startDate,
      isRecurring: true,
      recurrenceType: 'monthly',
      recurrenceValue: interval,
      templateType: 'maintenance',
    );
  }

  /// Plantilla para Revisión Técnica
  /// Se realiza anualmente
  static Alert createTechnicalReview({
    required String userId,
    required String carId,
    required DateTime startDate,
    String? description,
  }) {
    return Alert(
      userId: userId,
      carId: carId,
      title: 'Revisión Técnica',
      description: description ?? 'Revisión técnica obligatoria del vehículo',
      alertDate: startDate,
      isRecurring: true,
      recurrenceType: 'yearly',
      templateType: 'technical_review',
    );
  }

  /// Plantilla para Seguro del Vehículo
  /// Se renueva anualmente
  static Alert createInsurance({
    required String userId,
    required String carId,
    required DateTime startDate,
    String? description,
  }) {
    return Alert(
      userId: userId,
      carId: carId,
      title: 'Renovación Seguro',
      description: description ?? 'Recordatorio para renovar el seguro del vehículo',
      alertDate: startDate,
      isRecurring: true,
      recurrenceType: 'yearly',
      templateType: 'insurance',
    );
  }

  /// Plantilla para Cambio de Aceite
  /// Por defecto cada 3 meses o cada 5000 km (se usa tiempo por defecto)
  static Alert createOilChange({
    required String userId,
    required String carId,
    required DateTime startDate,
    String? description,
    int? monthsInterval,
  }) {
    final interval = monthsInterval ?? 3;
    return Alert(
      userId: userId,
      carId: carId,
      title: 'Cambio de Aceite',
      description: description ?? 'Recordatorio para cambio de aceite del motor',
      alertDate: startDate,
      isRecurring: true,
      recurrenceType: 'monthly',
      recurrenceValue: interval,
      templateType: 'oil_change',
    );
  }

  /// Plantilla para Cambio de Neumáticos
  /// Cada 2 años aproximadamente
  static Alert createTireChange({
    required String userId,
    required String carId,
    required DateTime startDate,
    String? description,
  }) {
    return Alert(
      userId: userId,
      carId: carId,
      title: 'Revisión/Cambio de Neumáticos',
      description: description ?? 'Revisar estado y considerar cambio de neumáticos',
      alertDate: startDate,
      isRecurring: true,
      recurrenceType: 'yearly',
      recurrenceValue: 2,
      templateType: 'tire_change',
    );
  }

  /// Plantilla personalizada (sin configuración predefinida)
  static Alert createCustom({
    required String userId,
    required String carId,
    required String title,
    required DateTime alertDate,
    String? description,
    bool isRecurring = false,
    String? recurrenceType,
    int? recurrenceValue,
  }) {
    return Alert(
      userId: userId,
      carId: carId,
      title: title,
      description: description,
      alertDate: alertDate,
      isRecurring: isRecurring,
      recurrenceType: recurrenceType,
      recurrenceValue: recurrenceValue,
      templateType: 'custom',
    );
  }

  /// Obtiene todas las plantillas disponibles con sus nombres
  static List<AlertTemplateInfo> getAvailableTemplates() {
    return [
      AlertTemplateInfo(
        id: 'soat',
        name: 'SOAT',
        description: 'Seguro Obligatorio de Accidentes de Tránsito (Anual)',
        icon: 'shield',
      ),
      AlertTemplateInfo(
        id: 'maintenance',
        name: 'Mantenimiento',
        description: 'Mantenimiento preventivo (Configurable)',
        icon: 'build',
      ),
      AlertTemplateInfo(
        id: 'technical_review',
        name: 'Revisión Técnica',
        description: 'Revisión técnica obligatoria (Anual)',
        icon: 'verified',
      ),
      AlertTemplateInfo(
        id: 'insurance',
        name: 'Seguro',
        description: 'Seguro del vehículo (Anual)',
        icon: 'security',
      ),
      AlertTemplateInfo(
        id: 'oil_change',
        name: 'Cambio de Aceite',
        description: 'Cambio de aceite del motor (Cada 3 meses)',
        icon: 'oil_barrel',
      ),
      AlertTemplateInfo(
        id: 'tire_change',
        name: 'Neumáticos',
        description: 'Revisión/Cambio de neumáticos (Cada 2 años)',
        icon: 'tire_repair',
      ),
      AlertTemplateInfo(
        id: 'custom',
        name: 'Personalizada',
        description: 'Crear alerta personalizada',
        icon: 'edit',
      ),
    ];
  }
}

/// Información sobre una plantilla de alerta
class AlertTemplateInfo {
  final String id;
  final String name;
  final String description;
  final String icon;

  AlertTemplateInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}
