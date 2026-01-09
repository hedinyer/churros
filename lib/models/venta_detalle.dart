import 'producto.dart';

class VentaDetalle {
  final int id;
  final int ventaId;
  final int productoId;
  final int cantidad;
  final double precioUnitario;
  final double precioTotal;
  final double descuento;
  final DateTime createdAt;
  final Producto? producto;

  VentaDetalle({
    required this.id,
    required this.ventaId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.precioTotal,
    required this.descuento,
    required this.createdAt,
    this.producto,
  });

  factory VentaDetalle.fromJson(Map<String, dynamic> json, {Producto? producto}) {
    return VentaDetalle(
      id: json['id'] as int,
      ventaId: json['venta_id'] as int,
      productoId: json['producto_id'] as int,
      cantidad: json['cantidad'] as int,
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      precioTotal: (json['precio_total'] as num).toDouble(),
      descuento: (json['descuento'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      producto: producto,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venta_id': ventaId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'precio_total': precioTotal,
      'descuento': descuento,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

