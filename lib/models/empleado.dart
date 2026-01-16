class Empleado {
  final int id;
  final String nombre;
  final String? telefono;
  final String? email;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Empleado({
    required this.id,
    required this.nombre,
    this.telefono,
    this.email,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Empleado.fromJson(Map<String, dynamic> json) {
    return Empleado(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String?,
      email: json['email'] as String?,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
      'email': email,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
