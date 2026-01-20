import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pedido_fabrica.dart';
import '../../models/pedido_cliente.dart';
import '../../models/producto.dart';
import '../../services/supabase_service.dart';

class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  List<PedidoFabrica> _pedidosFabrica = [];
  List<PedidoCliente> _pedidosClientes = [];
  List<PedidoCliente> _pedidosRecurrentes = [];
  List<Producto> _productos = [];
  String _filtroEstado = 'todos'; // 'todos', 'enviado', 'entregado'
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

      // Cargar pedidos de fábrica, clientes y recurrentes para despacho
      final pedidosFabrica = await SupabaseService.getPedidosFabricaParaDespacho(
        limit: 100,
      );
      final pedidosClientes = await SupabaseService.getPedidosClientesParaDespacho(
        limit: 100,
      );
      final pedidosRecurrentes = await SupabaseService.getPedidosRecurrentesParaDespacho(
        limit: 100,
      );

      setState(() {
        _productos = productos;
        _pedidosFabrica = pedidosFabrica;
        _pedidosClientes = pedidosClientes;
        _pedidosRecurrentes = pedidosRecurrentes;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando pedidos para despacho: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getPedidosFiltrados() {
    List<dynamic> todosPedidos = [];
    
    // Agregar pedidos de fábrica
    for (var pedido in _pedidosFabrica) {
      if (_filtroEstado == 'todos' || pedido.estado == _filtroEstado) {
        todosPedidos.add({'tipo': 'fabrica', 'pedido': pedido});
      }
    }
    
    // Agregar pedidos de clientes
    for (var pedido in _pedidosClientes) {
      if (_filtroEstado == 'todos' || pedido.estado == _filtroEstado) {
        todosPedidos.add({'tipo': 'cliente', 'pedido': pedido});
      }
    }
    
    // Agregar pedidos recurrentes
    for (var pedido in _pedidosRecurrentes) {
      if (_filtroEstado == 'todos' || pedido.estado == _filtroEstado) {
        todosPedidos.add({'tipo': 'recurrente', 'pedido': pedido});
      }
    }
    
    // Ordenar por fecha de creación (más recientes primero)
    todosPedidos.sort((a, b) {
      final fechaA = a['tipo'] == 'fabrica'
          ? (a['pedido'] as PedidoFabrica).createdAt
          : (a['pedido'] as PedidoCliente).createdAt;
      final fechaB = b['tipo'] == 'fabrica'
          ? (b['pedido'] as PedidoFabrica).createdAt
          : (b['pedido'] as PedidoCliente).createdAt;
      return fechaB.compareTo(fechaA);
    });
    
    return todosPedidos;
  }

  String _getEstadoBadge(String estado) {
    switch (estado.toLowerCase()) {
      case 'enviado':
        return 'Enviado';
      case 'entregado':
        return 'Entregado';
      default:
        return estado;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'enviado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado.toLowerCase()) {
      case 'enviado':
        return Icons.local_shipping;
      case 'entregado':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  Future<void> _marcarComoEntregado(dynamic pedidoData) async {
    final tipo = pedidoData['tipo'] as String;
    final pedido = pedidoData['pedido'];
    
    // Confirmar antes de marcar como entregado
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: const Text(
          '¿Deseas marcar este pedido como entregado?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    Map<String, dynamic> resultado;
    if (tipo == 'fabrica') {
      resultado = await SupabaseService.actualizarEstadoPedidoFabrica(
        pedidoId: (pedido as PedidoFabrica).id,
        nuevoEstado: 'entregado',
      );
    } else if (tipo == 'recurrente') {
      resultado = await SupabaseService.actualizarEstadoPedidoRecurrente(
        pedidoId: (pedido as PedidoCliente).id,
        nuevoEstado: 'entregado',
      );
    } else {
      resultado = await SupabaseService.actualizarEstadoPedidoCliente(
        pedidoId: (pedido as PedidoCliente).id,
        nuevoEstado: 'entregado',
      );
    }

    if (resultado['exito'] == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido marcado como entregado'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      await _loadData();
    } else if (mounted) {
      final mensaje = resultado['mensaje'] as String? ?? 'Error al actualizar el estado';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
        ),
      );
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
                    .withOpacity(0.95),
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
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                  Expanded(
                    child: Text(
                      'Despacho',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                  ),
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isOnline
                              ? Colors.green.withOpacity(isDark ? 0.2 : 0.1)
                              : primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color:
                            _isOnline
                                ? Colors.green.withOpacity(isDark ? 0.3 : 0.2)
                                : primaryColor.withOpacity(isDark ? 0.3 : 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.green : primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isOnline ? Colors.green : primaryColor,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D211A) : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.05),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (pedidosFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 64,
                                color:
                                    isDark
                                        ? const Color(0xFFA8A29E)
                                        : const Color(0xFF78716C),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay pedidos para despacho',
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
                            final pedidoData = pedidosFiltrados[index];
                            return _buildOrderCard(
                              isDark: isDark,
                              pedidoData: pedidoData,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? chipColor.withOpacity(isDark ? 0.2 : 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected
                    ? chipColor.withOpacity(isDark ? 0.3 : 0.2)
                    : (isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color:
                isSelected
                    ? chipColor
                    : (isDark
                        ? const Color(0xFFA8A29E)
                        : const Color(0xFF78716C)),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required bool isDark,
    required Map<String, dynamic> pedidoData,
    required Color primaryColor,
    required bool isSmallScreen,
  }) {
    final tipo = pedidoData['tipo'] as String;
    final isFabrica = tipo == 'fabrica';
    
    if (isFabrica) {
      return _buildPedidoFabricaCard(
        isDark: isDark,
        pedido: pedidoData['pedido'] as PedidoFabrica,
        primaryColor: primaryColor,
        isSmallScreen: isSmallScreen,
      );
    } else {
      final pedido = pedidoData['pedido'] as PedidoCliente;
      final esRecurrente = tipo == 'recurrente';
      return _buildPedidoClienteCard(
        isDark: isDark,
        pedido: pedido,
        primaryColor: primaryColor,
        isSmallScreen: isSmallScreen,
        esRecurrente: esRecurrente,
      );
    }
  }

  Widget _buildPedidoFabricaCard({
    required bool isDark,
    required PedidoFabrica pedido,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
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
                // Badge de tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront, size: 12, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Punto de Venta',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: estadoColor.withOpacity(
                                isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(estadoIcon, size: 14, color: estadoColor),
                                const SizedBox(width: 4),
                                Text(
                                  estadoBadge,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: estadoColor,
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
                                      Icons.storefront,
                                      size: 14,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        pedido.sucursal?.nombre ?? 'Sucursal',
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
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón para marcar como entregado (solo si está enviado)
          if (estado == 'enviado')
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
                  onPressed: () => _marcarComoEntregado({
                    'tipo': 'fabrica',
                    'pedido': pedido,
                  }),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Marcar como Entregado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  Widget _buildPedidoClienteCard({
    required bool isDark,
    required PedidoCliente pedido,
    required Color primaryColor,
    required bool isSmallScreen,
    bool esRecurrente = false,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
        ),
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
                // Badge de tipo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (esRecurrente ? Colors.teal : Colors.green).withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        esRecurrente ? Icons.repeat : Icons.chat,
                        size: 12,
                        color: esRecurrente ? Colors.teal : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        esRecurrente ? 'Recurrente' : 'WhatsApp',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: esRecurrente ? Colors.teal : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
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
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: estadoColor.withOpacity(
                                isDark ? 0.2 : 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(estadoIcon, size: 14, color: estadoColor),
                                const SizedBox(width: 4),
                                Text(
                                  estadoBadge,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: estadoColor,
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
                            Icons.person,
                            size: 14,
                            color:
                                isDark
                                    ? const Color(0xFFA8A29E)
                                    : const Color(0xFF78716C),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              pedido.clienteNombre,
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
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Botón para marcar como entregado (solo si está enviado)
          if (estado == 'enviado')
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
                  onPressed: () => _marcarComoEntregado({
                    'tipo': esRecurrente ? 'recurrente' : 'cliente',
                    'pedido': pedido,
                  }),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Marcar como Entregado'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
                    final producto = detalle.producto ?? _getProductoById(detalle.productoId);
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
