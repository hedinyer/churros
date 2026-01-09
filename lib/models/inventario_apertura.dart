import 'producto.dart';
import 'apertura_dia.dart';

class InventarioApertura {
  final int id;
  final AperturaDia apertura;
  final Producto producto;
  final int cantidadInicial;
  final DateTime createdAt;

  InventarioApertura({
    required this.id,
    required this.apertura,
    required this.producto,
    required this.cantidadInicial,
    required this.createdAt,
  });

  factory InventarioApertura.fromJson(Map<String, dynamic> json, {
    required AperturaDia apertura,
    required Producto producto,
  }) {
    return InventarioApertura(
      id: json['id'] as int,
      apertura: apertura,
      producto: producto,
      cantidadInicial: json['cantidad_inicial'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apertura_id': apertura.id,
      'producto_id': producto.id,
      'cantidad_inicial': cantidadInicial,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
