import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum NotificationSound {
  defaultSound,
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
          _channelFactorySentId,
          'Pedido enviado',
          description: 'Notificación cuando un pedido a fábrica es enviado',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('pedido_enviado'),
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelFactoryDeliveredId,
          'Pedido entregado',
          description: 'Notificación cuando un pedido a fábrica es entregado',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('pedido_entregado'),
        ),
      );
    }

    // Solicitar permisos en Android 13+
    if (await _notifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false) {
      _initialized = true;
    } else {
      _initialized = true;
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

    final (androidChannelId, androidChannelName, androidSound, iosSound, androidIcon) =
        switch (sound) {
          NotificationSound.factoryOrderSent => (
              _channelFactorySentId,
              'Pedido enviado',
              const RawResourceAndroidNotificationSound('pedido_enviado'),
              'pedido_enviado.aiff',
              _androidFactoryIcon,
            ),
          NotificationSound.factoryOrderDelivered => (
              _channelFactoryDeliveredId,
              'Pedido entregado',
              const RawResourceAndroidNotificationSound('pedido_entregado'),
              'pedido_entregado.aiff',
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
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: androidIcon,
      sound: androidSound,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSound,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Muestra una notificación de nuevo pedido de puntos
  static Future<void> showNewFactoryOrderNotification({
    required String sucursal,
    int? cantidadProductos,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Nuevo Pedido de Puntos',
      body: cantidadProductos != null
          ? 'Nuevo pedido desde $sucursal con $cantidadProductos productos'
          : 'Nuevo pedido desde $sucursal',
      payload: 'factory_order',
    );
  }

  /// Muestra una notificación de nuevo pedido de cliente
  static Future<void> showNewClientOrderNotification({
    required String cliente,
    int? cantidadProductos,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Nuevo Pedido de Cliente',
      body: cantidadProductos != null
          ? 'Nuevo pedido de $cliente con $cantidadProductos productos'
          : 'Nuevo pedido de $cliente',
      payload: 'client_order',
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
    final sucursal = sucursalNombre ?? 'Fábrica';
    final pedido = numeroPedido.isNotEmpty ? ' #$numeroPedido' : '';

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Pedido Enviado',
      body: 'Tu pedido a fábrica$pedido ha sido enviado desde $sucursal',
      payload: 'factory_order_sent',
      sound: NotificationSound.factoryOrderSent,
    );
  }

  /// Muestra una notificación cuando un pedido a fábrica cambia de Enviado a Entregado
  static Future<void> showFactoryOrderDeliveredNotification({
    required String numeroPedido,
    String? sucursalNombre,
  }) async {
    final sucursal = sucursalNombre ?? 'Fábrica';
    final pedido = numeroPedido.isNotEmpty ? ' #$numeroPedido' : '';

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Pedido Entregado',
      body: 'Tu pedido a fábrica$pedido ha sido entregado desde $sucursal',
      payload: 'factory_order_delivered',
      sound: NotificationSound.factoryOrderDelivered,
    );
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
