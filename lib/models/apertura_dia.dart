import 'sucursal.dart';

class AperturaDia {
  final int id;
  final Sucursal sucursal;
  final DateTime fechaApertura;
  final DateTime horaApertura;
  final int? usuarioApertura;
  final String estado;
  final int totalArticulos;
  final DateTime createdAt;

  AperturaDia({
    required this.id,
    required this.sucursal,
    required this.fechaApertura,
    required this.horaApertura,
    this.usuarioApertura,
    required this.estado,
    required this.totalArticulos,
    required this.createdAt,
  });

  factory AperturaDia.fromJson(Map<String, dynamic> json, {required Sucursal sucursal}) {
    // Parsear fecha_apertura (formato date: YYYY-MM-DD)
    final fechaStr = json['fecha_apertura'] as String;
    final fechaApertura = DateTime.parse(fechaStr);
    
    // Parsear hora_apertura (formato time: HH:MM:SS)
    // Puede venir como string "HH:MM:SS" o como DateTime
    DateTime horaApertura;
    final horaStr = json['hora_apertura'];
    if (horaStr is String) {
      // Si es string, parsear como hora y combinarlo con la fecha
      final partesHora = horaStr.split(':');
      if (partesHora.length >= 2) {
        final hora = int.parse(partesHora[0]);
        final minuto = int.parse(partesHora[1]);
        final segundo = partesHora.length > 2 ? int.parse(partesHora[2]) : 0;
        horaApertura = DateTime(
          fechaApertura.year,
          fechaApertura.month,
          fechaApertura.day,
          hora,
          minuto,
          segundo,
        );
      } else {
        // Fallback: usar la fecha con hora 00:00:00
        horaApertura = fechaApertura;
      }
    } else {
      // Si es DateTime, usarlo directamente
      horaApertura = DateTime.parse(horaStr.toString());
    }
    
    return AperturaDia(
      id: json['id'] as int,
      sucursal: sucursal,
      fechaApertura: fechaApertura,
      horaApertura: horaApertura,
      usuarioApertura: json['usuario_apertura'] as int?,
      estado: json['estado'] as String? ?? 'abierta',
      totalArticulos: json['total_articulos'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sucursal_id': sucursal.id,
      'fecha_apertura': fechaApertura.toIso8601String().split('T')[0], // Solo fecha
      'hora_apertura': '${horaApertura.hour.toString().padLeft(2, '0')}:${horaApertura.minute.toString().padLeft(2, '0')}:${horaApertura.second.toString().padLeft(2, '0')}', // Solo hora
      'usuario_apertura': usuarioApertura,
      'estado': estado,
      'total_articulos': totalArticulos,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
