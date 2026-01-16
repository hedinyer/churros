import 'empleado.dart';
import 'producto.dart';

class ProduccionEmpleado {
  final int id;
  final int empleadoId;
  final Empleado? empleado;
  final int productoId;
  final Producto? producto;
  final int cantidadProducida;
  final DateTime fechaProduccion;
  final DateTime horaProduccion;
  final int? pedidoFabricaId;
  final int? pedidoClienteId;
  final String? observaciones;
  final DateTime createdAt;

  ProduccionEmpleado({
    required this.id,
    required this.empleadoId,
    this.empleado,
    required this.productoId,
    this.producto,
    required this.cantidadProducida,
    required this.fechaProduccion,
    required this.horaProduccion,
    this.pedidoFabricaId,
    this.pedidoClienteId,
    this.observaciones,
    required this.createdAt,
  });

  factory ProduccionEmpleado.fromJson(
    Map<String, dynamic> json, {
    Empleado? empleado,
    Producto? producto,
  }) {
    return ProduccionEmpleado(
      id: json['id'] as int,
      empleadoId: json['empleado_id'] as int,
      empleado: empleado,
      productoId: json['producto_id'] as int,
      producto: producto,
      cantidadProducida: json['cantidad_producida'] as int,
      fechaProduccion: DateTime.parse(json['fecha_produccion'] as String),
      horaProduccion: DateTime.parse('2000-01-01T${json['hora_produccion'] as String}'),
      pedidoFabricaId: json['pedido_fabrica_id'] as int?,
      pedidoClienteId: json['pedido_cliente_id'] as int?,
      observaciones: json['observaciones'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empleado_id': empleadoId,
      'producto_id': productoId,
      'cantidad_producida': cantidadProducida,
      'fecha_produccion': fechaProduccion.toIso8601String().split('T')[0],
      'hora_produccion': horaProduccion.toIso8601String().split('T')[1].split('.')[0],
      'pedido_fabrica_id': pedidoFabricaId,
      'pedido_cliente_id': pedidoClienteId,
      'observaciones': observaciones,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
