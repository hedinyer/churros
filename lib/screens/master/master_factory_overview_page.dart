import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/pedido_cliente.dart';
import '../../services/data_cache_service.dart';
import '../../services/supabase_service.dart';
import '../factory/factory_inventory_production_page.dart';
import '../factory/factory_orders_list_page.dart';
import '../store/client_orders_list_page.dart';
import '../store/dispatch_page.dart';
import '../store/expenses_page.dart';
import 'master_historical_expenses_page.dart';

class MasterFactoryOverviewPage extends StatefulWidget {
  const MasterFactoryOverviewPage({super.key});

  @override
  State<MasterFactoryOverviewPage> createState() =>
      _MasterFactoryOverviewPageState();
}

class _MasterFactoryOverviewPageState extends State<MasterFactoryOverviewPage> {
  bool _isLoading = true;

  // Datos reutilizados de ExpensesPage para el resumen financiero
  List<PedidoCliente> _pedidosClientes = [];
  List<PedidoCliente> _pedidosRecurrentes = [];
  List<Map<String, dynamic>> _gastosVarios = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productosMap = await DataCacheService.getProductosMap();

      final results = await Future.wait([
        SupabaseService.getPedidosClientesPagadosFast(
          limit: 1000,
          productosMap: productosMap,
        ),
        SupabaseService.getPedidosRecurrentesPagadosFast(
          limit: 1000,
          productosMap: productosMap,
        ),
        SupabaseService.getGastosVarios(),
      ]);

      setState(() {
        _pedidosClientes = results[0] as List<PedidoCliente>;
        _pedidosRecurrentes = results[1] as List<PedidoCliente>;
        _gastosVarios = results[2] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de resumen fábrica: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
  }

  double _getTotalPagos() {
    final totalClientes = _pedidosClientes.fold(0.0, (sum, pedido) {
      return sum + pedido.total;
    });

    final totalRecurrentes = _pedidosRecurrentes.fold(0.0, (sum, pedido) {
      return sum + pedido.total;
    });

    return totalClientes + totalRecurrentes;
  }

  double _getTotalGastosVarios() {
    return _gastosVarios.fold(0.0, (sum, gasto) {
      final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
      return sum + monto;
    });
  }

  double _getTotalDomicilios() {
    final totalClientes = _pedidosClientes.fold(0.0, (sum, pedido) {
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + domicilio;
    });

    final totalRecurrentes = _pedidosRecurrentes.fold(0.0, (sum, pedido) {
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + domicilio;
    });

    return totalClientes + totalRecurrentes;
  }

  double _getTotalEfectivo() {
    double total = 0.0;

    for (final pedido in _pedidosClientes) {
      final metodoPago = pedido.metodoPago?.toUpperCase() ?? '';
      if (metodoPago == 'EFECTIVO') {
        total += pedido.total;
      } else if (metodoPago == 'MIXTO') {
        total += pedido.parteEfectivo ?? 0.0;
      }
    }

    for (final pedido in _pedidosRecurrentes) {
      final metodoPago = pedido.metodoPago?.toUpperCase() ?? '';
      if (metodoPago == 'EFECTIVO') {
        total += pedido.total;
      } else if (metodoPago == 'MIXTO') {
        total += pedido.parteEfectivo ?? 0.0;
      }
    }

    return total;
  }

  double _getTotalTransferencia() {
    double total = 0.0;

    for (final pedido in _pedidosClientes) {
      final metodoPago = pedido.metodoPago?.toUpperCase() ?? '';
      if (metodoPago == 'TRANSFERENCIA') {
        total += pedido.total;
      } else if (metodoPago == 'MIXTO') {
        total += pedido.parteTransferencia ?? 0.0;
      }
    }

    for (final pedido in _pedidosRecurrentes) {
      final metodoPago = pedido.metodoPago?.toUpperCase() ?? '';
      if (metodoPago == 'TRANSFERENCIA') {
        total += pedido.total;
      } else if (metodoPago == 'MIXTO') {
        total += pedido.parteTransferencia ?? 0.0;
      }
    }

    return total;
  }

  double _getTotalGeneral() {
    return _getTotalPagos() + _getTotalDomicilios() - _getTotalGastosVarios();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    final totalPagos = _getTotalPagos();
    final totalDomicilios = _getTotalDomicilios();
    final totalGastosVarios = _getTotalGastosVarios();
    final totalGeneral = _getTotalGeneral();
    final totalEfectivo = _getTotalEfectivo();
    final totalTransferencia = _getTotalTransferencia();

    return Scaffold(
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
                    .withOpacity(0.98),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fábrica',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color:
                                isDark ? Colors.white : const Color(0xFF1B130D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ventas y gastos del día',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? const Color(0xFF9C9591)
                                : const Color(0xFF8A8380),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: 16,
                        ),
                        children: [
                          _buildFinanceSummaryCard(
                            isDark: isDark,
                            primaryColor: primaryColor,
                            totalPagos: totalPagos,
                            totalDomicilios: totalDomicilios,
                            totalGastosVarios: totalGastosVarios,
                            totalGeneral: totalGeneral,
                            totalEfectivo: totalEfectivo,
                            totalTransferencia: totalTransferencia,
                          ),
                          const SizedBox(height: 24),
                          _buildShortcutsSection(
                            isDark: isDark,
                            primaryColor: primaryColor,
                            isSmallScreen: isSmallScreen,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummaryCard({
    required bool isDark,
    required Color primaryColor,
    required double totalPagos,
    required double totalDomicilios,
    required double totalGastosVarios,
    required double totalGeneral,
    required double totalEfectivo,
    required double totalTransferencia,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withOpacity(0.9),
            const Color(0xFFD45A0A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RESUMEN HOY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(totalPagos),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ventas registradas (pagos entregados)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildSummaryMetric(
                      icon: Icons.money_rounded,
                      label: 'Efectivo',
                      value: _formatCurrency(totalEfectivo),
                    ),
                    _buildSummaryDivider(),
                    _buildSummaryMetric(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transf.',
                      value: _formatCurrency(totalTransferencia),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildSummaryMetric(
                      icon: Icons.delivery_dining,
                      label: 'Domicilios',
                      value: _formatCurrency(totalDomicilios),
                    ),
                    _buildSummaryDivider(),
                    _buildSummaryMetric(
                      icon: Icons.trending_down_rounded,
                      label: 'Gastos varios',
                      value: _formatCurrency(totalGastosVarios),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL (Pago + domi - gasto)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  _formatCurrency(totalGeneral),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.18),
    );
  }

  Widget _buildShortcutsSection({
    required bool isDark,
    required Color primaryColor,
    required bool isSmallScreen,
  }) {
    final gridSpacing = isSmallScreen ? 12.0 : 14.0;
    final iconSize = isSmallScreen ? 22.0 : 24.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final subtitleFontSize = isSmallScreen ? 11.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCESOS FÁBRICA',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1B130D),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
          childAspectRatio: isSmallScreen ? 1.05 : 1.1,
          children: [
            _buildShortcutCard(
              isDark: isDark,
              icon: Icons.receipt_long,
              iconColor: Colors.red,
              title: 'GASTOS',
              subtitle: 'Pagos y compras',
              iconSize: iconSize,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExpensesPage(),
                  ),
                );
              },
            ),
            _buildShortcutCard(
              isDark: isDark,
              icon: Icons.storefront,
              iconColor: Colors.blue,
              title: 'PEDIDOS PUNTOS',
              subtitle: 'Puntos de venta',
              iconSize: iconSize,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FactoryOrdersListPage(),
                  ),
                );
              },
            ),
            _buildShortcutCard(
              isDark: isDark,
              icon: Icons.chat,
              iconColor: Colors.green,
              title: 'PEDIDOS CLIENTES',
              subtitle: 'WhatsApp',
              iconSize: iconSize,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientOrdersListPage(),
                  ),
                );
              },
            ),
            _buildShortcutCard(
              isDark: isDark,
              icon: Icons.local_shipping,
              iconColor: Colors.grey,
              title: 'DESPACHO',
              subtitle: 'Estados pedidos',
              iconSize: iconSize,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DispatchPage(),
                  ),
                );
              },
            ),
            _buildShortcutCard(
              isDark: isDark,
              icon: Icons.inventory_2,
              iconColor: Colors.orange,
              title: 'INVENTARIO',
              subtitle: 'Fábrica',
              iconSize: iconSize,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const FactoryInventoryProductionPage(),
                  ),
                );
              },
            ),
            _buildShortcutCard(
              isDark: isDark,
              icon: Icons.calendar_today,
              iconColor: primaryColor,
              title: 'HISTÓRICO',
              subtitle: 'Gastos por fecha',
              iconSize: iconSize,
              titleFontSize: titleFontSize,
              subtitleFontSize: subtitleFontSize,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const MasterHistoricalExpensesPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShortcutCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double iconSize,
    required double titleFontSize,
    required double subtitleFontSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D211A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconSize * 1.8,
              height: iconSize * 1.8,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: subtitleFontSize,
                color:
                    isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

