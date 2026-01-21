import 'sucursal.dart';
import 'user.dart' as app_user;

class PedidoFabrica {
  final int id;
  final int sucursalId;
  final Sucursal? sucursal;
  final int usuarioId;
  final app_user.AppUser? usuario;
  final DateTime fechaPedido;
  final DateTime horaPedido;
  final int totalItems;
  final String estado; // 'pendiente', 'enviado', 'entregado', 'cancelado'
  final String? numeroPedido;
  final String? observaciones;
  final bool sincronizado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PedidoFabricaDetalle>? detalles;

  PedidoFabrica({
    required this.id,
    required this.sucursalId,
    this.sucursal,
    required this.usuarioId,
    this.usuario,
    required this.fechaPedido,
    required this.horaPedido,
    required this.totalItems,
    required this.estado,
    this.numeroPedido,
    this.observaciones,
    required this.sincronizado,
    required this.createdAt,
    required this.updatedAt,
    this.detalles,
  });

  factory PedidoFabrica.fromJson(Map<String, dynamic> json, {
    Sucursal? sucursal,
    app_user.AppUser? usuario,
    List<PedidoFabricaDetalle>? detalles,
  }) {
    return PedidoFabrica(
      id: json['id'] as int,
      sucursalId: json['sucursal_id'] as int,
      sucursal: sucursal,
      usuarioId: json['usuario_id'] as int,
      usuario: usuario,
      fechaPedido: DateTime.parse(json['fecha_pedido'] as String),
      horaPedido: _parseTime(json['hora_pedido'] as String),
      totalItems: json['total_items'] as int,
      estado: (json['estado'] as String).toUpperCase(),
      numeroPedido: json['numero_pedido'] as String?,
      observaciones: json['observaciones'] != null ? (json['observaciones'] as String).toUpperCase() : null,
      sincronizado: json['sincronizado'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      detalles: detalles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sucursal_id': sucursalId,
      'usuario_id': usuarioId,
      'fecha_pedido': fechaPedido.toIso8601String().split('T')[0],
      'hora_pedido': '${horaPedido.hour.toString().padLeft(2, '0')}:${horaPedido.minute.toString().padLeft(2, '0')}:${horaPedido.second.toString().padLeft(2, '0')}',
      'total_items': totalItems,
      'estado': estado,
      'numero_pedido': numeroPedido,
      'observaciones': observaciones,
      'sincronizado': sincronizado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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

class PedidoFabricaDetalle {
  final int id;
  final int pedidoId;
  final int productoId;
  final int cantidad;
  final DateTime createdAt;

  PedidoFabricaDetalle({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    required this.cantidad,
    required this.createdAt,
  });

  factory PedidoFabricaDetalle.fromJson(Map<String, dynamic> json) {
    return PedidoFabricaDetalle(
      id: json['id'] as int,
      pedidoId: json['pedido_id'] as int,
      productoId: json['producto_id'] as int,
      cantidad: json['cantidad'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
