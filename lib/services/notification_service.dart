import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Inicializa el servicio de notificaciones
  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    // Aquí puedes manejar la navegación cuando se toca la notificación
    print('Notificación tocada: ${response.payload}');
  }

  /// Muestra una notificación local
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const androidDetails = AndroidNotificationDetails(
      'pedidos_channel',
      'Notificaciones de Pedidos',
      channelDescription: 'Notificaciones cuando llegan nuevos pedidos',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
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

  /// Cancela todas las notificaciones
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancela una notificación específica
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
