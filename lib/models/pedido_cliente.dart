import 'producto.dart';

class PedidoCliente {
  final int id;
  final String clienteNombre;
  final String? clienteTelefono;
  final String direccionEntrega;
  final DateTime fechaPedido;
  final DateTime horaPedido;
  final int totalItems;
  final double total;
  final String estado; // 'pendiente', 'en_preparacion', 'enviado', 'entregado', 'cancelado'
  final String? numeroPedido;
  final String? observaciones;
  final String? metodoPago;
  final bool sincronizado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? domicilio;
  final String? estadoPago;
  final DateTime? fechaPago;
  final List<PedidoClienteDetalle>? detalles;

  PedidoCliente({
    required this.id,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.direccionEntrega,
    required this.fechaPedido,
    required this.horaPedido,
    required this.totalItems,
    required this.total,
    required this.estado,
    this.numeroPedido,
    this.observaciones,
    this.metodoPago,
    required this.sincronizado,
    required this.createdAt,
    required this.updatedAt,
    this.domicilio,
    this.estadoPago,
    this.fechaPago,
    this.detalles,
  });

  factory PedidoCliente.fromJson(Map<String, dynamic> json, {
    List<PedidoClienteDetalle>? detalles,
  }) {
    return PedidoCliente(
      id: json['id'] as int,
      clienteNombre: (json['cliente_nombre'] as String).toUpperCase(),
      clienteTelefono: json['cliente_telefono'] as String?,
      direccionEntrega: (json['direccion_entrega'] as String).toUpperCase(),
      fechaPedido: DateTime.parse(json['fecha_pedido'] as String),
      horaPedido: _parseTime(json['hora_pedido'] as String),
      totalItems: json['total_items'] as int,
      total: (json['total'] as num).toDouble(),
      estado: (json['estado'] as String).toUpperCase(),
      numeroPedido: json['numero_pedido'] as String?,
      observaciones: json['observaciones'] != null ? (json['observaciones'] as String).toUpperCase() : null,
      metodoPago: json['metodo_pago'] != null ? (json['metodo_pago'] as String).toUpperCase() : null,
      sincronizado: json['sincronizado'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      domicilio: json['domicilio'] != null ? (json['domicilio'] as num).toDouble() : null,
      estadoPago: json['estado_pago'] as String?,
      fechaPago: json['fecha_pago'] != null ? DateTime.parse(json['fecha_pago'] as String) : null,
      detalles: detalles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'direccion_entrega': direccionEntrega,
      'fecha_pedido': fechaPedido.toIso8601String().split('T')[0],
      'hora_pedido': '${horaPedido.hour.toString().padLeft(2, '0')}:${horaPedido.minute.toString().padLeft(2, '0')}:${horaPedido.second.toString().padLeft(2, '0')}',
      'total_items': totalItems,
      'total': total,
      'estado': estado,
      'numero_pedido': numeroPedido,
      'observaciones': observaciones,
      'metodo_pago': metodoPago,
      'sincronizado': sincronizado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'domicilio': domicilio,
    };
  }

  static DateTime _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final second = parts.length > 2 ? int.parse(parts[2]) : 0;
        return DateTime(1970, 1, 1, hour, minute, second);
      }
    } catch (e) {
      print('Error parsing time: $timeString - $e');
    }
    return DateTime(1970, 1, 1);
  }
}

class PedidoClienteDetalle {
  final int id;
  final int pedidoId;
  final int productoId;
  final Producto? producto;
  final int cantidad;
  final double precioUnitario;
  final double precioTotal;
  final DateTime createdAt;

  PedidoClienteDetalle({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.precioTotal,
    required this.createdAt,
  });

  factory PedidoClienteDetalle.fromJson(Map<String, dynamic> json, {
    Producto? producto,
  }) {
    return PedidoClienteDetalle(
      id: json['id'] as int,
      pedidoId: json['pedido_id'] as int,
      productoId: json['producto_id'] as int,
      producto: producto,
      cantidad: json['cantidad'] as int,
      precioUnitario: (json['precio_unitario'] as num).toDouble(),
      precioTotal: (json['precio_total'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'precio_total': precioTotal,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
