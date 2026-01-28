import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../models/pedido_fabrica.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../../services/factory_session_service.dart';
import '../../main.dart';
import 'store_opening_page.dart';
import 'quick_sale_page.dart';
import 'inventory_control_page.dart';
import 'day_closing_page.dart';
import '../factory/factory_order_page.dart';
import 'store_expenses_page.dart';

class DashboardPage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const DashboardPage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _totalVentasHoy = 0.0;
  double _totalGastosHoy = 0.0;
  int _ticketsHoy = 0;
  double _porcentajeVsAyer = 0.0;
  bool _isLoadingVentas = true;

  // Monitoreo de cambios de estado de pedidos a fábrica
  Timer? _orderStatusTimer;
  Map<int, String> _previousOrderStates = {}; // pedidoId -> estado
  RealtimeChannel? _orderStatusChannel; // Listener de Realtime para cambios de estado

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
    // Inicializar notificaciones primero
    NotificationService.initialize().then((_) {
      print('✅ Servicio de notificaciones inicializado en Dashboard');
    });
    _loadVentasHoy();
    _initializeOrderStatusMonitoring();
    _setupNotificationNavigation();
  }

  @override
  void dispose() {
    _orderStatusTimer?.cancel();
    // Desconectar el listener de Realtime
    _orderStatusChannel?.unsubscribe();
    // Limpiar el callback de notificaciones
    NotificationService.onNotificationTapped = null;
    super.dispose();
  }

  /// Configura la navegación cuando se toca una notificación
  void _setupNotificationNavigation() {
    NotificationService.onNotificationTapped = (String? payload) {
      if (payload == 'factory_order_sent' ||
          payload == 'factory_order_delivered') {
        // Navegar a la página de Pedido a Fábrica
        // Usar Future.microtask para asegurar que se ejecute en el siguiente ciclo del event loop
        Future.microtask(() {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => FactoryOrderPage(
                      sucursal: widget.sucursal,
                      currentUser: widget.currentUser,
                    ),
              ),
            );
          }
        });
      }
    };
  }

  Future<void> _loadVentasHoy() async {
    setState(() {
      _isLoadingVentas = true;
    });

    try {
      final resumen = await SupabaseService.getResumenVentasHoy(
        widget.sucursal.id,
      );

      // Cargar gastos del día actual
      final gastos = await SupabaseService.getGastosPuntoVenta(
        sucursalId: widget.sucursal.id,
      );

      print('Dashboard - Gastos recibidos: ${gastos.length}');

      // Calcular el total de gastos del día
      double totalGastos = 0.0;
      for (final gasto in gastos) {
        final monto = gasto['monto'];
        print(
          'Dashboard - Procesando gasto: monto=$monto, tipo=${monto.runtimeType}',
        );

        double valor = 0.0;
        if (monto != null) {
          if (monto is num) {
            valor = monto.toDouble();
          } else if (monto is String) {
            // Remover cualquier formato de moneda o espacios
            final montoLimpio = monto.replaceAll(RegExp(r'[^\d.-]'), '');
            valor = double.tryParse(montoLimpio) ?? 0.0;
          } else {
            // Intentar convertir a string y luego a double
            try {
              valor = double.tryParse(monto.toString()) ?? 0.0;
            } catch (e) {
              print('Dashboard - Error convirtiendo monto: $e');
              valor = 0.0;
            }
          }
        }

        totalGastos += valor;
        print('Dashboard - Sumando: $valor, total acumulado: $totalGastos');
      }

      print(
        'Dashboard - Total gastos del día calculado: $totalGastos (${gastos.length} registros)',
      );

      setState(() {
        _totalVentasHoy = resumen['total'] as double;
        _totalGastosHoy = totalGastos;
        _ticketsHoy = resumen['tickets'] as int;
        _porcentajeVsAyer = resumen['porcentaje_vs_ayer'] as double;
        _isLoadingVentas = false;
      });
    } catch (e) {
      print('Error cargando ventas de hoy: $e');
      setState(() {
        _isLoadingVentas = false;
      });
    }
  }

  /// Inicializa el monitoreo de cambios de estado de pedidos a fábrica
  Future<void> _initializeOrderStatusMonitoring() async {
    // Asegurar que el servicio de notificaciones esté inicializado
    await NotificationService.initialize();
    
    // Cargar estado inicial de los pedidos
    await _loadInitialOrderStates();

    // Verificar cambios inmediatamente después de cargar estados iniciales
    await _checkOrderStatusChanges();

    // Configurar listener de Realtime para cambios instantáneos
    _setupRealtimeListener();

    // Configurar timer como respaldo para verificar cambios cada 15 segundos
    _orderStatusTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkOrderStatusChanges(),
    );
    
    print('✅ Monitoreo de pedidos inicializado - Realtime activo + verificación cada 15 segundos');
  }

  /// Configura el listener de Realtime para detectar cambios de estado al instante
  void _setupRealtimeListener() {
    try {
      print('🔌 Configurando listener de Realtime para pedidos_fabrica...');
      
      _orderStatusChannel = SupabaseService.client
          .channel('store_order_status_listener_${widget.sucursal.id}_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'pedidos_fabrica',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'sucursal_id',
              value: widget.sucursal.id,
            ),
            callback: (payload) async {
              print('📡 Cambio detectado en Realtime: ${payload.newRecord}');
              
              try {
                final pedidoId = payload.newRecord['id'] as int?;
                final estadoNuevo = (payload.newRecord['estado'] as String?)?.toLowerCase();
                final estadoAnterior = (payload.oldRecord['estado'] as String?)?.toLowerCase();
                final numeroPedido = payload.newRecord['numero_pedido'] as String?;

                if (pedidoId == null || estadoNuevo == null) {
                  print('⚠️ Datos incompletos en el cambio: pedidoId=$pedidoId, estado=$estadoNuevo');
                  return;
                }

                print('🔍 Analizando cambio: Pedido #$pedidoId de "$estadoAnterior" a "$estadoNuevo"');

                // Verificar cambio de Pendiente a Enviado
                if (estadoAnterior == 'pendiente' && estadoNuevo == 'enviado') {
                  print('🚀 Cambio detectado: PENDIENTE → ENVIADO para pedido #$pedidoId');
                  
                  // Asegurar que las notificaciones estén inicializadas
                  await NotificationService.initialize();
                  
                  // Mostrar notificación inmediatamente
                  await NotificationService.showFactoryOrderSentNotification(
                    numeroPedido: numeroPedido ?? pedidoId.toString(),
                    sucursalNombre: 'Fábrica',
                  );
                  
                  // Actualizar estado en el mapa
                  _previousOrderStates[pedidoId] = estadoNuevo;
                  
                  print('✅ Notificación de ENVIADO mostrada para pedido #$pedidoId');
                }
                // Verificar cambio de Enviado a Entregado
                else if (estadoAnterior == 'enviado' && estadoNuevo == 'entregado') {
                  print('📦 Cambio detectado: ENVIADO → ENTREGADO para pedido #$pedidoId');
                  
                  // Asegurar que las notificaciones estén inicializadas
                  await NotificationService.initialize();
                  
                  // Mostrar notificación inmediatamente
                  await NotificationService.showFactoryOrderDeliveredNotification(
                    numeroPedido: numeroPedido ?? pedidoId.toString(),
                    sucursalNombre: 'Fábrica',
                  );
                  
                  // Actualizar estado en el mapa
                  _previousOrderStates[pedidoId] = estadoNuevo;
                  
                  print('✅ Notificación de ENTREGADO mostrada para pedido #$pedidoId');
                }
                // Actualizar estado si cambió a otro estado
                else if (estadoAnterior != estadoNuevo) {
                  print('📝 Estado actualizado: Pedido #$pedidoId de "$estadoAnterior" a "$estadoNuevo"');
                  _previousOrderStates[pedidoId] = estadoNuevo;
                }
              } catch (e) {
                print('❌ Error procesando cambio de Realtime: $e');
                print('Stack trace: ${StackTrace.current}');
              }
            },
          )
          .subscribe();

      print('✅ Listener de Realtime configurado y suscrito exitosamente');
    } catch (e) {
      print('❌ Error configurando listener de Realtime: $e');
      print('Stack trace: ${StackTrace.current}');
      // Continuar con el timer como respaldo
    }
  }

  /// Carga el estado inicial de los pedidos a fábrica de esta sucursal
  Future<void> _loadInitialOrderStates() async {
    try {
      final pedidos = await SupabaseService.getPedidosFabricaRecientes(
        widget.sucursal.id,
        limit: 50,
      );

      _previousOrderStates = {
        for (var pedido in pedidos) pedido.id: pedido.estado,
      };
    } catch (e) {
      print('Error cargando estado inicial de pedidos: $e');
    }
  }

  /// Verifica cambios de estado en los pedidos a fábrica
  Future<void> _checkOrderStatusChanges() async {
    if (!mounted) return;

    try {
      final pedidos = await SupabaseService.getPedidosFabricaRecientes(
        widget.sucursal.id,
        limit: 50,
      );

      bool cambioDetectado = false;

      for (final PedidoFabrica pedido in pedidos) {
        final pedidoId = pedido.id;
        final estadoActual = pedido.estado.toLowerCase(); // Normalizar a minúsculas
        final estadoAnterior = _previousOrderStates[pedidoId]?.toLowerCase();

        // Si el pedido no estaba en el mapa anterior, agregarlo sin notificar
        if (estadoAnterior == null) {
          _previousOrderStates[pedidoId] = pedido.estado;
          continue;
        }

        // Verificar cambio de Pendiente a Enviado
        if (estadoAnterior == 'pendiente' && estadoActual == 'enviado') {
          print('🔔 Cambio detectado: Pedido #$pedidoId de PENDIENTE a ENVIADO');
          cambioDetectado = true;
          
          // Asegurar que las notificaciones estén inicializadas
          await NotificationService.initialize();
          
          await NotificationService.showFactoryOrderSentNotification(
            numeroPedido: pedido.numeroPedido ?? pedido.id.toString(),
            sucursalNombre: 'Fábrica',
          );
          
          print('✅ Notificación de ENVIADO mostrada para pedido #$pedidoId');
          _previousOrderStates[pedidoId] = pedido.estado;
        }
        // Verificar cambio de Enviado a Entregado
        else if (estadoAnterior == 'enviado' && estadoActual == 'entregado') {
          print('🔔 Cambio detectado: Pedido #$pedidoId de ENVIADO a ENTREGADO');
          cambioDetectado = true;
          
          // Asegurar que las notificaciones estén inicializadas
          await NotificationService.initialize();
          
          await NotificationService.showFactoryOrderDeliveredNotification(
            numeroPedido: pedido.numeroPedido ?? pedido.id.toString(),
            sucursalNombre: 'Fábrica',
          );
          
          print('✅ Notificación de ENTREGADO mostrada para pedido #$pedidoId');
          _previousOrderStates[pedidoId] = pedido.estado;
        }
        // Actualizar estado si cambió a otro estado
        else if (estadoAnterior != estadoActual) {
          print('📝 Estado actualizado: Pedido #$pedidoId de $estadoAnterior a $estadoActual');
          _previousOrderStates[pedidoId] = pedido.estado;
        }
      }

      // Limpiar pedidos que ya no existen (más de 50 días)
      final pedidosIds = pedidos.map((p) => p.id).toSet();
      final pedidosEliminados = _previousOrderStates.keys
          .where((id) => !pedidosIds.contains(id))
          .length;
      if (pedidosEliminados > 0) {
        _previousOrderStates.removeWhere((id, _) => !pedidosIds.contains(id));
        print('🧹 Limpiados $pedidosEliminados pedidos antiguos del mapa de estados');
      }

      if (!cambioDetectado) {
        print('👀 Monitoreo activo - Sin cambios detectados (${pedidos.length} pedidos monitoreados)');
      }
    } catch (e) {
      print('❌ Error verificando cambios de estado de pedidos: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 600;

    // Deshabilitar escalado de texto del sistema
    final mediaQueryWithoutTextScale = mediaQuery.copyWith(
      textScaler: TextScaler.linear(1.0),
    );

    return MediaQuery(
      data: mediaQueryWithoutTextScale,
      child: WillPopScope(
        onWillPop: () async => false, // Deshabilitar botón físico de atrás
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
          body: SafeArea(
            child: Column(
              children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: (isDark
                          ? const Color(0xFF221810)
                          : const Color(0xFFF8F7F6))
                      .withOpacity(0.95),
                ),
                child: Row(
                  children: [
                    // Nombre de sucursal centrado
                    Expanded(
                      child: Text(
                        widget.sucursal.nombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _logout,
                      icon: Icon(
                        Icons.logout,
                        color:
                            isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      tooltip: 'Cerrar sesión',
                    ),
                  ],
                ),
              ),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Sales Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                                isDark
                                    ? [
                                      const Color(0xFF2C2018),
                                      const Color(0xFF251C15),
                                    ]
                                    : [Colors.white, const Color(0xFFFDFCFB)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isDark
                                    ? const Color(0xFF44403C).withOpacity(0.4)
                                    : const Color(0xFFE7E5E4).withOpacity(0.5),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  isDark
                                      ? Colors.black.withOpacity(0.3)
                                      : Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'VENTAS DE HOY',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? const Color(0xFFA8A29E)
                                                  : const Color(0xFF78716C),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AnimatedOpacity(
                                        opacity: _isLoadingVentas ? 0.3 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                        child: Text(
                                          _isLoadingVentas
                                              ? '\$0'
                                              : '\$${NumberFormat('#,###', 'es').format(_totalVentasHoy.round())}',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Online Status
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(isDark ? 0.2 : 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withOpacity(isDark ? 0.3 : 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ONLINE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _porcentajeVsAyer >= 0
                                          ? Icons.trending_up
                                          : Icons.trending_down,
                                      size: 18,
                                      color:
                                          _porcentajeVsAyer >= 0
                                              ? const Color(0xFF10B981)
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_porcentajeVsAyer >= 0 ? '+' : ''}${_porcentajeVsAyer.toStringAsFixed(0)}% VS AYER',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            _porcentajeVsAyer >= 0
                                                ? const Color(0xFF10B981)
                                                : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'GASTOS: \$${NumberFormat('#,###', 'es').format(_totalGastosHoy.round())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                        // Action Buttons Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.1,
                          children: [
                            // Venta Rápida
                            GestureDetector(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => QuickSalePage(
                                          sucursal: widget.sucursal,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                                if (mounted) {
                                  _loadVentasHoy();
                                }
                              },
                              child: _buildModernCard(
                                key: null,
                                isDark: isDark,
                                color: primaryColor,
                                icon: Icons.payments,
                                title: 'VENTA RÁPIDA',
                              ),
                            ),

                            // Apertura de Punto
                            _buildActionButton(
                              key: null,
                              context: context,
                              isDark: isDark,
                              icon: Icons.storefront,
                              iconColor: Colors.blue,
                              backgroundColor: Colors.blue,
                              backgroundIcon: Icons.storefront,
                              title: 'APERTURA\nDE PUNTO',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => StoreOpeningPage(
                                          currentUser:
                                              widget.currentUser.toJson(),
                                        ),
                                  ),
                                );
                                if (mounted) {
                                  _loadVentasHoy();
                                }
                              },
                            ),

                            // Control de Inventario
                            _buildActionButton(
                              key: null,
                              context: context,
                              isDark: isDark,
                              icon: Icons.inventory_2,
                              iconColor: Colors.orange,
                              backgroundColor: Colors.orange,
                              backgroundIcon: Icons.inventory_2,
                              title: 'CONTROL DE\nINVENTARIO',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => InventoryControlPage(
                                          sucursal: widget.sucursal,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                                if (mounted) {
                                  _loadVentasHoy();
                                }
                              },
                            ),

                            // Cierre de Día
                            _buildActionButton(
                              key: null,
                              context: context,
                              isDark: isDark,
                              icon: Icons.lock_clock,
                              iconColor: Colors.grey,
                              backgroundColor: Colors.grey,
                              backgroundIcon: Icons.lock_clock,
                              title: 'CIERRE\nDE DÍA',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => DayClosingPage(
                                          sucursal: widget.sucursal,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                                if (mounted) {
                                  _loadVentasHoy();
                                }
                              },
                            ),

                            // Pedido a Fábrica
                            _buildActionButton(
                              key: null,
                              context: context,
                              isDark: isDark,
                              icon: Icons.factory,
                              iconColor: Colors.purple,
                              backgroundColor: Colors.purple,
                              backgroundIcon: Icons.factory,
                              title: 'PEDIDO A\nFÁBRICA',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => FactoryOrderPage(
                                          sucursal: widget.sucursal,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                                if (mounted) {
                                  _loadVentasHoy();
                                }
                              },
                            ),

                            // Gastos
                            _buildActionButton(
                              key: null,
                              context: context,
                              isDark: isDark,
                              icon: Icons.receipt_long,
                              iconColor: Colors.red,
                              backgroundColor: Colors.red,
                              backgroundIcon: Icons.receipt_long,
                              title: 'GASTOS',
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => StoreExpensesPage(
                                          sucursal: widget.sucursal,
                                          currentUser: widget.currentUser,
                                        ),
                                  ),
                                );
                                // Recargar datos cuando se regrese de la página de gastos
                                if (mounted) {
                                  _loadVentasHoy();
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernCard({
    Key? key,
    required bool isDark,
    required Color color,
    required IconData icon,
    required String title,
  }) {
    return Container(
      key: key,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? [color.withOpacity(0.12), color.withOpacity(0.06)]
                  : [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isDark ? 0.1 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark
                        ? Colors.white.withOpacity(0.95)
                        : const Color(0xFF1B130D),
                height: 1.3,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required IconData backgroundIcon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildModernCard(
        key: key,
        isDark: isDark,
        color: backgroundColor,
        icon: icon,
        title: title,
      ),
    );
  }
}
