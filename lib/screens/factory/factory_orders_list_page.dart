import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pedido_fabrica.dart';
import '../../models/producto.dart';
import '../../services/supabase_service.dart';

class FactoryOrdersListPage extends StatefulWidget {
  const FactoryOrdersListPage({super.key});

  @override
  State<FactoryOrdersListPage> createState() => _FactoryOrdersListPageState();
}

class _FactoryOrdersListPageState extends State<FactoryOrdersListPage> {
  List<PedidoFabrica> _pedidos = [];
  List<Producto> _productos = [];
  String _filtroEstado =
      'todos'; // 'todos', 'pendiente', 'enviado', 'entregado'
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      await SupabaseService.client
          .from('users')
          .select()
          .limit(1)
          .maybeSingle();
      setState(() {
        _isOnline = true;
      });
    } catch (e) {
      setState(() {
        _isOnline = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar productos para mostrar nombres
      final productos = await SupabaseService.getProductosActivos();

      // Cargar pedidos de todas las sucursales
      final pedidos =
          await SupabaseService.getPedidosFabricaRecientesTodasSucursales(
            limit: 100,
          );

      setState(() {
        _productos = productos;
        _pedidos = pedidos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando pedidos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PedidoFabrica> _getPedidosFiltrados() {
    if (_filtroEstado == 'todos') {
      return _pedidos;
    }
    return _pedidos.where((p) => p.estado == _filtroEstado).toList();
  }

  String _getEstadoBadge(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
      case 'enviado':
        return 'Enviado';
      case 'entregado':
        return 'Entregado';
      case 'cancelado':
        return 'Cancelado';
      default:
        return estado;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return const Color(0xFFEC6D13); // primary orange
      case 'enviado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Icons.sync_problem;
      case 'enviado':
        return Icons.send;
      case 'entregado':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  bool _puedeDespachar(String estadoActual) {
    return estadoActual.toLowerCase() == 'pendiente';
  }

  Future<void> _despacharPedido(PedidoFabrica pedido) async {
    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2D211A) : Colors.white,
          title: Text(
            'CONFIRMAR DESPACHO',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),
          content: Text(
            '¿ESTÁS SEGURO DE QUE DESEAS DESPACHAR EL PEDIDO ${pedido.numeroPedido ?? '#${pedido.id}'}?',
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : const Color(0xFF78716C),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'CANCELAR',
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : const Color(0xFF78716C),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('DESPACHAR'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    // Mostrar loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    try {
      // Actualizar estado del pedido a "enviado"
      final resultado = await SupabaseService.actualizarEstadoPedidoFabrica(
        pedidoId: pedido.id,
        nuevoEstado: 'enviado',
      );

      // Cerrar loading
      if (mounted) Navigator.pop(context);

      if (resultado['exito'] == true) {
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text((resultado['mensaje'] as String?)?.toUpperCase() ?? 'PEDIDO DESPACHADO EXITOSAMENTE'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Recargar datos
        await _loadData();
      } else {
        // Mostrar mensaje de error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text((resultado['mensaje'] as String?)?.toUpperCase() ?? 'ERROR AL DESPACHAR EL PEDIDO'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading si aún está abierto
      if (mounted) Navigator.pop(context);
      
      // Mostrar error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ERROR: ${e.toString().toUpperCase()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return DateFormat('d MMM', 'es').format(dateTime);
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('d MMM, h:mm a', 'es').format(dateTime);
  }

  Producto? _getProductoById(int productoId) {
    try {
      return _productos.firstWhere((p) => p.id == productoId);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    final pedidosFiltrados = _getPedidosFiltrados();

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
                          color: isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pedidos Puntos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                  ),
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isOnline
                              ? Colors.green.withOpacity(isDark ? 0.25 : 0.12)
                              : primaryColor.withOpacity(isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            _isOnline
                                ? Colors.green.withOpacity(isDark ? 0.4 : 0.25)
                                : primaryColor.withOpacity(isDark ? 0.4 : 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.green : primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isOnline ? Colors.green : primaryColor).withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isOnline ? Colors.green : primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Filtros
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D211A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      isDark: isDark,
                      label: 'Todos',
                      isSelected: _filtroEstado == 'todos',
                      onTap: () => setState(() => _filtroEstado = 'todos'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      isDark: isDark,
                      label: 'Pendientes',
                      isSelected: _filtroEstado == 'pendiente',
                      color: const Color(0xFFEC6D13),
                      onTap: () => setState(() => _filtroEstado = 'pendiente'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      isDark: isDark,
                      label: 'Enviados',
                      isSelected: _filtroEstado == 'enviado',
                      color: Colors.blue,
                      onTap: () => setState(() => _filtroEstado = 'enviado'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      isDark: isDark,
                      label: 'Entregados',
                      isSelected: _filtroEstado == 'entregado',
                      color: Colors.green,
                      onTap: () => setState(() => _filtroEstado = 'entregado'),
                    ),
                  ],
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
                        child:
                            pedidosFiltrados.isEmpty
                                ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 64,
                                          color:
                                              isDark
                                                  ? const Color(0xFFA8A29E)
                                                  : const Color(0xFF78716C),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No hay pedidos',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No se encontraron pedidos con el filtro seleccionado',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                isDark
                                                    ? const Color(0xFFA8A29E)
                                                    : const Color(0xFF78716C),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 16 : 20,
                                    vertical: 16,
                                  ),
                                  itemCount: pedidosFiltrados.length,
                                  itemBuilder: (context, index) {
                                    final pedido = pedidosFiltrados[index];
                                    return _buildOrderCard(
                                      isDark: isDark,
                                      pedido: pedido,
                                      primaryColor: primaryColor,
                                    );
                                  },
                                ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required bool isDark,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor =
        color ?? (isDark ? Colors.white : const Color(0xFF1B130D));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? chipColor.withOpacity(isDark ? 0.25 : 0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color:
                  isSelected
                      ? chipColor.withOpacity(isDark ? 0.4 : 0.25)
                      : (isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.12)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: chipColor.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
              color:
                  isSelected
                      ? chipColor
                      : (isDark
                          ? const Color(0xFFA8A29E)
                          : const Color(0xFF78716C)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required bool isDark,
    required PedidoFabrica pedido,
    required Color primaryColor,
  }) {
    final estado = pedido.estado;
    final estadoBadge = _getEstadoBadge(estado);
    final estadoColor = _getEstadoColor(estado);
    final estadoIcon = _getEstadoIcon(estado);
    final timeAgo = _formatTimeAgo(pedido.createdAt);
    final fechaHora = _formatDateTime(pedido.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header del pedido
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                ),
              ),
            ),
            child: Row(
              children: [
                // Borde izquierdo de color para pedidos pendientes
                if (estado == 'pendiente')
                  Container(
                    width: 4,
                    height: 60,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                  ),
                Expanded(
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
                                  pedido.numeroPedido ?? 'Pedido #${pedido.id}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF1B130D),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.storefront,
                                      size: 14,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      pedido.sucursal?.nombre ?? 'Sucursal',
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
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: estadoColor.withOpacity(
                                isDark ? 0.25 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: estadoColor.withOpacity(
                                  isDark ? 0.4 : 0.25,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: estadoColor.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(estadoIcon, size: 14, color: estadoColor),
                                const SizedBox(width: 6),
                                Text(
                                  estadoBadge,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: estadoColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color:
                                isDark
                                    ? const Color(0xFFA8A29E)
                                    : const Color(0xFF78716C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$timeAgo • $fechaHora',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.shopping_cart,
                            size: 14,
                            color:
                                isDark
                                    ? const Color(0xFFA8A29E)
                                    : const Color(0xFF78716C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${pedido.totalItems} items',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
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

          // Botón para despacho
          if (_puedeDespachar(estado))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom:
                      pedido.detalles != null && pedido.detalles!.isNotEmpty
                          ? BorderSide(
                            color:
                                isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.05),
                          )
                          : BorderSide.none,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _despacharPedido(pedido),
                  icon: const Icon(Icons.local_shipping, size: 20),
                  label: const Text(
                    'Despachar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 4,
                    shadowColor: Colors.blue.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Detalles de productos
          if (pedido.detalles != null && pedido.detalles!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.black.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productos:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark
                              ? const Color(0xFFA8A29E)
                              : const Color(0xFF78716C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...pedido.detalles!.map((detalle) {
                    final producto = _getProductoById(detalle.productoId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color:
                                  isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${detalle.cantidad} ${producto?.unidadMedida ?? 'unidad'} ${producto?.nombre ?? 'Producto #${detalle.productoId}'}',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
