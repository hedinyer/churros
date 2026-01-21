import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pedido_cliente.dart';
import '../../models/producto.dart';
import '../../services/supabase_service.dart';

class ClientOrdersListPage extends StatefulWidget {
  const ClientOrdersListPage({super.key});

  @override
  State<ClientOrdersListPage> createState() => _ClientOrdersListPageState();
}

class _ClientOrdersListPageState extends State<ClientOrdersListPage> {
  List<PedidoCliente> _pedidos = [];
  Map<int, bool> _esRecurrente = {}; // pedidoId -> esRecurrente
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

      // Cargar pedidos de clientes y pedidos recurrentes
      final pedidos = await SupabaseService.getPedidosClientesRecientes(
        limit: 100,
      );
      final pedidosRecurrentes =
          await SupabaseService.getPedidosRecurrentesRecientes(limit: 100);

      // Crear mapa para identificar pedidos recurrentes
      final esRecurrenteMap = <int, bool>{};
      for (final pedido in pedidosRecurrentes) {
        esRecurrenteMap[pedido.id] = true;
      }

      // Combinar ambos tipos de pedidos y ordenar por fecha
      final todosLosPedidos = [...pedidos, ...pedidosRecurrentes];
      todosLosPedidos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _productos = productos;
        _pedidos = todosLosPedidos;
        _esRecurrente = esRecurrenteMap;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando pedidos de clientes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PedidoCliente> _getPedidosFiltrados() {
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
        return const Color(0xFFEC6D13);
      case 'enviado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Icons.pending;
      case 'enviado':
        return Icons.local_shipping;
      case 'entregado':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  bool _puedeDespachar(String estado) {
    return estado == 'pendiente';
  }

  Future<void> _despacharPedido(PedidoCliente pedido) async {
    // Confirmar antes de despachar
    final confirmado = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('CONFIRMAR DESPACHO'),
            content: Text(
              '¿DESEAS DESPACHAR EL PEDIDO ${pedido.numeroPedido ?? '#${pedido.id}'}?\n\n'
              'ESTO CAMBIARÁ EL ESTADO A "ENVIADO" Y DESCONTARÁ EL INVENTARIO.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('CONFIRMAR'),
              ),
            ],
          ),
    );

    if (confirmado != true) return;

    // Mostrar indicador de carga
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      // Determinar si es un pedido recurrente
      final esRecurrente = _esRecurrente[pedido.id] == true;

      print('Despachando pedido ${pedido.id} - Es recurrente: $esRecurrente');

      // Actualizar estado a "enviado" según el tipo de pedido
      final resultado =
          esRecurrente
              ? await SupabaseService.actualizarEstadoPedidoRecurrente(
                pedidoId: pedido.id,
                nuevoEstado: 'enviado',
              )
              : await SupabaseService.actualizarEstadoPedidoCliente(
                pedidoId: pedido.id,
                nuevoEstado: 'enviado',
              );

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.pop(context);
      }

      if (resultado['exito'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PEDIDO DESPACHADO EXITOSAMENTE'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
        // Recargar datos
        await _loadData();
      } else {
        if (mounted) {
          final mensaje =
              (resultado['mensaje'] as String?)?.toUpperCase() ?? 'ERROR AL DESPACHAR EL PEDIDO';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar indicador de carga si hay error
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ERROR: ${e.toString().toUpperCase()}'), backgroundColor: Colors.red),
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

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
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
                      'Pedidos Clientes',
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
                      onTap: () => setState(() => _filtroEstado = 'pendiente'),
                      color: const Color(0xFFEC6D13),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      isDark: isDark,
                      label: 'Enviados',
                      isSelected: _filtroEstado == 'enviado',
                      onTap: () => setState(() => _filtroEstado = 'enviado'),
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      isDark: isDark,
                      label: 'Entregados',
                      isSelected: _filtroEstado == 'entregado',
                      onTap: () => setState(() => _filtroEstado = 'entregado'),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ),

            // Lista de pedidos
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (pedidosFiltrados.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                isSmallScreen: isSmallScreen,
                              );
                            },
                          )),
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
    required PedidoCliente pedido,
    required Color primaryColor,
    required bool isSmallScreen,
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
                    height: 80,
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pedido.numeroPedido ??
                                            'Pedido #${pedido.id}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1B130D),
                                        ),
                                      ),
                                    ),
                                    if (_esRecurrente[pedido.id] == true)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.withOpacity(
                                            isDark ? 0.2 : 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.teal.withOpacity(
                                              isDark ? 0.3 : 0.2,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.repeat,
                                              size: 12,
                                              color: Colors.teal,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Recurrente',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.teal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 14,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      pedido.clienteNombre,
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
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        pedido.direccionEntrega,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              isDark
                                                  ? const Color(0xFFA8A29E)
                                                  : const Color(0xFF78716C),
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
                      // Información responsive - se adapta a pantallas pequeñas
                      isSmallScreen
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  Expanded(
                                    child: Text(
                                      '$timeAgo • $fechaHora',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? const Color(0xFFA8A29E)
                                                : const Color(0xFF78716C),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
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
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color:
                                        isDark
                                            ? const Color(0xFFA8A29E)
                                            : const Color(0xFF78716C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatCurrency(pedido.total),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF1B130D),
                                    ),
                                  ),
                                ],
                              ),
                              if (pedido.domicilio != null && pedido.domicilio! > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.delivery_dining,
                                      size: 14,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Domicilio: ${_formatCurrency(pedido.domicilio!)}',
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
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.payments,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Valor Total: ${_formatCurrency(pedido.total + (pedido.domicilio ?? 0))}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                          : Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
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
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    size: 14,
                                    color:
                                        isDark
                                            ? const Color(0xFFA8A29E)
                                            : const Color(0xFF78716C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatCurrency(pedido.total),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF1B130D),
                                    ),
                                  ),
                                ],
                              ),
                              if (pedido.domicilio != null && pedido.domicilio! > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delivery_dining,
                                      size: 14,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Domicilio: ${_formatCurrency(pedido.domicilio!)}',
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.payments,
                                    size: 14,
                                    color: primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Total: ${_formatCurrency(pedido.total + (pedido.domicilio ?? 0))}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
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
                    final producto =
                        detalle.producto ??
                        _getProductoById(detalle.productoId);
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
                              '${detalle.cantidad} ${producto?.unidadMedida ?? 'unidad'} ${producto?.nombre ?? 'Producto #${detalle.productoId}'} - ${_formatCurrency(detalle.precioTotal)}',
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
