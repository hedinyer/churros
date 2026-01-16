import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/supabase_service.dart';
import 'factory_orders_list_page.dart';
import 'production_page.dart';
import 'client_orders_list_page.dart';
import 'dispatch_page.dart';
import 'manual_order_page.dart';

class FactoryDashboardPage extends StatefulWidget {
  final AppUser currentUser;

  const FactoryDashboardPage({super.key, required this.currentUser});

  @override
  State<FactoryDashboardPage> createState() => _FactoryDashboardPageState();
}

class _FactoryDashboardPageState extends State<FactoryDashboardPage> {
  Map<String, dynamic> _resumen = {};
  bool _isLoading = true;

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
      // Cargar resumen de fábrica
      final resumen = await SupabaseService.getResumenFabrica();

      setState(() {
        _resumen = resumen;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de fábrica: $e');
      setState(() {
        _isLoading = false;
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
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Navigator.pop(context),
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  Expanded(
                    child: Text(
                      'Fábrica Central',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Resumen Section
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Estado de hoy',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                isDark
                                                    ? const Color(0xFF9A6C4C)
                                                    : const Color(0xFF9A6C4C),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Resumen',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(
                                          isDark ? 0.3 : 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              right: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 8,
                                                height: 8,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 1.5,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.green),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'En operación',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // KPIs Grid
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildKPICard(
                                        isDark: isDark,
                                        value:
                                            _resumen['total_pedidos']
                                                ?.toString() ??
                                            '0',
                                        label: 'Pedidos\nTotales',
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildKPICard(
                                        isDark: isDark,
                                        value:
                                            _resumen['pedidos_pendientes']
                                                ?.toString() ??
                                            '0',
                                        label: 'Pendientes\nProd.',
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF1B130D),
                                        hasNotification: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildKPICard(
                                        isDark: isDark,
                                        value:
                                            '${(_resumen['meta_diaria'] as num?)?.toInt() ?? 0}%',
                                        label: 'Meta\nDiaria',
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Accesos Directos Section
                            Text(
                              'Accesos Directos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                              ),
                            ),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                              children: [
                                _buildAccessButton(
                                  isDark: isDark,
                                  icon: Icons.storefront,
                                  iconColor: Colors.blue,
                                  title: 'Pedidos Puntos',
                                  subtitle: 'App Interna',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const FactoryOrdersListPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildAccessButton(
                                  isDark: isDark,
                                  icon: Icons.chat,
                                  iconColor: Colors.green,
                                  title: 'Pedidos Clientes',
                                  subtitle: 'WhatsApp',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                const ClientOrdersListPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildAccessButton(
                                  isDark: isDark,
                                  icon: Icons.restaurant,
                                  iconColor: primaryColor,
                                  title: 'Producción',
                                  subtitle: 'Gestión Cocina',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const ProductionPage(),
                                      ),
                                    );
                                  },
                                ),
                                _buildAccessButton(
                                  isDark: isDark,
                                  icon: Icons.local_shipping,
                                  iconColor: Colors.grey,
                                  title: 'Despacho',
                                  subtitle: 'Logística',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => const DispatchPage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                            // Estadísticas Button (Full Width)
                            const SizedBox(height: 16),
                            _buildStatsButton(isDark: isDark),

                            const SizedBox(
                              height: 100,
                            ), // Space for bottom button
                          ],
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
                const Icon(Icons.add_circle, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Registrar Pedido Manual',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPICard({
    required bool isDark,
    required String value,
    required String label,
    required Color color,
    bool hasNotification = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (hasNotification)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
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
                child: Icon(icon, size: 64, color: iconColor),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                    if (notificationCount != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            notificationCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsButton({required bool isDark}) {
    return GestureDetector(
      onTap: () {
        // Navegar a estadísticas
      },
      child: Container(
        padding: const EdgeInsets.all(20),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estadísticas de Fábrica',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reportes y métricas',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isDark
                              ? const Color(0xFF9A6C4C)
                              : const Color(0xFF9A6C4C),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
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
