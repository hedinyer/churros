import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../services/supabase_service.dart';

class MasterHistoricalSalesPage extends StatefulWidget {
  const MasterHistoricalSalesPage({super.key});

  @override
  State<MasterHistoricalSalesPage> createState() =>
      _MasterHistoricalSalesPageState();
}

class _MasterHistoricalSalesPageState
    extends State<MasterHistoricalSalesPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<Sucursal> _sucursales = [];
  Map<int, Map<String, dynamic>> _resumenes = {}; // sucursalId -> resumen
  Map<int, List<Map<String, dynamic>>> _ventasDetalles =
      {}; // sucursalId -> lista de ventas
  Map<int, List<Map<String, dynamic>>> _gastosDetalles =
      {}; // sucursalId -> lista de gastos
  Map<int, bool> _expandedSucursales = {}; // sucursalId -> expanded

  // Totales globales
  double _totalVentas = 0;
  double _totalEfectivo = 0;
  double _totalTransferencias = 0;
  double _totalGastos = 0;
  int _totalTickets = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _selectDate() async {
    // Usar Navigator para obtener el contexto correcto con localizaciones
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (BuildContext dialogContext, Widget? child) {
        // Usar el contexto del diálogo para obtener las localizaciones
        return Theme(
          data: Theme.of(dialogContext).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFFEC6D13),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1B130D),
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
    setState(() => _isLoading = true);

    try {
      // Obtener todas las sucursales activas (filtrar test, dangond, centro)
      final allSucursales = await SupabaseService.getAllSucursales();
      final sucursales = allSucursales.where((sucursal) {
        final nombre = sucursal.nombre.toLowerCase();
        return !nombre.contains('test') &&
            !nombre.contains('dangond') &&
            !nombre.contains('centro');
      }).toList();

      final fechaStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final resumenes = <int, Map<String, dynamic>>{};
      final ventasDetalles = <int, List<Map<String, dynamic>>>{};
      final gastosDetalles = <int, List<Map<String, dynamic>>>{};

      await Future.wait(
        sucursales.map((sucursal) async {
          try {
            // Resumen de ventas
            final resumenVentas =
                await SupabaseService.getResumenVentasPorFecha(
              sucursal.id,
              fechaStr,
            );

            // Gastos
            final gastos = await SupabaseService.getGastosPuntoVentaPorFecha(
              sucursalId: sucursal.id,
              fecha: fechaStr,
            );
            final totalGastos = gastos.fold<double>(
              0.0,
              (sum, g) => sum + ((g['monto'] as num?)?.toDouble() ?? 0.0),
            );

            // Ventas completas
            final ventas = await SupabaseService.getVentasPorFecha(
              sucursal.id,
              fechaStr,
            );

            resumenes[sucursal.id] = {
              'ventas': resumenVentas['total'] ?? 0.0,
              'efectivo': resumenVentas['total_efectivo'] ?? 0.0,
              'transferencias': resumenVentas['total_transferencia'] ?? 0.0,
              'gastos': totalGastos,
              'tickets': resumenVentas['tickets'] ?? 0,
            };

            ventasDetalles[sucursal.id] = ventas;
            gastosDetalles[sucursal.id] = gastos;
          } catch (e) {
            print('Error cargando datos de ${sucursal.nombre}: $e');
            resumenes[sucursal.id] = {
              'ventas': 0.0,
              'efectivo': 0.0,
              'transferencias': 0.0,
              'gastos': 0.0,
              'tickets': 0,
            };
            ventasDetalles[sucursal.id] = [];
            gastosDetalles[sucursal.id] = [];
          }
        }),
      );

      // Calcular totales globales
      double tVentas = 0, tEfectivo = 0, tTransf = 0, tGastos = 0;
      int tTickets = 0;
      for (final r in resumenes.values) {
        tVentas += (r['ventas'] as num?)?.toDouble() ?? 0;
        tEfectivo += (r['efectivo'] as num?)?.toDouble() ?? 0;
        tTransf += (r['transferencias'] as num?)?.toDouble() ?? 0;
        tGastos += (r['gastos'] as num?)?.toDouble() ?? 0;
        tTickets += (r['tickets'] as num?)?.toInt() ?? 0;
      }

      setState(() {
        _sucursales = sucursales;
        _resumenes = resumenes;
        _ventasDetalles = ventasDetalles;
        _gastosDetalles = gastosDetalles;
        _totalVentas = tVentas;
        _totalEfectivo = tEfectivo;
        _totalTransferencias = tTransf;
        _totalGastos = tGastos;
        _totalTickets = tTickets;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos históricos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleSucursal(int sucursalId) {
    setState(() {
      _expandedSucursales[sucursalId] =
          !(_expandedSucursales[sucursalId] ?? false);
    });
  }

  String _formatCurrency(double value) {
    return '\$${NumberFormat('#,###', 'es').format(value.round())}';
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null) return '';
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final horizontalPad = isSmallScreen ? 16.0 : 24.0;

    final mediaQueryData = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(1.0),
    );

    return MediaQuery(
      data: mediaQueryData,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF221810) : const Color(0xFFF5F3F1),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(isDark, primaryColor, horizontalPad),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Cargando datos históricos...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFFA8A29E)
                                    : const Color(0xFF78716C),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: primaryColor,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            // Date selector
                            SliverToBoxAdapter(
                              child: _buildDateSelector(
                                  isDark, primaryColor, horizontalPad),
                            ),

                            // Global Summary
                            SliverToBoxAdapter(
                              child: _buildGlobalSummary(
                                  isDark, primaryColor, horizontalPad),
                            ),

                            // Sucursales
                            _sucursales.isEmpty
                                ? SliverFillRemaining(
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined,
                                              size: 64,
                                              color: isDark
                                                  ? const Color(0xFF44403C)
                                                  : const Color(0xFFD6D3D1)),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No hay datos para esta fecha',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isDark
                                                  ? const Color(0xFFA8A29E)
                                                  : const Color(0xFF78716C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : SliverPadding(
                                    padding: EdgeInsets.fromLTRB(
                                        horizontalPad, 20, horizontalPad, 100),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final sucursal = _sucursales[index];
                                          final resumen =
                                              _resumenes[sucursal.id] ??
                                                  {
                                                    'ventas': 0.0,
                                                    'efectivo': 0.0,
                                                    'transferencias': 0.0,
                                                    'gastos': 0.0,
                                                    'tickets': 0,
                                                  };
                                          final isExpanded =
                                              _expandedSucursales[sucursal.id] ??
                                                  false;

                                          return _buildSucursalCard(
                                            sucursal,
                                            resumen,
                                            isExpanded,
                                            isDark,
                                            primaryColor,
                                            isSmallScreen,
                                          );
                                        },
                                        childCount: _sucursales.length,
                                      ),
                                    ),
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

  Widget _buildHeader(bool isDark, Color primaryColor, double horizontalPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 0),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2018)
                      : const Color(0xFFEDE9E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: isDark
                      ? const Color(0xFFD6D3D1)
                      : const Color(0xFF57534E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Histórico de Ventas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Consulta ventas y gastos por fecha',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildDateSelector(
      bool isDark, Color primaryColor, double horizontalPad) {
    final dateStr = DateFormat('EEEE d \'de\' MMMM, yyyy', 'es')
        .format(_selectedDate)
        .toUpperCase();

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2018) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF3D3530)
                    : const Color(0xFFE7E5E4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_today_rounded,
                      size: 20, color: primaryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fecha seleccionada',
                        style: TextStyle(
                          fontSize: 12,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark
                      ? const Color(0xFF9C9591)
                      : const Color(0xFF8A8380),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalSummary(
      bool isDark, Color primaryColor, double horizontalPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.85),
              const Color(0xFFD45A0A),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL VENTAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatCurrency(_totalVentas),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        '$_totalTickets tickets',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildGlobalMetric(
                    Icons.payments_rounded,
                    'Efectivo',
                    _formatCurrency(_totalEfectivo),
                  ),
                  _buildGlobalDivider(),
                  _buildGlobalMetric(
                    Icons.swap_horiz_rounded,
                    'Transferencias',
                    _formatCurrency(_totalTransferencias),
                  ),
                  _buildGlobalDivider(),
                  _buildGlobalMetric(
                    Icons.trending_down_rounded,
                    'Gastos',
                    _formatCurrency(_totalGastos),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: Colors.white.withOpacity(0.8)),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withOpacity(0.15),
    );
  }

  Widget _buildSucursalCard(
    Sucursal sucursal,
    Map<String, dynamic> resumen,
    bool isExpanded,
    bool isDark,
    Color primaryColor,
    bool isSmallScreen,
  ) {
    final ventas = (resumen['ventas'] as num?)?.toDouble() ?? 0.0;
    final efectivo = (resumen['efectivo'] as num?)?.toDouble() ?? 0.0;
    final transferencias =
        (resumen['transferencias'] as num?)?.toDouble() ?? 0.0;
    final gastos = (resumen['gastos'] as num?)?.toDouble() ?? 0.0;
    final tickets = (resumen['tickets'] as num?)?.toInt() ?? 0;

    final ventasList = _ventasDetalles[sucursal.id] ?? [];
    final gastosList = _gastosDetalles[sucursal.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? const Color(0xFF3D3530).withOpacity(0.6)
              : const Color(0xFFE7E5E4).withOpacity(0.7),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              onTap: () => _toggleSucursal(sucursal.id),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(Icons.storefront_rounded,
                          size: 20, color: primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sucursal.nombre,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1B130D),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$tickets tickets • ${_formatCurrency(ventas)}',
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
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: isDark
                          ? const Color(0xFF9C9591)
                          : const Color(0xFF8A8380),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? const Color(0xFF3D3530)
                  : const Color(0xFFE7E5E4),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen
                  Row(
                    children: [
                      Expanded(
                        child: _buildMiniMetric(
                          _formatCurrency(efectivo),
                          'Efectivo',
                          const Color(0xFF10B981),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniMetric(
                          _formatCurrency(transferencias),
                          'Transfer.',
                          const Color(0xFF3B82F6),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildMiniMetric(
                          _formatCurrency(gastos),
                          'Gastos',
                          const Color(0xFFEF4444),
                          isDark,
                        ),
                      ),
                    ],
                  ),

                  if (ventasList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Ventas del día (${ventasList.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...ventasList.take(10).map((venta) {
                      return _buildVentaItem(venta, isDark);
                    }),
                    if (ventasList.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '... y ${ventasList.length - 10} ventas más',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF9C9591)
                                : const Color(0xFF8A8380),
                          ),
                        ),
                      ),
                  ],

                  if (gastosList.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Gastos del día (${gastosList.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...gastosList.map((gasto) {
                      return _buildGastoItem(gasto, isDark);
                    }),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMetric(
      String value, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF9C9591)
                        : const Color(0xFF8A8380),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVentaItem(Map<String, dynamic> venta, bool isDark) {
    final total = (venta['total'] as num?)?.toDouble() ?? 0.0;
    final metodoPago = (venta['metodo_pago'] as String? ?? 'efectivo')
        .toUpperCase()
        .substring(0, 1);
    final hora = _formatTime(venta['hora_venta'] as String?);
    final ticket = venta['numero_ticket'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1917) : const Color(0xFFF5F3F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                metodoPago,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatCurrency(total),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
                if (hora.isNotEmpty || ticket != null)
                  Text(
                    [if (hora.isNotEmpty) hora, if (ticket != null) 'Ticket: $ticket']
                        .join(' • '),
                    style: TextStyle(
                      fontSize: 11,
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
    );
  }

  Widget _buildGastoItem(Map<String, dynamic> gasto, bool isDark) {
    final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
    final descripcion = gasto['descripcion'] as String? ?? 'Sin descripción';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1917) : const Color(0xFFF5F3F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_down_rounded,
              size: 18,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(monto),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
