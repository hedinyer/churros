import 'sucursal.dart';
import 'user.dart' as app_user;

class Venta {
  final int id;
  final int sucursalId;
  final int usuarioId;
  final DateTime fechaVenta;
  final DateTime horaVenta;
  final double total;
  final double subtotal;
  final double descuento;
  final double impuesto;
  final String metodoPago;
  final String estado;
  final String? numeroTicket;
  final String? observaciones;
  final bool sincronizado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Sucursal? sucursal;
  final app_user.AppUser? usuario;

  Venta({
    required this.id,
    required this.sucursalId,
    required this.usuarioId,
    required this.fechaVenta,
    required this.horaVenta,
    required this.total,
    required this.subtotal,
    required this.descuento,
    required this.impuesto,
    required this.metodoPago,
    required this.estado,
    this.numeroTicket,
    this.observaciones,
    required this.sincronizado,
    required this.createdAt,
    required this.updatedAt,
    this.sucursal,
    this.usuario,
  });

  factory Venta.fromJson(Map<String, dynamic> json, {Sucursal? sucursal, app_user.AppUser? usuario}) {
    // Parsear fecha_venta
    final fechaStr = json['fecha_venta'] as String;
    final fechaVenta = DateTime.parse(fechaStr);
    
    // Parsear hora_venta
    DateTime horaVenta;
    final horaStr = json['hora_venta'];
    if (horaStr is String) {
      final partesHora = horaStr.split(':');
      if (partesHora.length >= 2) {
        final hora = int.parse(partesHora[0]);
        final minuto = int.parse(partesHora[1]);
        final segundo = partesHora.length > 2 ? int.parse(partesHora[2]) : 0;
        horaVenta = DateTime(
          fechaVenta.year,
          fechaVenta.month,
          fechaVenta.day,
          hora,
          minuto,
          segundo,
        );
      } else {
        horaVenta = fechaVenta;
      }
    } else {
      horaVenta = DateTime.parse(horaStr.toString());
    }

    return Venta(
      id: json['id'] as int,
      sucursalId: json['sucursal_id'] as int,
      usuarioId: json['usuario_id'] as int,
      fechaVenta: fechaVenta,
      horaVenta: horaVenta,
      total: (json['total'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      descuento: (json['descuento'] as num).toDouble(),
      impuesto: (json['impuesto'] as num).toDouble(),
      metodoPago: json['metodo_pago'] as String? ?? 'efectivo',
      estado: json['estado'] as String? ?? 'completada',
      numeroTicket: json['numero_ticket'] as String?,
      observaciones: json['observaciones'] as String?,
      sincronizado: json['sincronizado'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sucursal: sucursal,
      usuario: usuario,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sucursal_id': sucursalId,
      'usuario_id': usuarioId,
      'fecha_venta': fechaVenta.toIso8601String().split('T')[0],
      'hora_venta': '${horaVenta.hour.toString().padLeft(2, '0')}:${horaVenta.minute.toString().padLeft(2, '0')}:${horaVenta.second.toString().padLeft(2, '0')}',
      'total': total,
      'subtotal': subtotal,
      'descuento': descuento,
      'impuesto': impuesto,
      'metodo_pago': metodoPago,
      'estado': estado,
      'numero_ticket': numeroTicket,
      'observaciones': observaciones,
      'sincronizado': sincronizado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

