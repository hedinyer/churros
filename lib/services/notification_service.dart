import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

enum NotificationSound {
  defaultSound,
  newOrder,
  factoryOrderSent,
  factoryOrderDelivered,
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _androidIcon = 'ic_notification_delivery';
  static const String _androidFactoryIcon = 'ic_notification_factory';
  
  // Callback para manejar la navegación cuando se toca una notificación
  static Function(String? payload)? onNotificationTapped;

  // Android 8+ channels (sound is fixed per channel once created)
  static const String _channelDefaultId = 'pedidos_channel';
  static const String _channelNewOrderId = 'new_order_channel_v1';
  static const String _channelFactorySentId = 'factory_order_sent_channel_v1';
  static const String _channelFactoryDeliveredId =
      'factory_order_delivered_channel_v1';

  /// Inicializa el servicio de notificaciones
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(_androidIcon);
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android channels (required for custom sounds on Android 8+)
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelDefaultId,
          'Notificaciones de Pedidos',
          description: 'Notificaciones cuando llegan nuevos pedidos',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelNewOrderId,
          'Nuevo pedido',
          description: 'Notificación cuando llega un nuevo pedido',
          importance: Importance.max,
          sound: RawResourceAndroidNotificationSound('pedido_enviado'),
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelFactorySentId,
          'Pedido enviado',
          description: 'Notificación cuando un pedido a fábrica es enviado',
          importance: Importance.max, // Máxima importancia para asegurar que se muestre
          sound: RawResourceAndroidNotificationSound('pedido_enviado'),
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelFactoryDeliveredId,
          'Pedido entregado',
          description: 'Notificación cuando un pedido a fábrica es entregado',
          importance: Importance.max, // Máxima importancia para asegurar que se muestre
          sound: RawResourceAndroidNotificationSound('pedido_entregado'),
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    // Solicitar permisos de notificaciones de forma robusta
    await _requestNotificationPermissions();
    
    _initialized = true;
  }

  /// Solicita permisos de notificaciones de forma robusta para todos los dispositivos Android
  static Future<bool> _requestNotificationPermissions() async {
    try {
      // Para Android 13+ (API 33+), usar permission_handler
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        
        if (status.isDenied || status.isPermanentlyDenied) {
          print('📱 Solicitando permiso de notificaciones...');
          
          // Solicitar permiso usando permission_handler (más confiable)
          final result = await Permission.notification.request();
          
          if (result.isGranted) {
            print('✅ Permiso de notificaciones concedido');
            return true;
          } else if (result.isPermanentlyDenied) {
            print('⚠️ Permiso de notificaciones denegado permanentemente');
            // Opcional: abrir configuración de la app
            // await openAppSettings();
            return false;
          } else {
            print('⚠️ Permiso de notificaciones denegado');
            return false;
          }
        } else if (status.isGranted) {
          print('✅ Permiso de notificaciones ya concedido');
          return true;
        }
      }
      
      // Para iOS, el permiso se solicita automáticamente con DarwinInitializationSettings
      // Para Android < 13, los permisos están en el manifest
      return true;
    } catch (e) {
      print('❌ Error solicitando permisos de notificaciones: $e');
      // Intentar método alternativo del plugin
      try {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          return granted ?? false;
        }
      } catch (e2) {
        print('❌ Error en método alternativo de permisos: $e2');
      }
      return false;
    }
  }

  /// Verifica si los permisos de notificaciones están concedidos
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      // Para iOS, verificar con el plugin
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.areNotificationsEnabled();
        return granted ?? false;
      }
      return true; // Asumir que está habilitado si no se puede verificar
    } catch (e) {
      print('Error verificando permisos de notificaciones: $e');
      return false;
    }
  }

  /// Maneja cuando se toca una notificación
  static void _onNotificationTapped(NotificationResponse response) {
    // Ejecutar el callback si está configurado
    if (onNotificationTapped != null) {
      onNotificationTapped!(response.payload);
    }
    print('Notificación tocada: ${response.payload}');
  }

  /// Muestra una notificación local
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    NotificationSound sound = NotificationSound.defaultSound,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    print('📱 Preparando notificación: $title - $body (ID: $id, Sound: $sound)');

    final (androidChannelId, androidChannelName, androidSound, iosSound, androidIcon) =
        switch (sound) {
          NotificationSound.newOrder => (
              _channelNewOrderId,
              'Nuevo pedido',
              const RawResourceAndroidNotificationSound('pedido_enviado'),
              null,
              _androidFactoryIcon,
            ),
          NotificationSound.factoryOrderSent => (
              _channelFactorySentId,
              'Pedido enviado',
              const RawResourceAndroidNotificationSound('pedido_enviado'),
              null,
              _androidFactoryIcon,
            ),
          NotificationSound.factoryOrderDelivered => (
              _channelFactoryDeliveredId,
              'Pedido entregado',
              const RawResourceAndroidNotificationSound('pedido_entregado'),
              null,
              _androidFactoryIcon,
            ),
          NotificationSound.defaultSound => (
              _channelDefaultId,
              'Notificaciones de Pedidos',
              null,
              null,
              _androidIcon,
            ),
        };

    final androidDetails = AndroidNotificationDetails(
      androidChannelId,
      androidChannelName,
      channelDescription: 'Notificaciones de pedidos',
      importance: Importance.max, // Cambiar a max para asegurar que se muestre
      priority: Priority.max, // Cambiar a max para alta prioridad
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: androidIcon,
      sound: androidSound,
      enableLights: true,
      ledColor: const Color(0xFFEC6D13),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSound,
      interruptionLevel: InterruptionLevel.timeSensitive, // iOS: notificación crítica
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      print('✅ Notificación mostrada exitosamente (ID: $id)');
    } catch (e) {
      print('❌ Error mostrando notificación: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Muestra una notificación de nuevo pedido de puntos
  static Future<void> showNewFactoryOrderNotification({
    required String sucursal,
    int? cantidadProductos,
    bool noisy = false,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Nuevo Pedido de Puntos',
      body: cantidadProductos != null
          ? 'Nuevo pedido desde $sucursal con $cantidadProductos productos'
          : 'Nuevo pedido desde $sucursal',
      payload: 'factory_order',
      sound: noisy ? NotificationSound.newOrder : NotificationSound.defaultSound,
    );
  }

  /// Muestra una notificación de nuevo pedido de cliente
  static Future<void> showNewClientOrderNotification({
    required String cliente,
    int? cantidadProductos,
    bool noisy = false,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Nuevo Pedido de Cliente',
      body: cantidadProductos != null
          ? 'Nuevo pedido de $cliente con $cantidadProductos productos'
          : 'Nuevo pedido de $cliente',
      payload: 'client_order',
      sound: noisy ? NotificationSound.newOrder : NotificationSound.defaultSound,
    );
  }

  /// Muestra una notificación de pedido entregado
  static Future<void> showDeliveredOrderNotification({
    required String tipoPedido, // 'fabrica' o 'cliente'
    String? sucursalNombre,
    String? clienteNombre,
    String? numeroPedido,
  }) async {
    String body;
    if (tipoPedido == 'fabrica') {
      final sucursal = sucursalNombre ?? 'Punto de Venta';
      final pedido = numeroPedido != null ? ' (Pedido #$numeroPedido)' : '';
      body = 'Pedido de $sucursal$pedido ha sido entregado exitosamente';
    } else {
      final cliente = clienteNombre ?? 'Cliente';
      final pedido = numeroPedido != null ? ' (Pedido #$numeroPedido)' : '';
      body = 'Pedido de $cliente$pedido ha sido entregado exitosamente';
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Pedido Entregado',
      body: body,
      payload: 'delivered_order',
    );
  }

  /// Muestra una notificación cuando un pedido a fábrica cambia de Pendiente a Enviado
  static Future<void> showFactoryOrderSentNotification({
    required String numeroPedido,
    String? sucursalNombre,
  }) async {
    // Asegurar inicialización
    if (!_initialized) {
      await initialize();
    }

    final sucursal = sucursalNombre ?? 'Fábrica';
    final pedido = numeroPedido.isNotEmpty ? ' #$numeroPedido' : '';

    print('🔔 Mostrando notificación: Pedido Enviado - Pedido$pedido desde $sucursal');

    // Usar un ID único basado en el número de pedido para evitar duplicados
    final notificationId = (numeroPedido.isNotEmpty 
        ? numeroPedido.hashCode 
        : DateTime.now().millisecondsSinceEpoch) % 100000;

    await showNotification(
      id: notificationId,
      title: 'Pedido Enviado',
      body: 'Tu pedido a fábrica$pedido ha sido enviado desde $sucursal',
      payload: 'factory_order_sent',
      sound: NotificationSound.factoryOrderSent,
    );

    print('✅ Notificación de ENVIADO mostrada exitosamente (ID: $notificationId)');
  }

  /// Muestra una notificación cuando un pedido a fábrica cambia de Enviado a Entregado
  static Future<void> showFactoryOrderDeliveredNotification({
    required String numeroPedido,
    String? sucursalNombre,
  }) async {
    // Asegurar inicialización
    if (!_initialized) {
      await initialize();
    }

    final sucursal = sucursalNombre ?? 'Fábrica';
    final pedido = numeroPedido.isNotEmpty ? ' #$numeroPedido' : '';

    print('🔔 Mostrando notificación: Pedido Entregado - Pedido$pedido desde $sucursal');

    // Usar un ID único basado en el número de pedido para evitar duplicados
    final notificationId = (numeroPedido.isNotEmpty 
        ? numeroPedido.hashCode 
        : DateTime.now().millisecondsSinceEpoch) % 100000;

    await showNotification(
      id: notificationId,
      title: 'Pedido Entregado',
      body: 'Tu pedido a fábrica$pedido ha sido entregado desde $sucursal',
      payload: 'factory_order_delivered',
      sound: NotificationSound.factoryOrderDelivered,
    );

    print('✅ Notificación de ENTREGADO mostrada exitosamente (ID: $notificationId)');
  }

  /// Cancela todas las notificaciones
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancela una notificación específica
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
