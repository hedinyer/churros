import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import 'factory_orders_list_page.dart';
import '../store/client_orders_list_page.dart';
import '../store/dispatch_page.dart';
import '../store/manual_order_page.dart';
import 'factory_statistics_page.dart';
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

class _FactoryDashboardPageState extends State<FactoryDashboardPage> with WidgetsBindingObserver {
  bool _isLoading = true;
  int _newFactoryOrdersCount = 0;
  int _newClientOrdersCount = 0;
  int _newDeliveredOrdersCount = 0;
  
  // Realtime subscriptions
  RealtimeChannel? _factoryOrdersChannel;
  RealtimeChannel? _clientOrdersChannel;
  RealtimeChannel? _deliveredOrdersChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _factoryOrdersChannel?.unsubscribe();
    _clientOrdersChannel?.unsubscribe();
    _deliveredOrdersChannel?.unsubscribe();
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
      setState(() {
        _isLoading = false;
        // Resetear contadores cuando se recarga manualmente
        _newFactoryOrdersCount = 0;
        _newClientOrdersCount = 0;
        _newDeliveredOrdersCount = 0;
      });
    } catch (e) {
      print('Error cargando datos de fábrica: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Configura los listeners de Supabase Realtime
  void _setupRealtimeListeners() {
    try {
      // Listener para pedidos de fábrica (pedidos_fabrica)
      _factoryOrdersChannel = SupabaseService.client
          .channel('factory_orders_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'pedidos_fabrica',
            callback: (payload) {
              print('Nuevo pedido de fábrica recibido: ${payload.newRecord}');
              _handleNewFactoryOrder(payload.newRecord);
            },
          )
          .subscribe();

      // Listener para pedidos de clientes (pedidos_clientes)
      _clientOrdersChannel = SupabaseService.client
          .channel('client_orders_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'pedidos_clientes',
            callback: (payload) {
              print('Nuevo pedido de cliente recibido: ${payload.newRecord}');
              _handleNewClientOrder(payload.newRecord);
            },
          )
          .subscribe();

      // Listener para pedidos entregados (cambios de estado a "entregado")
      // Escuchamos todos los updates y filtramos en el callback
      _deliveredOrdersChannel = SupabaseService.client
          .channel('delivered_orders_channel')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'pedidos_fabrica',
            callback: (payload) {
              final newRecord = payload.newRecord;
              final oldRecord = payload.oldRecord;
              
              // Verificar que el estado cambió a "entregado"
              final estadoAnterior = oldRecord['estado'] as String?;
              final estadoNuevo = newRecord['estado'] as String?;
              
              if (estadoNuevo == 'entregado' && estadoAnterior != 'entregado') {
                print('Pedido de fábrica entregado: $newRecord');
                _handleDeliveredOrder(newRecord, 'fabrica');
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
              
              // Verificar que el estado cambió a "entregado"
              final estadoAnterior = oldRecord['estado'] as String?;
              final estadoNuevo = newRecord['estado'] as String?;
              
              if (estadoNuevo == 'entregado' && estadoAnterior != 'entregado') {
                print('Pedido de cliente entregado: $newRecord');
                _handleDeliveredOrder(newRecord, 'cliente');
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
      });

      // Obtener información de la sucursal si está disponible
      final sucursalNombre = newOrder['sucursal_nombre'] ?? 'Punto de Venta';
      
      // Contar productos si está disponible
      final productos = newOrder['productos'];
      int? cantidadProductos;
      if (productos != null && productos is List) {
        cantidadProductos = productos.length;
      }

      // Mostrar notificación push
      NotificationService.showNewFactoryOrderNotification(
        sucursal: sucursalNombre,
        cantidadProductos: cantidadProductos,
      );

      // Actualizar resumen
      _loadData();
    }
  }

  /// Maneja cuando llega un nuevo pedido de cliente
  void _handleNewClientOrder(Map<String, dynamic> newOrder) {
    if (mounted) {
      setState(() {
        _newClientOrdersCount++;
      });

      // Obtener información del cliente
      final clienteNombre = newOrder['cliente_nombre'] ?? 
                           newOrder['nombre_cliente'] ?? 
                           'Cliente';
      
      // Contar productos si está disponible
      final productos = newOrder['productos'];
      int? cantidadProductos;
      if (productos != null && productos is List) {
        cantidadProductos = productos.length;
      }

      // Mostrar notificación push
      NotificationService.showNewClientOrderNotification(
        cliente: clienteNombre,
        cantidadProductos: cantidadProductos,
      );

      // Actualizar resumen
      _loadData();
    }
  }

  /// Maneja cuando un pedido es entregado
  void _handleDeliveredOrder(Map<String, dynamic> orderData, String tipo) {
    if (mounted) {
      // Verificar que el estado actual es "entregado"
      final estadoActual = orderData['estado'] as String?;
      if (estadoActual != 'entregado') {
        return; // No es una entrega, ignorar
      }

      setState(() {
        _newDeliveredOrdersCount++;
      });

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

      // Mostrar notificación push
      NotificationService.showDeliveredOrderNotification(
        tipoPedido: tipo,
        sucursalNombre: sucursalNombre,
        clienteNombre: clienteNombre,
        numeroPedido: numeroPedido,
      );

      // Actualizar resumen
      _loadData();
    }
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
    final headerFontSize = isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final sectionTitleFontSize = isVerySmallScreen ? 16.0 : (isSmallScreen ? 18.0 : 20.0);
    final buttonTitleFontSize = isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 16.0);
    final buttonSubtitleFontSize = isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0);
    final bottomButtonFontSize = isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 18.0);
    final iconSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 22.0 : 24.0);
    final buttonPadding = isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0);
    final gridSpacing = isVerySmallScreen ? 12.0 : (isSmallScreen ? 14.0 : 16.0);

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
              child: Center(
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
                                  notificationCount: _newFactoryOrdersCount > 0 ? _newFactoryOrdersCount : null,
                                  onTap: () async {
                                    // Resetear contador al entrar
                                    setState(() {
                                      _newFactoryOrdersCount = 0;
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
                                  notificationCount: _newClientOrdersCount > 0 ? _newClientOrdersCount : null,
                                  onTap: () async {
                                    // Resetear contador al entrar
                                    setState(() {
                                      _newClientOrdersCount = 0;
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
                                            (context) => const RecurrentOrdersPage(),
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
                                            (context) => const FactoryInventoryProductionPage(),
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
                                  notificationCount: _newDeliveredOrdersCount > 0 ? _newDeliveredOrdersCount : null,
                                  onTap: () {
                                    // Resetear contador al entrar
                                    setState(() {
                                      _newDeliveredOrdersCount = 0;
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
                                            (context) => const ProductsManagementPage(),
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
                                            (context) => const EmployeesManagementPage(),
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

                            // Estadísticas Button (Full Width)
                            SizedBox(height: isVerySmallScreen ? 12 : 16),
                            _buildStatsButton(
                              isDark: isDark,
                              titleFontSize: buttonTitleFontSize,
                              subtitleFontSize: buttonSubtitleFontSize,
                              iconSize: iconSize,
                              padding: buttonPadding,
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
                Icon(Icons.add_circle, size: isVerySmallScreen ? 20 : (isSmallScreen ? 22 : 24)),
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
      child: Container(
        padding: EdgeInsets.all(effectivePadding),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D211A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Stack(
          children: [
            // Background Icon
            Positioned(
              right: -8,
              top: -8,
              child: Opacity(
                opacity: 0.1,
                child: Icon(icon, size: effectiveIconSize * 2.5, color: iconColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: effectiveIconSize * 2,
                      height: effectiveIconSize * 2,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: effectiveIconSize),
                    ),
                    if (notificationCount != null && notificationCount > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: notificationCount > 9 ? 4 : 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              notificationCount > 99 ? '99+' : notificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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

  Widget _buildStatsButton({
    required bool isDark,
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
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FactoryStatisticsPage(),
          ),
        );
        // Actualizar resumen al volver
        _loadData();
      },
      child: Container(
        padding: EdgeInsets.all(effectivePadding),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D211A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: effectiveIconSize * 2,
              height: effectiveIconSize * 2,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics, color: Colors.purple, size: effectiveIconSize),
            ),
            SizedBox(width: effectivePadding * 0.8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTADÍSTICAS DE FÁBRICA',
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
                    'REPORTES Y MÉTRICAS',
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
            ),
            Icon(
              Icons.chevron_right,
              size: effectiveIconSize,
              color:
                  isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
