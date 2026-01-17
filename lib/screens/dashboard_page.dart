import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sucursal.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import '../widgets/onboarding_overlay.dart';
import 'store_opening_page.dart';
import 'quick_sale_page.dart';
import 'inventory_control_page.dart';
import 'day_closing_page.dart';
import 'factory_order_page.dart';
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
  int _ticketsHoy = 0;
  double _porcentajeVsAyer = 0.0;
  bool _isLoadingVentas = true;

  // GlobalKeys para el onboarding
  final GlobalKey _storeOpeningKey = GlobalKey();
  final GlobalKey _quickSaleKey = GlobalKey();
  final GlobalKey _inventoryKey = GlobalKey();
  final GlobalKey _closingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadVentasHoy();
    _checkAndShowOnboarding();
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
      setState(() {
        _totalVentasHoy = resumen['total'] as double;
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
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2C2018) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                isDark
                                    ? const Color(0xFF44403C)
                                    : const Color(0xFFE7E5E4),
                          ),
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
                            Row(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long,
                                      size: 18,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_ticketsHoy Tickets',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            isDark
                                                ? const Color(0xFFA8A29E)
                                                : const Color(0xFF78716C),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Row(
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
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                        children: [
                          // Venta Rápida (Large Button)
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
                            child: Container(
                              key: _quickSaleKey,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.25),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  // Background Icon
                                  Positioned(
                                    right: -24,
                                    bottom: -32,
                                    child: Opacity(
                                      opacity: 0.2,
                                      child: Icon(
                                        Icons.point_of_sale,
                                        size: 160,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  // Content
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.payments,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Venta Rápida',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Nuevo pedido al mostrador',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.8,
                                                ),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
      child: Container(
        key: key,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Icon
            Positioned(
              right: -24,
              bottom: -32,
              child: Opacity(
                opacity: 0.2,
                child: Icon(backgroundIcon, size: 160, color: Colors.white),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 28),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
