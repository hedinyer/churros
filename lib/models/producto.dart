import 'categoria.dart';

class Producto {
  final int id;
  final String nombre;
  final String? descripcion;
  final Categoria? categoria;
  final double precio;
  final String unidadMedida;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Producto({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    required this.precio,
    required this.unidadMedida,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Producto.fromJson(Map<String, dynamic> json, {Categoria? categoria}) {
    return Producto(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      categoria: categoria,
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      unidadMedida: json['unidad_medida'] as String? ?? 'unidad',
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria_id': categoria?.id,
      'precio': precio,
      'unidad_medida': unidadMedida,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
