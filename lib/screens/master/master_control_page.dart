import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../services/supabase_service.dart';
import '../../main.dart';
import 'master_inventory_page.dart';
import 'master_opening_inventory_page.dart';
import 'master_factory_overview_page.dart';
import 'master_historical_sales_page.dart';

class MasterControlPage extends StatefulWidget {
  const MasterControlPage({super.key});

  @override
  State<MasterControlPage> createState() => _MasterControlPageState();
}

class _MasterControlPageState extends State<MasterControlPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Sucursal> _sucursales = [];
  Map<int, Map<String, dynamic>> _resumenes = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Totales globales
  double _totalVentas = 0;
  double _totalEfectivo = 0;
  double _totalTransferencias = 0;
  double _totalGastos = 0;
  int _totalTickets = 0;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final allSucursales = await SupabaseService.getAllSucursales();
      
      // Filtrar sucursales TEST, dangond y centro
      final sucursales = allSucursales.where((sucursal) {
        final nombre = sucursal.nombre.toLowerCase();
        return !nombre.contains('test') && 
               !nombre.contains('dangond') && 
               !nombre.contains('centro');
      }).toList();
      
      final resumenes = <int, Map<String, dynamic>>{};

      await Future.wait(
        sucursales.map((sucursal) async {
          try {
            final resumenVentas =
                await SupabaseService.getResumenVentasHoy(sucursal.id);
            final gastos = await SupabaseService.getGastosPuntoVenta(
                sucursalId: sucursal.id);
            final totalGastos = gastos.fold<double>(
              0.0,
              (sum, g) => sum + ((g['monto'] as num?)?.toDouble() ?? 0.0),
            );

            resumenes[sucursal.id] = {
              'ventas': resumenVentas['total'] ?? 0.0,
              'efectivo': resumenVentas['total_efectivo'] ?? 0.0,
              'transferencias': resumenVentas['total_transferencia'] ?? 0.0,
              'gastos': totalGastos,
              'tickets': resumenVentas['tickets'] ?? 0,
            };
          } catch (e) {
            print('Error cargando resumen de ${sucursal.nombre}: $e');
            resumenes[sucursal.id] = {
              'ventas': 0.0,
              'efectivo': 0.0,
              'transferencias': 0.0,
              'gastos': 0.0,
              'tickets': 0,
            };
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
        _totalVentas = tVentas;
        _totalEfectivo = tEfectivo;
        _totalTransferencias = tTransf;
        _totalGastos = tGastos;
        _totalTickets = tTickets;
        _isLoading = false;
      });

      _fadeController.forward(from: 0);
    } catch (e) {
      print('Error cargando datos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _navigateToInventory(Sucursal sucursal) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MasterInventoryPage(sucursal: sucursal),
      ),
    ).then((_) => _loadData());
  }

  void _openSucursalOptions(Sucursal sucursal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? const Color(0xFF1F2933) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.inventory_2_rounded,
                    color: primaryColor,
                  ),
                  title: const Text('Inventario actual'),
                  subtitle: const Text('Cantidades actuales en el punto'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToInventory(sucursal);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.login_rounded,
                    color: isDark ? Colors.amber : Colors.orange,
                  ),
                  title: const Text('Inventario apertura de hoy'),
                  subtitle: const Text(
                    'Cantidades registradas al abrir el punto',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MasterOpeningInventoryPage(sucursal: sucursal),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCurrency(double value) {
    return '\$${NumberFormat('#,###', 'es').format(value.round())}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
    final horizontalPad = isSmallScreen ? 16.0 : 24.0;

    // Deshabilitar escalado de texto del sistema
    final mediaQueryData = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(1.0),
    );

    return MediaQuery(
      data: mediaQueryData,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF221810) : const Color(0xFFF5F3F1),
        body: SafeArea(
          child: _isLoading
              ? _buildLoadingState(primaryColor, isDark)
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    color: primaryColor,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: _buildHeader(
                              isDark, primaryColor, horizontalPad),
                        ),
                        // Global Summary
                        SliverToBoxAdapter(
                          child: _buildGlobalSummary(
                              isDark, primaryColor, horizontalPad),
                        ),
                        // Section title
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalPad, 28, horizontalPad, 12),
                            child: Row(
                              children: [
                                Text(
                                  'Puntos de venta',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_sucursales.length}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Store cards
                        _sucursales.isEmpty
                            ? SliverFillRemaining(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.store_mall_directory_outlined,
                                          size: 64,
                                          color: isDark
                                              ? const Color(0xFF44403C)
                                              : const Color(0xFFD6D3D1)),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No hay sucursales disponibles',
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
                                    horizontalPad, 0, horizontalPad, 100),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isSmallScreen
                                        ? 1
                                        : (isMediumScreen ? 2 : 3),
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: isSmallScreen
                                        ? 1.55
                                        : (isMediumScreen ? 1.3 : 1.2),
                                  ),
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
                                      return _buildSucursalCard(
                                          sucursal,
                                          resumen,
                                          isDark,
                                          primaryColor,
                                          isSmallScreen);
                                    },
                                    childCount: _sucursales.length,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando datos...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color:
                  isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color primaryColor, double horizontalPad) {
    final today = DateFormat('EEEE d \'de\' MMMM, yyyy', 'es').format(DateTime.now());

    return Padding(
      padding:
          EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          // Title & date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control Maestro',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  today,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF9C9591)
                        : const Color(0xFF8A8380),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          // Actions (Histórico arriba, Fábrica debajo)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MasterHistoricalSalesPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Histórico',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const MasterFactoryOverviewPage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(isDark ? 0.16 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.factory_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Fábrica',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2018)
                      : const Color(0xFFEDE9E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  size: 22,
                  color:
                      isDark ? const Color(0xFFD6D3D1) : const Color(0xFF57534E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2018)
                      : const Color(0xFFEDE9E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout_rounded,
                  size: 22,
                  color:
                      isDark ? const Color(0xFFD6D3D1) : const Color(0xFF57534E),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalSummary(
      bool isDark, Color primaryColor, double horizontalPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 24, horizontalPad, 0),
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
            // Total ventas
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VENTAS TOTALES HOY',
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
            // Breakdown
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

    // Proporción efectivo/transferencia para la mini barra
    final totalPayments = efectivo + transferencias;
    final cashRatio =
        totalPayments > 0 ? efectivo / totalPayments : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openSucursalOptions(sucursal),
        child: Container(
          padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store header
              Row(
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
                    child: Text(
                      sucursal.nombre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1B130D),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3D3530)
                          : const Color(0xFFF5F3F1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isDark
                          ? const Color(0xFF9C9591)
                          : const Color(0xFF8A8380),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ventas prominente
              Text(
                _formatCurrency(ventas),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1B130D),
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Ventas de hoy',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFF9C9591)
                          : const Color(0xFF8A8380),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.receipt_outlined,
                      size: 13,
                      color: isDark
                          ? const Color(0xFF9C9591)
                          : const Color(0xFF8A8380)),
                  const SizedBox(width: 4),
                  Text(
                    '$tickets tickets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF9C9591)
                          : const Color(0xFF8A8380),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Payment breakdown bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (cashRatio * 100).round().clamp(0, 100),
                        child: Container(
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      if ((100 - (cashRatio * 100).round()).clamp(0, 100) > 0)
                        Expanded(
                          flex: (100 - (cashRatio * 100).round())
                              .clamp(0, 100),
                          child: Container(
                            color: const Color(0xFF3B82F6),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Efectivo / Transfer / Gastos row
              Row(
                children: [
                  _buildMiniMetric(
                    _formatCurrency(efectivo),
                    'Efectivo',
                    const Color(0xFF10B981),
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniMetric(
                    _formatCurrency(transferencias),
                    'Transfer.',
                    const Color(0xFF3B82F6),
                    isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildMiniMetric(
                    _formatCurrency(gastos),
                    'Gastos',
                    const Color(0xFFEF4444),
                    isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniMetric(
      String value, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
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
      ),
    );
  }
}
