import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../models/empleado.dart';
import '../../models/producto.dart';
import '../../services/factory_section_tracker.dart';

class FactoryStatisticsPage extends StatefulWidget {
  const FactoryStatisticsPage({super.key});

  @override
  State<FactoryStatisticsPage> createState() => _FactoryStatisticsPageState();
}

class _FactoryStatisticsPageState extends State<FactoryStatisticsPage> {
  Map<String, dynamic> _estadisticas = {};
  List<Empleado> _empleados = [];
  List<Producto> _productos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    FactorySectionTracker.enter();
    _loadData();
  }

  @override
  void dispose() {
    FactorySectionTracker.exit();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final estadisticas = await SupabaseService.getEstadisticasFabrica();
      final empleados = await SupabaseService.getEmpleadosActivos();
      final productos = await SupabaseService.getProductosActivos();

      setState(() {
        _estadisticas = estadisticas;
        _empleados = empleados;
        _productos = productos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando estadísticas: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 600;

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
                    color:
                        isDark
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
                    child: Text(
                      'Estadísticas de Fábrica',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance del botón de back
                ],
              ),
            ),

            // Content
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
                              // Resumen General
                              _buildSectionTitle('Resumen General', isDark),
                              const SizedBox(height: 16),
                              _buildResumenGeneral(isDark, isSmallScreen),

                              const SizedBox(height: 32),

                              // Pedidos a Fábrica
                              _buildSectionTitle('Pedidos a Fábrica', isDark),
                              const SizedBox(height: 16),
                              _buildPedidosFabricaStats(isDark, isSmallScreen),

                              const SizedBox(height: 32),

                              // Pedidos de Clientes
                              _buildSectionTitle('Pedidos de Clientes', isDark),
                              const SizedBox(height: 16),
                              _buildPedidosClientesStats(isDark, isSmallScreen),

                              const SizedBox(height: 32),

                              // Producción
                              _buildSectionTitle('Producción', isDark),
                              const SizedBox(height: 16),
                              _buildProduccionStats(isDark, isSmallScreen),

                              const SizedBox(height: 32),

                              // Top Productos
                              _buildSectionTitle(
                                'Productos Más Producidos',
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildTopProductos(isDark),

                              const SizedBox(height: 32),

                              // Tendencias (últimos 7 días)
                              _buildSectionTitle(
                                'Tendencias (Últimos 7 Días)',
                                isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildTendencias(isDark),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF1B130D),
      ),
    );
  }

  Widget _buildResumenGeneral(bool isDark, bool isSmallScreen) {
    final pedidosFabrica =
        _estadisticas['pedidos_fabrica'] as Map<String, dynamic>? ?? {};
    final pedidosClientes =
        _estadisticas['pedidos_clientes'] as Map<String, dynamic>? ?? {};
    final produccion =
        _estadisticas['produccion'] as Map<String, dynamic>? ?? {};
    final empleados = _estadisticas['empleados'] as Map<String, dynamic>? ?? {};

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Pedidos Fábrica',
            value: '${pedidosFabrica['total_hoy'] ?? 0}',
            subtitle: 'Hoy',
            icon: Icons.storefront,
            iconColor: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Pedidos Clientes',
            value: '${pedidosClientes['total_hoy'] ?? 0}',
            subtitle: 'Hoy',
            icon: Icons.chat,
            iconColor: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            isDark: isDark,
            title: 'Producción',
            value: '${produccion['total_hoy'] ?? 0}',
            subtitle: 'Unidades hoy',
            icon: Icons.restaurant,
            iconColor: const Color(0xFFEC6D13),
          ),
        ),
        if (!isSmallScreen) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              isDark: isDark,
              title: 'Empleados',
              value: '${empleados['total_activos'] ?? 0}',
              subtitle: 'Activos',
              icon: Icons.people,
              iconColor: Colors.purple,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard({
    required bool isDark,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosFabricaStats(bool isDark, bool isSmallScreen) {
    final pedidosFabrica =
        _estadisticas['pedidos_fabrica'] as Map<String, dynamic>? ?? {};
    final porEstado =
        pedidosFabrica['por_estado'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Items Hoy: ${pedidosFabrica['total_items_hoy'] ?? 0}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          const SizedBox(height: 16),
          _buildEstadoRow(
            'Pendientes',
            porEstado['pendiente'] ?? 0,
            Colors.orange,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'En Preparación',
            porEstado['en_preparacion'] ?? 0,
            Colors.blue,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'Enviados',
            porEstado['enviado'] ?? 0,
            Colors.purple,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'Entregados',
            porEstado['entregado'] ?? 0,
            Colors.green,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'Cancelados',
            porEstado['cancelado'] ?? 0,
            Colors.red,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosClientesStats(bool isDark, bool isSmallScreen) {
    final pedidosClientes =
        _estadisticas['pedidos_clientes'] as Map<String, dynamic>? ?? {};
    final porEstado =
        pedidosClientes['por_estado'] as Map<String, dynamic>? ?? {};
    final ingresosHoy =
        (pedidosClientes['ingresos_hoy'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ingresos Hoy: \$${NumberFormat('#,##0.00').format(ingresosHoy)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          const SizedBox(height: 16),
          _buildEstadoRow(
            'Pendientes',
            porEstado['pendiente'] ?? 0,
            Colors.orange,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'En Preparación',
            porEstado['en_preparacion'] ?? 0,
            Colors.blue,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'Enviados',
            porEstado['enviado'] ?? 0,
            Colors.purple,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'Entregados',
            porEstado['entregado'] ?? 0,
            Colors.green,
            isDark,
          ),
          const SizedBox(height: 8),
          _buildEstadoRow(
            'Cancelados',
            porEstado['cancelado'] ?? 0,
            Colors.red,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoRow(String label, int value, Color color, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
            ),
          ],
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildProduccionStats(bool isDark, bool isSmallScreen) {
    final produccion =
        _estadisticas['produccion'] as Map<String, dynamic>? ?? {};
    final porEmpleado =
        produccion['por_empleado'] as Map<String, dynamic>? ?? {};

    final empleadosMap = {for (var e in _empleados) e.id: e};
    final produccionEmpleados = <Map<String, dynamic>>[];

    porEmpleado.forEach((empleadoIdStr, cantidad) {
      final empleadoId = int.tryParse(empleadoIdStr);
      if (empleadoId != null) {
        final empleado = empleadosMap[empleadoId];
        if (empleado != null) {
          produccionEmpleados.add({
            'empleado': empleado,
            'cantidad': cantidad as int,
          });
        }
      }
    });

    produccionEmpleados.sort(
      (a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Producción por Empleado (Hoy)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          const SizedBox(height: 16),
          if (produccionEmpleados.isEmpty)
            Text(
              'No hay producción registrada hoy',
              style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
              ),
            )
          else
            ...produccionEmpleados.map((item) {
              final empleado = item['empleado'] as Empleado;
              final cantidad = item['cantidad'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        empleado.nombre,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ),
                    Text(
                      '$cantidad unidades',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEC6D13),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTopProductos(bool isDark) {
    final topProductos =
        _estadisticas['top_productos'] as Map<String, dynamic>? ?? {};

    final productosMap = {for (var p in _productos) p.id: p};
    final productosProduccion = <Map<String, dynamic>>[];

    topProductos.forEach((productoIdStr, cantidad) {
      final productoId = int.tryParse(productoIdStr);
      if (productoId != null) {
        final producto = productosMap[productoId];
        if (producto != null) {
          productosProduccion.add({
            'producto': producto,
            'cantidad': cantidad as int,
          });
        }
      }
    });

    productosProduccion.sort(
      (a, b) => (b['cantidad'] as int).compareTo(a['cantidad'] as int),
    );
    final top5 = productosProduccion.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 Productos (Últimos 7 Días)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          const SizedBox(height: 16),
          if (top5.isEmpty)
            Text(
              'No hay producción registrada',
              style: TextStyle(
                fontSize: 14,
                color:
                    isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
              ),
            )
          else
            ...top5.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final producto = item['producto'] as Producto;
              final cantidad = item['cantidad'] as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEC6D13).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEC6D13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        producto.nombre,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ),
                    Text(
                      '$cantidad unidades',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEC6D13),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTendencias(bool isDark) {
    final produccion =
        _estadisticas['produccion'] as Map<String, dynamic>? ?? {};
    final ultimos7Dias =
        produccion['ultimos_7_dias'] as Map<String, dynamic>? ?? {};

    if (ultimos7Dias.isEmpty) {
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
        child: Text(
          'No hay datos de producción en los últimos 7 días',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
          ),
        ),
      );
    }

    final maxValue = ultimos7Dias.values
        .map((v) => (v as num?)?.toInt() ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    final fechas = ultimos7Dias.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Producción Diaria',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          const SizedBox(height: 24),
          ...fechas.map((fecha) {
            final cantidad = (ultimos7Dias[fecha] as num?)?.toInt() ?? 0;
            final porcentaje = maxValue > 0 ? (cantidad / maxValue) : 0.0;

            // Formatear fecha
            DateTime? fechaDate;
            try {
              fechaDate = DateTime.parse(fecha);
            } catch (e) {
              fechaDate = null;
            }

            final fechaFormateada =
                fechaDate != null
                    ? DateFormat('dd/MM').format(fechaDate)
                    : fecha;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fechaFormateada,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFF9A6C4C)
                                  : const Color(0xFF9A6C4C),
                        ),
                      ),
                      Text(
                        '$cantidad unidades',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: porcentaje,
                      minHeight: 8,
                      backgroundColor:
                          isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFEC6D13),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
