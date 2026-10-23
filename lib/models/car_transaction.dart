enum TransactionType {
  income('income', 'Ingreso'),
  expense('expense', 'Egreso');

  final String dbValue;
  final String label;
  const TransactionType(this.dbValue, this.label);

  static TransactionType fromDb(String? value) => TransactionType.values
      .firstWhere((t) => t.dbValue == value, orElse: () => income);
}

enum TransactionCategory {
  fuel('fuel', 'Combustible'),
  maintenance('maintenance', 'Mantenimiento'),
  other('other', 'Otros');

  final String dbValue;
  final String label;
  const TransactionCategory(this.dbValue, this.label);

  /// Devuelve null si el valor es nulo o no es una categoría conocida
  /// (los ingresos antiguos pueden tener texto libre).
  static TransactionCategory? fromDb(String? value) {
    for (final category in TransactionCategory.values) {
      if (category.dbValue == value) return category;
    }
    return null;
  }
}

/// Movimiento económico de un vehículo: ingreso o egreso.
class CarTransaction {
  final String? id; // UUID de Supabase
  final String userId; // UUID del usuario propietario
  final String carId; // UUID del vehículo (referencia a cars.id)
  final TransactionType type;
  final String description;
  final double amount; // siempre positivo; el signo lo da [type]
  final DateTime date;
  final TransactionCategory? category;
  final String? notes;
  final double? liters; // solo combustible
  final double? odometerKm; // combustible / mantenimiento
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CarTransaction({
    this.id,
    required this.userId,
    required this.carId,
    this.type = TransactionType.income,
    required this.description,
    required this.amount,
    required this.date,
    this.category,
    this.notes,
    this.liters,
    this.odometerKm,
    this.createdAt,
    this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  /// Monto con signo: positivo para ingresos, negativo para egresos.
  double get signedAmount => isIncome ? amount : -amount;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'car_id': carId,
      'type': type.dbValue,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category?.dbValue,
      'notes': notes,
      'liters': liters,
      'odometer_km': odometerKm,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CarTransaction.fromMap(Map<String, dynamic> map) {
    return CarTransaction(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      type: TransactionType.fromDb(map['type'] as String?),
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: TransactionCategory.fromDb(map['category'] as String?),
      notes: map['notes'] as String?,
      liters: (map['liters'] as num?)?.toDouble(),
      odometerKm: (map['odometer_km'] as num?)?.toDouble(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
