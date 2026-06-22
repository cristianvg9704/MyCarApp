class Income {
  final String? id; // UUID de Supabase
  final String userId; // UUID del usuario propietario
  final String carId; // UUID del vehículo (referencia a cars.id)
  final String description;
  final double amount;
  final DateTime date;
  final String? category;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Income({
    this.id,
    required this.userId,
    required this.carId,
    required this.description,
    required this.amount,
    required this.date,
    this.category,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'car_id': carId,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    return Income(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      carId: map['car_id'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
