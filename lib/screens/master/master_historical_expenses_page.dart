import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/pedido_cliente.dart';
import '../../services/data_cache_service.dart';
import '../../services/supabase_service.dart';

class MasterHistoricalExpensesPage extends StatefulWidget {
  const MasterHistoricalExpensesPage({super.key});

  @override
  State<MasterHistoricalExpensesPage> createState() =>
      _MasterHistoricalExpensesPageState();
}

class _MasterHistoricalExpensesPageState
    extends State<MasterHistoricalExpensesPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  List<PedidoCliente> _pedidosClientes = [];
  List<PedidoCliente> _pedidosRecurrentes = [];
  List<PedidoCliente> _pedidosClientesPendientes = [];
  List<PedidoCliente> _pedidosRecurrentesPendientes = [];
  List<Map<String, dynamic>> _gastosVarios = [];
  int _selectedTab = 0; // 0 = Pagos Entregados, 1 = Pagos Pendientes, 2 = Gastos Varios

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFEC6D13),
              onPrimary: Colors.white,
              surface: isDark ? const Color(0xFF1C1917) : Colors.white,
              onSurface: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productosMap = await DataCacheService.getProductosMap();
      final fechaStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final results = await Future.wait([
        SupabaseService.getPedidosClientesPagadosPorFechaFast(
          fecha: fechaStr,
          limit: 1000,
          productosMap: productosMap,
        ),
        SupabaseService.getPedidosRecurrentesPagadosPorFechaFast(
          fecha: fechaStr,
          limit: 1000,
          productosMap: productosMap,
        ),
        // Pendientes: mismo criterio que en ExpensesPage (no se filtra por fecha)
        SupabaseService.getPedidosClientesPendientesFast(
          limit: 1000,
          productosMap: productosMap,
        ),
        SupabaseService.getPedidosRecurrentesPendientesFast(
          limit: 1000,
          productosMap: productosMap,
        ),
        SupabaseService.getGastosVariosPorFecha(fechaStr),
      ]);

      setState(() {
        _pedidosClientes = results[0] as List<PedidoCliente>;
        _pedidosRecurrentes = results[1] as List<PedidoCliente>;
        _pedidosClientesPendientes = results[2] as List<PedidoCliente>;
        _pedidosRecurrentesPendientes = results[3] as List<PedidoCliente>;
        _gastosVarios = results[4] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos históricos de gastos: $e');
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

  double _getTotalPagosPendientes() {
    final totalClientes = _pedidosClientesPendientes.fold(0.0, (sum, pedido) {
      final totalPedido = pedido.total;
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + totalPedido + domicilio;
    });

    final totalRecurrentes = _pedidosRecurrentesPendientes.fold(0.0,
        (sum, pedido) {
      final totalPedido = pedido.total;
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + totalPedido + domicilio;
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

  double _getTotalGeneral() {
    return _getTotalPagos() + _getTotalDomicilios() - _getTotalGastosVarios();
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

    final dateStr = DateFormat('EEEE d \'de\' MMMM, yyyy', 'es')
        .format(_selectedDate);

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
                          'Histórico de Gastos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color:
                                isDark ? Colors.white : const Color(0xFF1B130D),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Selecciona un día para ver ventas, pagos y gastos',
                          style: TextStyle(
                            fontSize: 12,
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

            // Date selector
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
                vertical: 12,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D211A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                primaryColor.withOpacity(isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha seleccionada',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFF9C9591)
                                      : const Color(0xFF8A8380),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1B130D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: isDark
                              ? const Color(0xFF9C9591)
                              : const Color(0xFF8A8380),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Summary card
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
              ),
              child: _buildSummaryCard(
                isDark: isDark,
                primaryColor: primaryColor,
                totalPagos: totalPagos,
                totalDomicilios: totalDomicilios,
                totalGastosVarios: totalGastosVarios,
                totalGeneral: totalGeneral,
                totalEfectivo: totalEfectivo,
                totalTransferencia: totalTransferencia,
              ),
            ),

            // Tabs
            Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D211A) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Pagos\nEntregados',
                      isSelected: _selectedTab == 0,
                      total: _getTotalPagos(),
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Pagos\nPendientes',
                      isSelected: _selectedTab == 1,
                      total: _getTotalPagosPendientes(),
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Gastos\nVarios',
                      isSelected: _selectedTab == 2,
                      total: _getTotalGastosVarios(),
                      onTap: () => setState(() => _selectedTab = 2),
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
                      child: _selectedTab == 0
                          ? _buildPagosPedidosList(
                              isDark: isDark,
                              primaryColor: primaryColor,
                            )
                          : _selectedTab == 1
                              ? _buildPagosPendientesList(
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                )
                              : _buildGastosVariosList(
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
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
      padding: const EdgeInsets.all(16),
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAGOS ENTREGADOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCurrency(totalPagos),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.8,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total día',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 2),
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
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildSummaryMetric(
                      icon: Icons.payments_rounded,
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
                const SizedBox(height: 8),
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
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
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
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _buildTabButton({
    required bool isDark,
    required String label,
    required bool isSelected,
    required double total,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFEC6D13) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1B130D))
                    : (isDark
                        ? const Color(0xFF9A6C4C)
                        : const Color(0xFF9A6C4C)),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Text(
              _formatCurrency(total),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFFEC6D13)
                    : (isDark
                        ? const Color(0xFF9A6C4C)
                        : const Color(0xFF9A6C4C)),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagosPedidosList({
    required bool isDark,
    required Color primaryColor,
  }) {
    final todosLosPedidos = [..._pedidosClientes, ..._pedidosRecurrentes];

    todosLosPedidos.sort((a, b) {
      if (a.fechaPago != null && b.fechaPago != null) {
        return b.fechaPago!.compareTo(a.fechaPago!);
      }
      if (a.fechaPago != null && b.fechaPago == null) return -1;
      if (a.fechaPago == null && b.fechaPago != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (todosLosPedidos.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payment_outlined,
                  size: 64,
                  color: isDark
                      ? const Color(0xFFA8A29E)
                      : const Color(0xFF78716C),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay pagos entregados en esta fecha',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todosLosPedidos.length,
      itemBuilder: (context, index) {
        final pedido = todosLosPedidos[index];
        final esRecurrente =
            _pedidosRecurrentes.any((p) => p.id == pedido.id) &&
                !_pedidosClientes.any((p) => p.id == pedido.id);

        return _buildPagoPedidoCard(
          isDark: isDark,
          pedido: pedido,
          primaryColor: primaryColor,
          esRecurrente: esRecurrente,
          esPendiente: false,
        );
      },
    );
  }

  Widget _buildPagosPendientesList({
    required bool isDark,
    required Color primaryColor,
  }) {
    final todosLosPedidos = [
      ..._pedidosClientesPendientes,
      ..._pedidosRecurrentesPendientes,
    ];

    todosLosPedidos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (todosLosPedidos.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_outlined,
                  size: 64,
                  color: isDark
                      ? const Color(0xFFA8A29E)
                      : const Color(0xFF78716C),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay pagos pendientes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: todosLosPedidos.length,
      itemBuilder: (context, index) {
        final pedido = todosLosPedidos[index];
        final esRecurrente =
            _pedidosRecurrentesPendientes.any((p) => p.id == pedido.id);
        return _buildPagoPedidoCard(
          isDark: isDark,
          pedido: pedido,
          primaryColor: primaryColor,
          esRecurrente: esRecurrente,
          esPendiente: true,
        );
      },
    );
  }

  Widget _buildPagoPedidoCard({
    required bool isDark,
    required PedidoCliente pedido,
    required Color primaryColor,
    bool esRecurrente = false,
    bool esPendiente = false,
  }) {
    final observaciones = pedido.observaciones ?? '';
    final esFiado = observaciones.toUpperCase().contains('FIADO');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPendiente
              ? Colors.orange.withOpacity(0.3)
              : (isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08)),
          width: esPendiente ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: esPendiente
                ? Colors.orange.withOpacity(0.2)
                : Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pedido.clienteNombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pedido.numeroPedido ?? 'Pedido #${pedido.id}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF9A6C4C)
                                    : const Color(0xFF9A6C4C),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (esRecurrente) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'RECURRENTE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(pedido.total),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    if (pedido.domicilio != null && pedido.domicilio! > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 12,
                            color: isDark
                                ? const Color(0xFF9A6C4C)
                                : const Color(0xFF9A6C4C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatCurrency(pedido.domicilio!),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF9A6C4C)
                                  : const Color(0xFF9A6C4C),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (esFiado)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: esPendiente
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: esPendiente
                                ? Colors.red.withOpacity(0.6)
                                : Colors.green.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          esPendiente ? 'FIADO' : 'FIADO - PAGADO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: esPendiente ? Colors.red : Colors.green,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (esPendiente)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'PENDIENTE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.payment,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF9A6C4C)
                      : const Color(0xFF9A6C4C),
                ),
                const SizedBox(width: 4),
                Text(
                  pedido.metodoPago ?? 'efectivo',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9A6C4C)
                        : const Color(0xFF9A6C4C),
                  ),
                ),
              ],
            ),
            if (observaciones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  observaciones,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFA8A29E)
                        : const Color(0xFF78716C),
                  ),
                ),
              ),
            if (pedido.domicilio != null && pedido.domicilio! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    Text(
                      _formatCurrency(pedido.total + pedido.domicilio!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
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

  Widget _buildGastosVariosList({
    required bool isDark,
    required Color primaryColor,
  }) {
    if (_gastosVarios.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: isDark
                      ? const Color(0xFFA8A29E)
                      : const Color(0xFF78716C),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay gastos varios en esta fecha',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gastosVarios.length,
      itemBuilder: (context, index) {
        final gasto = _gastosVarios[index];
        return _buildGastoVarioCard(
          isDark: isDark,
          gasto: gasto,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildGastoVarioCard({
    required bool isDark,
    required Map<String, dynamic> gasto,
    required Color primaryColor,
  }) {
    final descripcion = gasto['descripcion'] as String? ?? '';
    final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
    final tipo = gasto['tipo'] as String? ?? 'otro';
    final categoria = gasto['categoria'] as String?;

    IconData tipoIcon;
    Color tipoColor;
    switch (tipo) {
      case 'compra':
        tipoIcon = Icons.shopping_cart;
        tipoColor = Colors.blue;
        break;
      case 'pago':
        tipoIcon = Icons.payment;
        tipoColor = Colors.orange;
        break;
      case 'nomina':
        tipoIcon = Icons.badge;
        tipoColor = Colors.purple;
        break;
      default:
        tipoIcon = Icons.receipt;
        tipoColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tipoColor.withOpacity(isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(tipoIcon, color: tipoColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
                if (categoria != null && categoria.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    categoria,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatCurrency(monto),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

