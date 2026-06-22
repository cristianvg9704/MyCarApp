class User {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? photoPath;

  User({
    this.id,
    required this.name,
    this.email,
    this.phone,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photo_path': photoPath,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      photoPath: map['photo_path'] as String?,
    );
  }
}
