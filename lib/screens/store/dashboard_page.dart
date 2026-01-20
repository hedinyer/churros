import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../models/pedido_fabrica.dart';
import '../../services/supabase_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/onboarding_overlay.dart';
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

  // GlobalKeys para el onboarding
  final GlobalKey _storeOpeningKey = GlobalKey();
  final GlobalKey _quickSaleKey = GlobalKey();
  final GlobalKey _inventoryKey = GlobalKey();
  final GlobalKey _closingKey = GlobalKey();

  // Monitoreo de cambios de estado de pedidos a fábrica
  Timer? _orderStatusTimer;
  Map<int, String> _previousOrderStates = {}; // pedidoId -> estado

  @override
  void initState() {
    super.initState();
    _loadVentasHoy();
    _checkAndShowOnboarding();
    _initializeOrderStatusMonitoring();
  }

  @override
  void dispose() {
    _orderStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndShowOnboarding() async {
    // Esperar a que el widget se construya completamente y los widgets estén renderizados
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) return;
    
    final isCompleted = await OnboardingOverlay.isCompleted();
    if (!isCompleted) {
      // Esperar un poco más para asegurar que los widgets están completamente renderizados
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _showOnboarding();
      }
    }
  }

  void _showOnboarding() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OnboardingOverlay(
        storeOpeningKey: _storeOpeningKey,
        quickSaleKey: _quickSaleKey,
        inventoryKey: _inventoryKey,
        closingKey: _closingKey,
      ),
    );
  }

  Future<void> _loadVentasHoy() async {
    setState(() {
      _isLoadingVentas = true;
    });

    try {
      final resumen = await SupabaseService.getResumenVentasHoy(
        widget.sucursal.id,
      );
      
      // Cargar gastos del día
      final gastos = await SupabaseService.getGastosPuntoVenta(
        sucursalId: widget.sucursal.id,
      );
      final totalGastos = gastos.fold<double>(
        0.0,
        (sum, gasto) => sum + ((gasto['monto'] as num?)?.toDouble() ?? 0.0),
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
    // Cargar estado inicial de los pedidos
    await _loadInitialOrderStates();
    
    // Configurar timer para verificar cambios cada 30 segundos
    _orderStatusTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkOrderStatusChanges(),
    );
  }

  /// Carga el estado inicial de los pedidos a fábrica de esta sucursal
  Future<void> _loadInitialOrderStates() async {
    try {
      final pedidos = await SupabaseService.getPedidosFabricaRecientes(
        widget.sucursal.id,
        limit: 50,
      );
      
      _previousOrderStates = {
        for (var pedido in pedidos)
          pedido.id: pedido.estado,
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

      for (final PedidoFabrica pedido in pedidos) {
        final pedidoId = pedido.id;
        final estadoActual = pedido.estado;
        final estadoAnterior = _previousOrderStates[pedidoId];

        // Si el pedido no estaba en el mapa anterior, agregarlo sin notificar
        if (estadoAnterior == null) {
          _previousOrderStates[pedidoId] = estadoActual;
          continue;
        }

        // Verificar cambio de Pendiente a Enviado
        if (estadoAnterior == 'pendiente' && estadoActual == 'enviado') {
          await NotificationService.showFactoryOrderSentNotification(
            numeroPedido: pedido.numeroPedido ?? pedido.id.toString(),
            sucursalNombre: 'Fábrica',
          );
          _previousOrderStates[pedidoId] = estadoActual;
        }
        // Verificar cambio de Enviado a Entregado
        else if (estadoAnterior == 'enviado' && estadoActual == 'entregado') {
          await NotificationService.showFactoryOrderDeliveredNotification(
            numeroPedido: pedido.numeroPedido ?? pedido.id.toString(),
            sucursalNombre: 'Fábrica',
          );
          _previousOrderStates[pedidoId] = estadoActual;
        }
        // Actualizar estado si cambió a otro estado
        else if (estadoAnterior != estadoActual) {
          _previousOrderStates[pedidoId] = estadoActual;
        }
      }

      // Limpiar pedidos que ya no existen (más de 50 días)
      final pedidosIds = pedidos.map((p) => p.id).toSet();
      _previousOrderStates.removeWhere((id, _) => !pedidosIds.contains(id));
    } catch (e) {
      print('Error verificando cambios de estado de pedidos: $e');
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
                    // Sucursal Name
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
                            colors: isDark
                                ? [
                                    const Color(0xFF2C2018),
                                    const Color(0xFF251C15),
                                  ]
                                : [
                                    Colors.white,
                                    const Color(0xFFFDFCFB),
                                  ],
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
                              color: isDark
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
                                        'Online',
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
                                      '${_porcentajeVsAyer >= 0 ? '+' : ''}${_porcentajeVsAyer.toStringAsFixed(0)}% vs ayer',
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
                                      'Gastos: \$${NumberFormat('#,###', 'es').format(_totalGastosHoy.round())}',
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
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => QuickSalePage(
                                        sucursal: widget.sucursal,
                                        currentUser: widget.currentUser,
                                      ),
                                ),
                              );
                            },
                            child: _buildModernCard(
                              key: _quickSaleKey,
                              isDark: isDark,
                              color: primaryColor,
                              icon: Icons.payments,
                              title: 'Venta Rápida',
                            ),
                          ),

                          // Apertura de Punto
                          _buildActionButton(
                            key: _storeOpeningKey,
                            context: context,
                            isDark: isDark,
                            icon: Icons.storefront,
                            iconColor: Colors.blue,
                            backgroundColor: Colors.blue,
                            backgroundIcon: Icons.storefront,
                            title: 'Apertura\nde Punto',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => StoreOpeningPage(
                                        currentUser:
                                            widget.currentUser.toJson(),
                                      ),
                                ),
                              );
                            },
                          ),

                          // Control de Inventario
                          _buildActionButton(
                            key: _inventoryKey,
                            context: context,
                            isDark: isDark,
                            icon: Icons.inventory_2,
                            iconColor: Colors.orange,
                            backgroundColor: Colors.orange,
                            backgroundIcon: Icons.inventory_2,
                            title: 'Control de\nInventario',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => InventoryControlPage(
                                        sucursal: widget.sucursal,
                                        currentUser: widget.currentUser,
                                      ),
                                ),
                              );
                            },
                          ),

                          // Cierre de Día
                          _buildActionButton(
                            key: _closingKey,
                            context: context,
                            isDark: isDark,
                            icon: Icons.lock_clock,
                            iconColor: Colors.grey,
                            backgroundColor: Colors.grey,
                            backgroundIcon: Icons.lock_clock,
                            title: 'Cierre\nde Día',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => DayClosingPage(
                                        sucursal: widget.sucursal,
                                        currentUser: widget.currentUser,
                                      ),
                                ),
                              );
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
                            title: 'Pedido a\nFábrica',
                            onTap: () {
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
                            title: 'Gastos',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => StoreExpensesPage(
                                        sucursal: widget.sucursal,
                                        currentUser: widget.currentUser,
                                      ),
                                ),
                              );
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
          colors: isDark
              ? [
                  color.withOpacity(0.12),
                  color.withOpacity(0.06),
                ]
              : [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
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
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withOpacity(0.95) : const Color(0xFF1B130D),
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
