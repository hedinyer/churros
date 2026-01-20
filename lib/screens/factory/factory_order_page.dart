import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../models/producto.dart';
import '../../models/pedido_fabrica.dart';
import '../../services/supabase_service.dart';

class FactoryOrderPage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const FactoryOrderPage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<FactoryOrderPage> createState() => _FactoryOrderPageState();
}

class _FactoryOrderPageState extends State<FactoryOrderPage> {
  List<Producto> _productos = [];
  Map<int, int> _cantidades = {}; // productoId -> cantidad
  Map<int, TextEditingController> _cantidadControllers = {}; // productoId -> controller
  // ignore: unused_field
  Map<int, int> _inventario =
      {}; // productoId -> stock actual (cargado para uso futuro)
  List<PedidoFabrica> _pedidosRecientes = [];
  bool _isLoading = true;
  bool _isOnline = true;
  bool _isEnviando = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkConnection();
  }

  @override
  void dispose() {
    // Dispose de todos los controllers
    for (var controller in _cantidadControllers.values) {
      controller.dispose();
    }
    _cantidadControllers.clear();
    super.dispose();
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
      // Cargar todos los productos activos de la tabla productos
      final productos = await SupabaseService.getProductosActivos();

      // Filtrar productos: 
      // - categoria_id = 1 o 4: nombre contiene "crudo" y unidad_medida = "bandeja"
      // - categoria_id = 5: sin restricciones adicionales
      final productosFiltrados = productos.where((producto) {
        final categoriaId = producto.categoria?.id;
        
        // Si es categoría 5, se puede pedir sin restricciones
        if (categoriaId == 5) {
          return true;
        }
        
        // Para categorías 1 y 4, verificar condiciones adicionales
        if (categoriaId == 1 || categoriaId == 4) {
          final nombre = producto.nombre.toLowerCase();
          final unidadMedida = producto.unidadMedida.toLowerCase();
          
          // Verificar que el nombre contenga "crudo"
          final contieneCrudo = nombre.contains('crudo');
          
          // Verificar que la unidad de medida sea "bandeja"
          final esBandeja = unidadMedida == 'bandeja';
          
          return contieneCrudo && esBandeja;
        }
        
        // Otras categorías no se pueden pedir
        return false;
      }).toList();

      // Cargar inventario actual
      final inventario = await SupabaseService.getInventarioActual(
        widget.sucursal.id,
      );

      // Cargar pedidos recientes
      final pedidos = await SupabaseService.getPedidosFabricaRecientes(
        widget.sucursal.id,
      );

      setState(() {
        _productos = productosFiltrados;
        _inventario = inventario;
        _pedidosRecientes = pedidos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _incrementProduct(int productoId) {
    setState(() {
      _cantidades[productoId] = (_cantidades[productoId] ?? 0) + 1;
      _updateController(productoId);
    });
    // Note: _inventario is loaded and available for future stock validation
  }

  void _decrementProduct(int productoId) {
    setState(() {
      final current = _cantidades[productoId] ?? 0;
      if (current > 0) {
        _cantidades[productoId] = current - 1;
        _updateController(productoId);
      }
    });
  }

  void _updateController(int productoId) {
    final controller = _cantidadControllers[productoId];
    if (controller != null) {
      final cantidad = _cantidades[productoId] ?? 0;
      if (controller.text != cantidad.toString()) {
        controller.text = cantidad.toString();
      }
    }
  }

  void _onCantidadChanged(int productoId, String value) {
    if (value.isEmpty) {
      setState(() {
        _cantidades[productoId] = 0;
      });
      return;
    }

    final cantidad = int.tryParse(value) ?? 0;
    if (cantidad >= 0) {
      setState(() {
        _cantidades[productoId] = cantidad;
      });
    }
  }

  TextEditingController _getOrCreateController(int productoId) {
    if (!_cantidadControllers.containsKey(productoId)) {
      final cantidad = _cantidades[productoId] ?? 0;
      _cantidadControllers[productoId] = TextEditingController(
        text: cantidad.toString(),
      );
    }
    return _cantidadControllers[productoId]!;
  }

  int _getTotalItems() {
    return _cantidades.values.fold(0, (sum, cantidad) => sum + cantidad);
  }

  Future<void> _enviarPedido() async {
    // Filtrar solo productos con cantidad > 0
    final productosConCantidad =
        _cantidades.entries.where((entry) => entry.value > 0).toList();

    if (productosConCantidad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto al pedido')),
      );
      return;
    }

    setState(() {
      _isEnviando = true;
    });

    try {
      final pedido = await SupabaseService.crearPedidoFabrica(
        sucursalId: widget.sucursal.id,
        usuarioId: widget.currentUser.id,
        productos: Map.fromEntries(productosConCantidad),
      );

      if (pedido != null) {
        // Limpiar cantidades
        setState(() {
          _cantidades.clear();
          _isEnviando = false;
        });

        // Recargar pedidos recientes
        await _loadData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isOnline
                  ? 'Pedido enviado exitosamente'
                  : 'Pedido guardado localmente. Se enviará cuando haya conexión',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _isEnviando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al crear el pedido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isEnviando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getEstadoBadge(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return 'Pendiente';
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
      case 'pendiente':
        return const Color(0xFFEC6D13); // primary orange
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
      case 'pendiente':
        return Icons.sync_problem;
      case 'enviado':
        return Icons.send;
      case 'entregado':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return DateFormat('d MMM', 'es').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

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
                      'Pedido a Fábrica',
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
                        if (!_isOnline)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 8,
                                    height: 8,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFEC6D13),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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

            // Main Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 20,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Order Input Section
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Nuevo Pedido',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF1B130D),
                                  ),
                                ),
                                Text(
                                  'Stock Actual',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark
                                            ? const Color(0xFFA8A29E)
                                            : const Color(0xFF78716C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Product Cards
                            ..._productos.map((producto) {
                              // Note: _inventario is available for future stock display/validation

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF2D231B)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.black.withOpacity(0.05),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            producto.nombre,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1B130D),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Unidad: ${producto.unidadMedida}',
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
                                    ),
                                    // Quantity Controls
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? Colors.white.withOpacity(0.05)
                                                : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          // Decrement Button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap:
                                                  () => _decrementProduct(
                                                    producto.id,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color:
                                                      isDark
                                                          ? Colors.white
                                                              .withOpacity(0.1)
                                                          : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        isDark
                                                            ? Colors.transparent
                                                            : const Color(
                                                              0xFFE2E8F0,
                                                            ),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.remove,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Quantity Input
                                          SizedBox(
                                            width: 60,
                                            child: TextField(
                                              controller: _getOrCreateController(producto.id),
                                              textAlign: TextAlign.center,
                                              keyboardType: TextInputType.number,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1B130D,
                                                        ),
                                              ),
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              onChanged: (value) => _onCantidadChanged(producto.id, value),
                                            ),
                                          ),
                                          // Increment Button
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap:
                                                  () => _incrementProduct(
                                                    producto.id,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 32),

                            // Order History Section
                            Text(
                              'Pedidos Recientes',
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

                            if (_pedidosRecientes.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'No hay pedidos recientes',
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? const Color(0xFFA8A29E)
                                            : const Color(0xFF78716C),
                                  ),
                                ),
                              )
                            else
                              ..._pedidosRecientes.map((pedido) {
                                final estado = pedido.estado;
                                final estadoBadge = _getEstadoBadge(estado);
                                final estadoColor = _getEstadoColor(estado);
                                final estadoIcon = _getEstadoIcon(estado);
                                final timeAgo = _formatTimeAgo(
                                  pedido.createdAt,
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? const Color(0xFF2D231B)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.black.withOpacity(0.05),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Borde izquierdo de color para pedidos pendientes
                                      if (estado == 'pendiente')
                                        Container(
                                          width: 4,
                                          color: primaryColor,
                                        ),
                                      // Contenido principal
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          pedido.numeroPedido ??
                                                              'Pedido #${pedido.id}',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                isDark
                                                                    ? Colors
                                                                        .white
                                                                    : const Color(
                                                                      0xFF1B130D,
                                                                    ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          timeAgo,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                isDark
                                                                    ? const Color(
                                                                      0xFFA8A29E,
                                                                    )
                                                                    : const Color(
                                                                      0xFF78716C,
                                                                    ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: estadoColor
                                                          .withOpacity(
                                                            isDark ? 0.2 : 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          estadoIcon,
                                                          size: 14,
                                                          color: estadoColor,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          estadoBadge,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: estadoColor,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (pedido.detalles != null &&
                                                  pedido.detalles!.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: Text(
                                                    pedido.detalles!
                                                        .map((d) {
                                                          final producto = _productos.firstWhere(
                                                            (p) =>
                                                                p.id ==
                                                                d.productoId,
                                                            orElse:
                                                                () => Producto(
                                                                  id:
                                                                      d.productoId,
                                                                  nombre:
                                                                      'Producto #${d.productoId}',
                                                                  precio: 0,
                                                                  unidadMedida:
                                                                      'unidad',
                                                                  activo: true,
                                                                  createdAt:
                                                                      DateTime.now(),
                                                                  updatedAt:
                                                                      DateTime.now(),
                                                                ),
                                                          );
                                                          return '${d.cantidad} ${producto.unidadMedida} ${producto.nombre}';
                                                        })
                                                        .join(', '),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          isDark
                                                              ? const Color(
                                                                0xFFA8A29E,
                                                              )
                                                              : const Color(
                                                                0xFF78716C,
                                                              ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),

                            const SizedBox(height: 100), // Space for footer
                          ],
                        ),
                      ),
            ),

            // Sticky Footer
            Container(
              padding: EdgeInsets.only(
                left: isSmallScreen ? 16 : 20,
                right: isSmallScreen ? 16 : 20,
                top: 16,
                bottom: 16 + mediaQuery.padding.bottom,
              ),
              decoration: BoxDecoration(
                color: (isDark
                        ? const Color(0xFF221810)
                        : const Color(0xFFF8F7F6))
                    .withOpacity(0.95),
                border: Border(
                  top: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total items: ${_getTotalItems()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFFA8A29E)
                                  : const Color(0xFF78716C),
                        ),
                      ),
                      if (!_isOnline)
                        Text(
                          'Modo Offline Activo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: primaryColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isEnviando ? null : _enviarPedido,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 8,
                        shadowColor: primaryColor.withOpacity(0.3),
                      ),
                      child:
                          _isEnviando
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Enviar Pedido',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward),
                                ],
                              ),
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
}
