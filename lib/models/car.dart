class Car {
  final String? id; // UUID de Supabase
  final String userId; // UUID del usuario propietario
  final String brand;
  final String model;
  final int year;
  final String? plateNumber;
  final String? color;
  final DateTime? purchaseDate;
  final double? purchasePrice;
  final String? notes;
  final String? imagePath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Car({
    this.id,
    required this.userId,
    required this.brand,
    required this.model,
    required this.year,
    this.plateNumber,
    this.color,
    this.purchaseDate,
    this.purchasePrice,
    this.notes,
    this.imagePath,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'brand': brand,
      'model': model,
      'year': year,
      'plate_number': plateNumber,
      'color': color,
      'purchase_date': purchaseDate?.toIso8601String(),
      'purchase_price': purchasePrice,
      'notes': notes,
      'image_path': imagePath,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      year: map['year'] as int,
      plateNumber: map['plate_number'] as String?,
      color: map['color'] as String?,
      purchaseDate: map['purchase_date'] != null
          ? DateTime.parse(map['purchase_date'] as String)
          : null,
      purchasePrice: map['purchase_price'] != null
          ? (map['purchase_price'] as num).toDouble()
          : null,
      notes: map['notes'] as String?,
      imagePath: map['image_path'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
