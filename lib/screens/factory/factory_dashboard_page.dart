import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../services/data_cache_service.dart';
import '../../services/notification_service.dart';
import '../../services/factory_section_tracker.dart';
import '../../services/factory_session_service.dart';
import '../../main.dart';
import 'factory_orders_list_page.dart';
import '../store/client_orders_list_page.dart';
import '../store/dispatch_page.dart';
import '../store/manual_order_page.dart';
import '../store/products_management_page.dart';
import 'employees_management_page.dart';
import 'factory_inventory_production_page.dart';
import '../store/expenses_page.dart';
import '../store/recurrent_orders_page.dart';

class FactoryDashboardPage extends StatefulWidget {
  final AppUser currentUser;

  const FactoryDashboardPage({super.key, required this.currentUser});

  @override
  State<FactoryDashboardPage> createState() => _FactoryDashboardPageState();
}

class _FactoryDashboardPageState extends State<FactoryDashboardPage>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  int _newFactoryOrdersCount = 0;
  int _newClientOrdersCount = 0;
  int _newDispatchStatusChangesCount = 0;
  int _todayFactoryOrdersCount =
      0; // Contador de pedidos pendientes del día actual
  int _todayClientOrdersCount =
      0; // Contador de pedidos de clientes y recurrentes pendientes del día actual
  int _todayDeliveredOrdersCount =
      0; // Contador de pedidos ENVIADOS del día actual

  // Animaciones para las notificaciones
  final Map<String, AnimationController> _notificationAnimations = {};
  final Map<String, bool> _hasNewNotification = {};

  // Realtime subscriptions
  RealtimeChannel? _factoryOrdersChannel;
  RealtimeChannel? _clientOrdersChannel;
  RealtimeChannel? _dispatchStatusChannel;

  Future<void> _logout() async {
    // Resetear flag de sesión de fábrica
    await FactorySessionService.setFactorySession(false);

    if (!mounted) return;

    // Navegar a la pantalla de Login y limpiar el stack de navegación
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    FactorySectionTracker.enter();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    FactorySectionTracker.exit();
    WidgetsBinding.instance.removeObserver(this);
    _factoryOrdersChannel?.unsubscribe();
    _clientOrdersChannel?.unsubscribe();
    _dispatchStatusChannel?.unsubscribe();
    // Limpiar animaciones
    for (var controller in _notificationAnimations.values) {
      controller.dispose();
    }
    _notificationAnimations.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Actualizar datos cuando la app vuelve a estar activa
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Pre-cargar productos y categorías en caché en paralelo con los conteos.
      // Así cuando el usuario entre a cualquier sección, los datos ya están listos.
      await Future.wait([
        DataCacheService.preload(),
        _loadTodayOrdersCount(),
        _loadTodayClientOrdersCount(),
        _loadTodayDeliveredOrdersCount(),
      ]);

      setState(() {
        _isLoading = false;
        // Resetear contadores cuando se recarga manualmente
        _newFactoryOrdersCount = 0;
        _newClientOrdersCount = 0;
        _newDispatchStatusChangesCount = 0;
      });
    } catch (e) {
      print('Error cargando datos de fábrica: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Carga el conteo de pedidos pendientes del día actual desde la base de datos
  Future<void> _loadTodayOrdersCount() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await SupabaseService.client
          .from('pedidos_fabrica')
          .select('id')
          .eq('estado', 'pendiente')
          .eq('fecha_pedido', today);

      if (mounted) {
        setState(() {
          _todayFactoryOrdersCount = response.length;
        });
      }
    } catch (e) {
      print('Error cargando conteo de pedidos pendientes del día: $e');
      if (mounted) {
        setState(() {
          _todayFactoryOrdersCount = 0;
        });
      }
    }
  }

  /// Carga el conteo de pedidos de clientes y recurrentes pendientes del día actual
  Future<void> _loadTodayClientOrdersCount() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Contar pedidos de clientes y recurrentes pendientes EN PARALELO
      final results = await Future.wait([
        SupabaseService.client
            .from('pedidos_clientes')
            .select('id')
            .eq('estado', 'pendiente')
            .eq('fecha_pedido', today),
        SupabaseService.client
            .from('pedidos_recurrentes')
            .select('id')
            .eq('estado', 'pendiente')
            .eq('fecha_pedido', today),
      ]);

      if (mounted) {
        setState(() {
          _todayClientOrdersCount = results[0].length + results[1].length;
        });
      }
    } catch (e) {
      print(
        'Error cargando conteo de pedidos de clientes pendientes del día: $e',
      );
      if (mounted) {
        setState(() {
          _todayClientOrdersCount = 0;
        });
      }
    }
  }

  /// Carga el conteo de pedidos ENVIADOS del día actual
  Future<void> _loadTodayDeliveredOrdersCount() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Contar TODOS los pedidos enviados EN PARALELO
      final results = await Future.wait([
        SupabaseService.client
            .from('pedidos_fabrica')
            .select('id')
            .eq('estado', 'enviado')
            .eq('fecha_pedido', today),
        SupabaseService.client
            .from('pedidos_clientes')
            .select('id')
            .eq('estado', 'enviado')
            .eq('fecha_pedido', today),
        SupabaseService.client
            .from('pedidos_recurrentes')
            .select('id')
            .eq('estado', 'enviado')
            .eq('fecha_pedido', today),
      ]);

      if (mounted) {
        setState(() {
          _todayDeliveredOrdersCount =
              results[0].length + results[1].length + results[2].length;
        });
      }
    } catch (e) {
      print('Error cargando conteo de pedidos entregados del día: $e');
      if (mounted) {
        setState(() {
          _todayDeliveredOrdersCount = 0;
        });
      }
    }
  }

  /// Configura los listeners de Supabase Realtime
  void _setupRealtimeListeners() {
    try {
      // Listener para pedidos de fábrica (pedidos_fabrica)
      _factoryOrdersChannel =
          SupabaseService.client
              .channel('factory_orders_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'pedidos_fabrica',
                callback: (payload) {
                  print(
                    'Nuevo pedido de fábrica recibido: ${payload.newRecord}',
                  );
                  _handleNewFactoryOrder(payload.newRecord);
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'pedidos_fabrica',
                callback: (payload) {
                  print('Pedido de fábrica actualizado: ${payload.newRecord}');
                  // Actualizar conteo cuando cambia el estado (solo si afecta pedidos pendientes del día)
                  final estadoAnterior = payload.oldRecord['estado'] as String?;
                  final estadoNuevo = payload.newRecord['estado'] as String?;
                  final fechaPedido =
                      payload.newRecord['fecha_pedido'] as String?;
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  if ((estadoAnterior == 'pendiente' ||
                          estadoNuevo == 'pendiente') &&
                      fechaPedido == today) {
                    _loadTodayOrdersCount();
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'pedidos_fabrica',
                callback: (payload) {
                  print('Pedido de fábrica eliminado: ${payload.oldRecord}');
                  // Actualizar conteo cuando se elimina un pedido (solo si era pendiente del día)
                  final estado = payload.oldRecord['estado'] as String?;
                  final fechaPedido =
                      payload.oldRecord['fecha_pedido'] as String?;
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  if (estado == 'pendiente' && fechaPedido == today) {
                    _loadTodayOrdersCount();
                  }
                },
              )
              .subscribe();

      // Listener para pedidos de clientes (pedidos_clientes)
      _clientOrdersChannel =
          SupabaseService.client
              .channel('client_orders_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'pedidos_clientes',
                callback: (payload) {
                  print(
                    'Nuevo pedido de cliente recibido: ${payload.newRecord}',
                  );
                  _handleNewClientOrder(payload.newRecord);
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'pedidos_clientes',
                callback: (payload) {
                  print('Pedido de cliente actualizado: ${payload.newRecord}');
                  // Actualizar conteo cuando cambia el estado (solo si afecta pedidos pendientes del día)
                  final estadoAnterior = payload.oldRecord['estado'] as String?;
                  final estadoNuevo = payload.newRecord['estado'] as String?;
                  final fechaPedido =
                      payload.newRecord['fecha_pedido'] as String?;
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  if ((estadoAnterior == 'pendiente' ||
                          estadoNuevo == 'pendiente') &&
                      fechaPedido == today) {
                    _loadTodayClientOrdersCount();
                  }
                  // Actualizar conteo de "despacho" si el estado cambia a/desde ENVIADO del día
                  if ((estadoAnterior == 'enviado' ||
                          estadoNuevo == 'enviado') &&
                      fechaPedido == today) {
                    _loadTodayDeliveredOrdersCount();
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'pedidos_clientes',
                callback: (payload) {
                  print('Pedido de cliente eliminado: ${payload.oldRecord}');
                  // Actualizar conteo cuando se elimina un pedido (solo si era pendiente del día)
                  final estado = payload.oldRecord['estado'] as String?;
                  final fechaPedido =
                      payload.oldRecord['fecha_pedido'] as String?;
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  if (estado == 'pendiente' && fechaPedido == today) {
                    _loadTodayClientOrdersCount();
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'pedidos_recurrentes',
                callback: (payload) {
                  print(
                    'Nuevo pedido recurrente recibido: ${payload.newRecord}',
                  );
                  // Manejar nuevo pedido recurrente
                  _handleNewRecurrentOrder(payload.newRecord);
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'pedidos_recurrentes',
                callback: (payload) {
                  print('Pedido recurrente actualizado: ${payload.newRecord}');
                  // Actualizar conteo cuando cambia el estado (solo si afecta pedidos pendientes del día)
                  final estadoAnterior = payload.oldRecord['estado'] as String?;
                  final estadoNuevo = payload.newRecord['estado'] as String?;
                  final fechaPedido =
                      payload.newRecord['fecha_pedido'] as String?;
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  if ((estadoAnterior == 'pendiente' ||
                          estadoNuevo == 'pendiente') &&
                      fechaPedido == today) {
                    _loadTodayClientOrdersCount();
                  }
                  // Actualizar conteo de "despacho" si el estado cambia a/desde ENVIADO del día
                  if ((estadoAnterior == 'enviado' ||
                          estadoNuevo == 'enviado') &&
                      fechaPedido == today) {
                    _loadTodayDeliveredOrdersCount();
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'pedidos_recurrentes',
                callback: (payload) {
                  print('Pedido recurrente eliminado: ${payload.oldRecord}');
                  // Actualizar conteo cuando se elimina un pedido (solo si era pendiente del día)
                  final estado = payload.oldRecord['estado'] as String?;
                  final fechaPedido =
                      payload.oldRecord['fecha_pedido'] as String?;
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  if (estado == 'pendiente' && fechaPedido == today) {
                    _loadTodayClientOrdersCount();
                  }
                },
              )
              .subscribe();

      // Listener para cambios de estado en despacho
      // Detecta cualquier cambio de estado relevante (pendiente -> enviado, enviado -> entregado, etc.)
      _dispatchStatusChannel =
          SupabaseService.client
              .channel('dispatch_status_channel')
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'pedidos_fabrica',
                callback: (payload) {
                  final newRecord = payload.newRecord;
                  final oldRecord = payload.oldRecord;

                  final estadoAnterior = oldRecord['estado'] as String?;
                  final estadoNuevo = newRecord['estado'] as String?;

                  // Detectar cualquier cambio de estado relevante para despacho
                  if (estadoAnterior != estadoNuevo &&
                      estadoNuevo != null &&
                      (estadoNuevo == 'enviado' ||
                          estadoNuevo == 'entregado' ||
                          estadoNuevo == 'en_preparacion')) {
                    print(
                      'Cambio de estado en pedido de fábrica: $estadoAnterior -> $estadoNuevo',
                    );
                    // Actualizar conteo si el estado cambia a/desde pendiente del día
                    final fechaPedido = newRecord['fecha_pedido'] as String?;
                    final today =
                        DateTime.now().toIso8601String().split('T')[0];
                    if ((estadoAnterior == 'pendiente' ||
                            estadoNuevo == 'pendiente') &&
                        fechaPedido == today) {
                      _loadTodayOrdersCount();
                    }
                    // Actualizar conteo de "despacho" si el estado cambia a/desde ENVIADO
                    if (estadoAnterior == 'enviado' ||
                        estadoNuevo == 'enviado') {
                      _loadTodayDeliveredOrdersCount();
                    }
                    _handleDispatchStatusChange(
                      newRecord,
                      'fabrica',
                      estadoAnterior,
                      estadoNuevo,
                    );
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'pedidos_clientes',
                callback: (payload) {
                  final newRecord = payload.newRecord;
                  final oldRecord = payload.oldRecord;

                  final estadoAnterior = oldRecord['estado'] as String?;
                  final estadoNuevo = newRecord['estado'] as String?;

                  // Detectar cualquier cambio de estado relevante para despacho
                  if (estadoAnterior != estadoNuevo &&
                      estadoNuevo != null &&
                      (estadoNuevo == 'enviado' ||
                          estadoNuevo == 'entregado' ||
                          estadoNuevo == 'en_preparacion')) {
                    print(
                      'Cambio de estado en pedido de cliente: $estadoAnterior -> $estadoNuevo',
                    );
                    // Actualizar conteo si el estado cambia a/desde pendiente del día
                    final fechaPedido = newRecord['fecha_pedido'] as String?;
                    final today =
                        DateTime.now().toIso8601String().split('T')[0];
                    if ((estadoAnterior == 'pendiente' ||
                            estadoNuevo == 'pendiente') &&
                        fechaPedido == today) {
                      _loadTodayClientOrdersCount();
                    }
                    // Actualizar conteo de "despacho" si el estado cambia a/desde ENVIADO
                    if (estadoAnterior == 'enviado' ||
                        estadoNuevo == 'enviado') {
                      _loadTodayDeliveredOrdersCount();
                    }
                    _handleDispatchStatusChange(
                      newRecord,
                      'cliente',
                      estadoAnterior,
                      estadoNuevo,
                    );
                  }
                },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'pedidos_recurrentes',
                callback: (payload) {
                  final newRecord = payload.newRecord;
                  final oldRecord = payload.oldRecord;

                  final estadoAnterior = oldRecord['estado'] as String?;
                  final estadoNuevo = newRecord['estado'] as String?;

                  // Detectar cualquier cambio de estado relevante para despacho
                  if (estadoAnterior != estadoNuevo &&
                      estadoNuevo != null &&
                      (estadoNuevo == 'enviado' ||
                          estadoNuevo == 'entregado' ||
                          estadoNuevo == 'en_preparacion')) {
                    print(
                      'Cambio de estado en pedido recurrente: $estadoAnterior -> $estadoNuevo',
                    );
                    // Actualizar conteo si el estado cambia a/desde pendiente del día
                    final fechaPedido = newRecord['fecha_pedido'] as String?;
                    final today =
                        DateTime.now().toIso8601String().split('T')[0];
                    if ((estadoAnterior == 'pendiente' ||
                            estadoNuevo == 'pendiente') &&
                        fechaPedido == today) {
                      _loadTodayClientOrdersCount();
                    }
                    // Actualizar conteo de "despacho" si el estado cambia a/desde ENVIADO
                    if (estadoAnterior == 'enviado' ||
                        estadoNuevo == 'enviado') {
                      _loadTodayDeliveredOrdersCount();
                    }
                    _handleDispatchStatusChange(
                      newRecord,
                      'recurrente',
                      estadoAnterior,
                      estadoNuevo,
                    );
                  }
                },
              )
              .subscribe();

      print('Listeners de Realtime configurados correctamente');
    } catch (e) {
      print('Error configurando listeners de Realtime: $e');
    }
  }

  /// Maneja cuando llega un nuevo pedido de fábrica
  void _handleNewFactoryOrder(Map<String, dynamic> newOrder) {
    if (mounted) {
      setState(() {
        _newFactoryOrdersCount++;
        _hasNewNotification['factory'] = true;
      });

      // Si el nuevo pedido es del día actual, actualizar el conteo
      final fechaPedido = newOrder['fecha_pedido'] as String?;
      final today = DateTime.now().toIso8601String().split('T')[0];
      if (fechaPedido == today) {
        _loadTodayOrdersCount();
      }

      // Obtener información del pedido para la notificación
      final sucursalNombre =
          newOrder['sucursal_nombre'] as String? ?? 'Punto de Venta';
      final totalItems = newOrder['total_items'] as int?;

      // Mostrar notificación push ruidosa
      NotificationService.showNewFactoryOrderNotification(
        sucursal: sucursalNombre,
        cantidadProductos: totalItems,
        noisy: true, // Notificación ruidosa
      );

      // Iniciar animación de notificación
      _triggerNotificationAnimation('factory');

      // Actualizar resumen
      _loadData();
    }
  }

  /// Maneja cuando llega un nuevo pedido de cliente
  void _handleNewClientOrder(Map<String, dynamic> newOrder) {
    if (mounted) {
      setState(() {
        _newClientOrdersCount++;
        _hasNewNotification['client'] = true;
      });

      // Obtener información del pedido para la notificación
      final clienteNombre = newOrder['cliente_nombre'] as String? ?? 'Cliente';
      final totalItems = newOrder['total_items'] as int?;

      // Mostrar notificación push ruidosa
      NotificationService.showNewClientOrderNotification(
        cliente: clienteNombre,
        cantidadProductos: totalItems,
        noisy: true, // Notificación ruidosa
      );

      // Iniciar animación de notificación
      _triggerNotificationAnimation('client');

      // Actualizar resumen
      _loadData();
    }
  }

  /// Maneja cuando llega un nuevo pedido recurrente
  void _handleNewRecurrentOrder(Map<String, dynamic> newOrder) {
    if (mounted) {
      setState(() {
        _newClientOrdersCount++;
        _hasNewNotification['client'] = true;
      });

      // Actualizar conteo si es pendiente del día actual
      final estado = newOrder['estado'] as String?;
      final fechaPedido = newOrder['fecha_pedido'] as String?;
      final today = DateTime.now().toIso8601String().split('T')[0];
      if (estado == 'pendiente' && fechaPedido == today) {
        _loadTodayClientOrdersCount();
      }

      // Obtener información del pedido para la notificación
      final clienteNombre =
          newOrder['cliente_nombre'] as String? ?? 'Cliente Recurrente';
      final totalItems = newOrder['total_items'] as int?;

      // Mostrar notificación push ruidosa
      NotificationService.showNewClientOrderNotification(
        cliente: clienteNombre,
        cantidadProductos: totalItems,
        noisy: true, // Notificación ruidosa
      );

      // Iniciar animación de notificación
      _triggerNotificationAnimation('client');

      // Actualizar resumen
      _loadData();
    }
  }

  /// Maneja cambios de estado en despacho
  void _handleDispatchStatusChange(
    Map<String, dynamic> orderData,
    String tipo,
    String? estadoAnterior,
    String estadoNuevo,
  ) {
    if (mounted) {
      // Solo mostrar notificación cuando el estado cambia a "entregado"
      if (estadoNuevo == 'entregado') {
        setState(() {
          _newDispatchStatusChangesCount++;
          _hasNewNotification['dispatch'] = true;
        });

        // Iniciar animación de notificación
        _triggerNotificationAnimation('dispatch');

        // Obtener información del pedido
        String? sucursalNombre;
        String? clienteNombre;
        String? numeroPedido;

        if (tipo == 'fabrica') {
          sucursalNombre = orderData['sucursal_nombre'] as String?;
          numeroPedido = orderData['numero_pedido'] as String?;
        } else {
          clienteNombre = orderData['cliente_nombre'] as String?;
          numeroPedido = orderData['numero_pedido'] as String?;
        }

        // Mostrar notificación push para entregas
        NotificationService.showDeliveredOrderNotification(
          tipoPedido: tipo,
          sucursalNombre: sucursalNombre,
          clienteNombre: clienteNombre,
          numeroPedido: numeroPedido,
        );
      }

      // Actualizar resumen
      _loadData();
    }
  }

  /// Inicia una animación de notificación para una card específica
  void _triggerNotificationAnimation(String cardKey) {
    // La animación se manejará visualmente en el widget
    // Resetear después de un tiempo
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _hasNewNotification[cardKey] = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 600;
    final isVerySmallScreen = screenWidth < 400;

    // Tamaños responsive
    final headerFontSize =
        isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final sectionTitleFontSize =
        isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final buttonTitleFontSize =
        isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 16.0);
    final buttonSubtitleFontSize =
        isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0);
    final bottomButtonFontSize =
        isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0);
    final iconSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 22.0 : 24.0);
    final buttonPadding =
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0);
    final gridSpacing =
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header Sticky
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: (isDark
                        ? const Color(0xFF221810)
                        : const Color(0xFFF8F7F6))
                    .withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'FÁBRICA CENTRAL',
                      style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    icon: Icon(
                      Icons.logout,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                    tooltip: 'Cerrar sesión',
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 20,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Accesos Directos Section
                              Text(
                                'ACCESOS DIRECTOS',
                                style: TextStyle(
                                  fontSize: sectionTitleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              SizedBox(height: isVerySmallScreen ? 12 : 16),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: gridSpacing,
                                mainAxisSpacing: gridSpacing,
                                childAspectRatio: isVerySmallScreen ? 1.0 : 1.1,
                                children: [
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.storefront,
                                    iconColor: Colors.blue,
                                    title: 'PEDIDOS PUNTOS',
                                    subtitle: 'APP INTERNA',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    notificationCount:
                                        _todayFactoryOrdersCount > 0
                                            ? _todayFactoryOrdersCount
                                            : null,
                                    hasNewNotification:
                                        _hasNewNotification['factory'] == true,
                                    onTap: () async {
                                      // Resetear contador de nuevos al entrar
                                      setState(() {
                                        _newFactoryOrdersCount = 0;
                                        _hasNewNotification['factory'] = false;
                                      });
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const FactoryOrdersListPage(),
                                        ),
                                      );
                                      // Actualizar resumen al volver
                                      _loadData();
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.chat,
                                    iconColor: Colors.green,
                                    title: 'PEDIDOS CLIENTES',
                                    subtitle: 'WHATSAPP',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    notificationCount:
                                        _todayClientOrdersCount > 0
                                            ? _todayClientOrdersCount
                                            : null,
                                    hasNewNotification:
                                        _hasNewNotification['client'] == true,
                                    onTap: () async {
                                      // Resetear contador al entrar
                                      setState(() {
                                        _newClientOrdersCount = 0;
                                        _hasNewNotification['client'] = false;
                                      });
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const ClientOrdersListPage(),
                                        ),
                                      );
                                      // Actualizar resumen al volver
                                      _loadData();
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.repeat,
                                    iconColor: Colors.teal,
                                    title: 'PEDIDO RECURRENTE',
                                    subtitle: 'CLIENTES FIJOS',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const RecurrentOrdersPage(),
                                        ),
                                      );
                                      // Actualizar resumen al volver
                                      _loadData();
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.restaurant,
                                    iconColor: primaryColor,
                                    title: 'PRODUCCIÓN',
                                    subtitle: 'GESTIÓN COCINA',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const FactoryInventoryProductionPage(),
                                        ),
                                      );
                                      // Actualizar resumen al volver
                                      _loadData();
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.local_shipping,
                                    iconColor: Colors.grey,
                                    title: 'DESPACHO',
                                    subtitle: 'LOGÍSTICA',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    notificationCount:
                                        _todayDeliveredOrdersCount > 0
                                            ? _todayDeliveredOrdersCount
                                            : null,
                                    hasNewNotification:
                                        _hasNewNotification['dispatch'] == true,
                                    onTap: () {
                                      // Resetear contador al entrar
                                      setState(() {
                                        _newDispatchStatusChangesCount = 0;
                                        _hasNewNotification['dispatch'] = false;
                                      });
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => const DispatchPage(),
                                        ),
                                      ).then((_) {
                                        // Actualizar resumen al volver
                                        _loadData();
                                      });
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.inventory_2,
                                    iconColor: Colors.orange,
                                    title: 'PRODUCTOS',
                                    subtitle: 'GESTIÓN',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const ProductsManagementPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.people,
                                    iconColor: Colors.purple,
                                    title: 'EMPLEADOS',
                                    subtitle: 'GESTIÓN',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const EmployeesManagementPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildAccessButton(
                                    isDark: isDark,
                                    icon: Icons.receipt_long,
                                    iconColor: Colors.red,
                                    title: 'GASTOS',
                                    subtitle: 'Pagos y Compras',
                                    titleFontSize: buttonTitleFontSize,
                                    subtitleFontSize: buttonSubtitleFontSize,
                                    iconSize: iconSize,
                                    padding: buttonPadding,
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => const ExpensesPage(),
                                        ),
                                      );
                                      // Actualizar resumen al volver
                                      _loadData();
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 100,
                              ), // Space for bottom button
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
      // Fixed Bottom Button
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: isSmallScreen ? 16 : 20,
          right: isSmallScreen ? 16 : 20,
          top: 16,
          bottom: 16 + mediaQuery.padding.bottom,
        ),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6))
              .withOpacity(0.8),
          border: Border(
            top: BorderSide(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
            ),
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManualOrderPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : const Color(0xFF1B130D),
              foregroundColor: isDark ? const Color(0xFF221810) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle,
                  size: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 24),
                ),
                SizedBox(width: isVerySmallScreen ? 6 : 8),
                Flexible(
                  child: Text(
                    'REGISTRAR PEDIDO MANUAL',
                    style: TextStyle(
                      fontSize: bottomButtonFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessButton({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    int? notificationCount,
    bool hasNewNotification = false,
    required VoidCallback onTap,
    double? titleFontSize,
    double? subtitleFontSize,
    double? iconSize,
    double? padding,
  }) {
    final effectiveTitleFontSize = titleFontSize ?? 16.0;
    final effectiveSubtitleFontSize = subtitleFontSize ?? 12.0;
    final effectiveIconSize = iconSize ?? 24.0;
    final effectivePadding = padding ?? 20.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(effectivePadding),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D211A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                hasNewNotification
                    ? iconColor.withOpacity(0.5)
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1)),
            width: hasNewNotification ? 2 : 1,
          ),
          boxShadow:
              hasNewNotification
                  ? [
                    BoxShadow(
                      color: iconColor.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background Icon
            Positioned(
              right: -8,
              top: -8,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  icon,
                  size: effectiveIconSize * 2.5,
                  color: iconColor,
                ),
              ),
            ),
            // Badge de notificación en la esquina superior derecha de la card
            if ((notificationCount != null && notificationCount > 0) ||
                (hasNewNotification &&
                    (notificationCount == null || notificationCount == 0)))
              Positioned(
                top: -8,
                right: -8,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    // Si hay contador y es mayor que 0, mostrar badge numérico
                    // Si hay notificación nueva pero contador es 0 o null, mostrar punto pulsante
                    if (notificationCount != null && notificationCount > 0) {
                      final count = notificationCount;
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: count > 9 ? (count > 99 ? 6 : 7) : 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isDark
                                      ? const Color(0xFF2D211A)
                                      : Colors.white,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.7),
                                blurRadius: 8,
                                spreadRadius: 1.5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(
                            minWidth: count > 9 ? (count > 99 ? 26 : 24) : 22,
                            minHeight: 22,
                          ),
                          child: Center(
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: count > 99 ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                    return Transform.scale(scale: value, child: _PulsingDot());
                  },
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: effectiveIconSize * 2,
                      height: effectiveIconSize * 2,
                      decoration: BoxDecoration(
                        color:
                            hasNewNotification
                                ? iconColor.withOpacity(isDark ? 0.3 : 0.2)
                                : iconColor.withOpacity(isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: effectiveIconSize,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: effectivePadding * 0.8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: effectiveTitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: effectiveSubtitleFontSize,
                    color:
                        isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget que muestra un punto con animación de pulso
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(1 - _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 4 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
