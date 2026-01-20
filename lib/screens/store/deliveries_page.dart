import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pedido_fabrica.dart';
import '../../models/pedido_cliente.dart';
import '../../models/producto.dart';
import '../../services/supabase_service.dart';

class DeliveriesPage extends StatefulWidget {
  const DeliveriesPage({super.key});

  @override
  State<DeliveriesPage> createState() => _DeliveriesPageState();
}

class _DeliveriesPageState extends State<DeliveriesPage> {
  List<PedidoFabrica> _pedidosFabrica = [];
  List<PedidoCliente> _pedidosClientes = [];
  List<Producto> _productos = [];
  bool _isLoading = true;
  String _busqueda = '';

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
      // Cargar productos
      final productos = await SupabaseService.getProductosActivos();

      // Cargar pedidos de fábrica en estado "enviado"
      final todosPedidosFabrica = await SupabaseService.getPedidosFabricaParaDespacho(limit: 100);
      final pedidosFabricaEnviados = todosPedidosFabrica.where((p) => p.estado == 'enviado').toList();

      // Cargar pedidos de clientes en estado "enviado"
      final todosPedidosClientes = await SupabaseService.getPedidosClientesParaDespacho(limit: 100);
      final pedidosClientesEnviados = todosPedidosClientes.where((p) => p.estado == 'enviado').toList();

      setState(() {
        _productos = productos;
        _pedidosFabrica = pedidosFabricaEnviados;
        _pedidosClientes = pedidosClientesEnviados;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando pedidos para entrega: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<PedidoFabrica> _getPedidosFabricaFiltrados() {
    if (_busqueda.isEmpty) {
      return _pedidosFabrica;
    }
    final busquedaLower = _busqueda.toLowerCase();
    return _pedidosFabrica.where((pedido) {
      final numero = (pedido.numeroPedido ?? 'Pedido #${pedido.id}').toLowerCase();
      final sucursal = (pedido.sucursal?.nombre ?? '').toLowerCase();
      return numero.contains(busquedaLower) || sucursal.contains(busquedaLower);
    }).toList();
  }

  List<PedidoCliente> _getPedidosClientesFiltrados() {
    if (_busqueda.isEmpty) {
      return _pedidosClientes;
    }
    final busquedaLower = _busqueda.toLowerCase();
    return _pedidosClientes.where((pedido) {
      final numero = (pedido.numeroPedido ?? 'Pedido #${pedido.id}').toLowerCase();
      final cliente = pedido.clienteNombre.toLowerCase();
      return numero.contains(busquedaLower) || cliente.contains(busquedaLower);
    }).toList();
  }

  Future<void> _marcarComoEntregado({
    required String tipo,
    required int pedidoId,
  }) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar entrega'),
        content: const Text('¿Confirmar que el pedido fue entregado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      Map<String, dynamic> resultado;
      if (tipo == 'fabrica') {
        resultado = await SupabaseService.actualizarEstadoPedidoFabrica(
          pedidoId: pedidoId,
          nuevoEstado: 'entregado',
        );
      } else {
        resultado = await SupabaseService.actualizarEstadoPedidoCliente(
          pedidoId: pedidoId,
          nuevoEstado: 'entregado',
        );
      }

      if (resultado['exito'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido marcado como entregado'),
            backgroundColor: Colors.green,
          ),
        );
        // Recargar datos
        await _loadData();
      } else if (mounted) {
        final mensaje = resultado['mensaje'] as String? ?? 'Error al marcar el pedido como entregado';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Producto? _getProductoById(int productoId) {
    try {
      return _productos.firstWhere((p) => p.id == productoId);
    } catch (e) {
      return null;
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
    } else {
      return DateFormat('d MMM', 'es').format(dateTime);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    final pedidosFabricaFiltrados = _getPedidosFabricaFiltrados();
    final pedidosClientesFiltrados = _getPedidosClientesFiltrados();
    final totalPedidos = pedidosFabricaFiltrados.length + pedidosClientesFiltrados.length;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
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
                color: (isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6))
                    .withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Domicilios y Entregas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2F2218) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _busqueda = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar por # pedido, sucursal o cliente...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
              ),
            ),

            // Resumen
            if (!_isLoading && totalPedidos > 0)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$totalPedidos pedido${totalPedidos != 1 ? 's' : ''} pendiente${totalPedidos != 1 ? 's' : ''} de entrega',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : totalPedidos == 0
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay pedidos pendientes',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Todos los pedidos han sido entregados',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFFA8A29E)
                                        : const Color(0xFF78716C),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pedidos de Fábrica
                              if (pedidosFabricaFiltrados.isNotEmpty) ...[
                                Text(
                                  'Pedidos de Puntos de Venta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...pedidosFabricaFiltrados.map((pedido) =>
                                    _buildPedidoCard(
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                      tipo: 'fabrica',
                                      pedidoFabrica: pedido,
                                      pedidoCliente: null,
                                    )),
                                const SizedBox(height: 24),
                              ],

                              // Pedidos de Clientes
                              if (pedidosClientesFiltrados.isNotEmpty) ...[
                                Text(
                                  'Pedidos de Clientes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...pedidosClientesFiltrados.map((pedido) =>
                                    _buildPedidoCard(
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                      tipo: 'cliente',
                                      pedidoFabrica: null,
                                      pedidoCliente: pedido,
                                    )),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoCard({
    required bool isDark,
    required Color primaryColor,
    required String tipo,
    PedidoFabrica? pedidoFabrica,
    PedidoCliente? pedidoCliente,
  }) {
    final isFabrica = tipo == 'fabrica';
    final numeroPedido = isFabrica
        ? (pedidoFabrica!.numeroPedido ?? 'Pedido #${pedidoFabrica.id}')
        : (pedidoCliente!.numeroPedido ?? 'Pedido #${pedidoCliente.id}');
    final timeAgo = isFabrica
        ? _formatTimeAgo(pedidoFabrica!.createdAt)
        : _formatTimeAgo(pedidoCliente!.createdAt);
    final detalles = isFabrica
        ? (pedidoFabrica!.detalles ?? [])
        : (pedidoCliente!.detalles ?? []);
    final totalItems = isFabrica
        ? pedidoFabrica!.totalItems
        : pedidoCliente!.totalItems;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2F2218) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Borde superior de color
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del pedido
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ENVIADO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF9A6C4C)
                                      : const Color(0xFF9A6C4C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            numeroPedido,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1B130D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isFabrica ? Icons.storefront : Icons.person,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF9A6C4C)
                                    : const Color(0xFF9A6C4C),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isFabrica
                                      ? (pedidoFabrica!.sucursal?.nombre ?? 'Sucursal')
                                      : pedidoCliente!.clienteNombre,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF9A6C4C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!isFabrica) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: isDark
                                      ? const Color(0xFF9A6C4C)
                                      : const Color(0xFF9A6C4C),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    pedidoCliente!.direccionEntrega,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF9A6C4C)
                                          : const Color(0xFF9A6C4C),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFabrica ? Icons.storefront : Icons.chat,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Detalle de productos
                if (detalles.isNotEmpty) ...[
                  Text(
                    'Detalle de productos:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        ...detalles.map((detalle) {
                          Producto? producto;
                          int cantidad;
                          String? precioTotal;
                          
                          if (isFabrica) {
                            final detalleFabrica = detalle as PedidoFabricaDetalle;
                            producto = _getProductoById(detalleFabrica.productoId);
                            cantidad = detalleFabrica.cantidad;
                          } else {
                            final detalleCliente = detalle as PedidoClienteDetalle;
                            producto = detalleCliente.producto ?? _getProductoById(detalleCliente.productoId);
                            cantidad = detalleCliente.cantidad;
                            precioTotal = _formatCurrency(detalleCliente.precioTotal);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF78716C),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${producto?.nombre ?? 'Producto #${isFabrica ? (detalle as PedidoFabricaDetalle).productoId : (detalle as PedidoClienteDetalle).productoId}'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF1B130D),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            'Cantidad: $cantidad ${producto?.unidadMedida ?? 'unidad'}${cantidad != 1 ? 's' : ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark
                                                  ? const Color(0xFF9A6C4C)
                                                  : const Color(0xFF78716C),
                                            ),
                                          ),
                                          if (precioTotal != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              '• $precioTotal',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? const Color(0xFF9A6C4C)
                                                    : const Color(0xFF78716C),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total: ${detalles.length} producto${detalles.length != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF9A6C4C),
                                  ),
                                ),
                                Text(
                                  '$totalItems items',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF9A6C4C),
                                  ),
                                ),
                              ],
                            ),
                            if (!isFabrica && pedidoCliente != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Total del pedido:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF9A6C4C)
                                          : const Color(0xFF9A6C4C),
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(pedidoCliente.total),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                '$totalItems items',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1B130D),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Botón de marcar como entregado
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _marcarComoEntregado(
                      tipo: tipo,
                      pedidoId: isFabrica ? pedidoFabrica!.id : pedidoCliente!.id,
                    ),
                    icon: const Icon(Icons.check_circle, size: 24),
                    label: const Text(
                      'Marcar como Entregado',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 8,
                    ),
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
