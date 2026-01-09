class Sucursal {
  final int id;
  final String nombre;
  final String? direccion;
  final String? telefono;
  final bool activa;
  final DateTime createdAt;
  final DateTime updatedAt;

  Sucursal({
    required this.id,
    required this.nombre,
    this.direccion,
    this.telefono,
    required this.activa,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    return Sucursal(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String?,
      telefono: json['telefono'] as String?,
      activa: json['activa'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'activa': activa,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
