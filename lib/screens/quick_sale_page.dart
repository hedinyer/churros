import 'package:flutter/material.dart';
import '../models/sucursal.dart';
import '../models/user.dart';
import '../models/producto.dart';
import '../services/supabase_service.dart';
import 'dashboard_page.dart';

class QuickSalePage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const QuickSalePage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends State<QuickSalePage> {
  List<Producto> _productos = [];
  final Map<int, int> _cart = {}; // productoId -> cantidad
  bool _isLoading = true;
  bool _isOnline = true;
  int _totalInventario = 0;

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

      // Cargar inventario actual
      final inventario = await SupabaseService.getInventarioActual(
        widget.sucursal.id,
      );
      _totalInventario = inventario.values.fold(
        0,
        (sum, cantidad) => sum + cantidad,
      );

      setState(() {
        _productos = productos;
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
      _cart[productoId] = (_cart[productoId] ?? 0) + 1;
    });
  }

  void _decrementProduct(int productoId) {
    setState(() {
      final currentValue = _cart[productoId] ?? 0;
      if (currentValue > 0) {
        _cart[productoId] = currentValue - 1;
        if (_cart[productoId] == 0) {
          _cart.remove(productoId);
        }
      }
    });
  }

  double get _totalAmount {
    double total = 0.0;
    for (final entry in _cart.entries) {
      final producto = _productos.firstWhere((p) => p.id == entry.key);
      total += (producto.precio * entry.value);
    }
    return total;
  }

  Future<void> _registerSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega productos al carrito'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación con selector de método de pago
    String? metodoPagoSeleccionado = 'efectivo';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = const Color(0xFFEC6D13);

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2018) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.payments,
                            color: primaryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirmar Venta',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Revisa los detalles antes de continuar',
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
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Total destacado
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total a Cobrar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$${_totalAmount.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: -1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Selector de método de pago
                    Text(
                      'Método de Pago',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              metodoPagoSeleccionado = 'efectivo';
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  metodoPagoSeleccionado == 'efectivo'
                                      ? primaryColor
                                      : (isDark
                                          ? const Color(0xFF1C1917)
                                          : const Color(0xFFF8F7F6)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    metodoPagoSeleccionado == 'efectivo'
                                        ? primaryColor
                                        : (isDark
                                            ? const Color(0xFF44403C)
                                            : const Color(0xFFE7E5E4)),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.money,
                                  color:
                                      metodoPagoSeleccionado == 'efectivo'
                                          ? Colors.white
                                          : (isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C)),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Efectivo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        metodoPagoSeleccionado == 'efectivo'
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFA8A29E)
                                                : const Color(0xFF78716C)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              metodoPagoSeleccionado = 'transferencia';
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  metodoPagoSeleccionado == 'transferencia'
                                      ? primaryColor
                                      : (isDark
                                          ? const Color(0xFF1C1917)
                                          : const Color(0xFFF8F7F6)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    metodoPagoSeleccionado == 'transferencia'
                                        ? primaryColor
                                        : (isDark
                                            ? const Color(0xFF44403C)
                                            : const Color(0xFFE7E5E4)),
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance,
                                  color:
                                      metodoPagoSeleccionado == 'transferencia'
                                          ? Colors.white
                                          : (isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C)),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Transferencia',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        metodoPagoSeleccionado ==
                                                'transferencia'
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFA8A29E)
                                                : const Color(0xFF78716C)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Resumen de productos
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF1C1917)
                                : const Color(0xFFF8F7F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color:
                                  isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._cart.entries.map((entry) {
                            final producto = _productos.firstWhere(
                              (p) => p.id == entry.key,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${producto.nombre} x${entry.value}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF1B130D),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '\$${(producto.precio * entry.value).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF1B130D),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botones de acción
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? const Color(0xFFA8A29E)
                                        : const Color(0xFF78716C),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop({
                                'confirmado': true,
                                'metodoPago': metodoPagoSeleccionado,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Confirmar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || result['confirmado'] != true) return;
    final metodoPago = result['metodoPago'] as String? ?? 'efectivo';

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Crear mapa de productos para el método
      final productosMap = {
        for (var producto in _productos) producto.id: producto,
      };

      // Guardar la venta
      final venta = await SupabaseService.guardarVenta(
        sucursalId: widget.sucursal.id,
        usuarioId: widget.currentUser.id,
        productos: _cart,
        productosMap: productosMap,
        metodoPago: metodoPago,
        descuento: 0.0,
        impuesto: 0.0,
      );

      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      if (venta != null) {
        // Limpiar carrito
        setState(() {
          _cart.clear();
        });

        // Actualizar inventario total
        final inventario = await SupabaseService.getInventarioActual(
          widget.sucursal.id,
        );
        setState(() {
          _totalInventario = inventario.values.fold(
            0,
            (sum, cantidad) => sum + cantidad,
          );
        });

        // Mostrar éxito y navegar al dashboard
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Venta registrada exitosamente\nTicket: ${venta.numeroTicket}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Navegar al dashboard después de un breve delay
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => DashboardPage(
                        sucursal: widget.sucursal,
                        currentUser: widget.currentUser,
                      ),
                ),
              );
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al registrar la venta. Intenta nuevamente.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Cerrar loading
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
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
            // Header
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
                            ? const Color(0xFF44403C)
                            : const Color(0xFFE7E5E4),
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.sucursal.nombre,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cajero: ${widget.currentUser.userId}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? const Color(0xFFA8A29E)
                                        : const Color(0xFF78716C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Online/Offline Status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _isOnline
                                  ? const Color(
                                    0xFF10B981,
                                  ).withOpacity(isDark ? 0.2 : 0.1)
                                  : const Color(
                                    0xFFF59E0B,
                                  ).withOpacity(isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                _isOnline
                                    ? const Color(
                                      0xFF10B981,
                                    ).withOpacity(isDark ? 0.3 : 0.2)
                                    : const Color(
                                      0xFFF59E0B,
                                    ).withOpacity(isDark ? 0.3 : 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isOnline ? Icons.wifi : Icons.wifi_off,
                              size: 18,
                              color:
                                  _isOnline
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    _isOnline
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Inventario Total
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2018) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF44403C)
                                : const Color(0xFFE7E5E4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Inventario Total',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? const Color(0xFFD6D3D1)
                                        : const Color(0xFF44403C),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$_totalInventario unid.',
                          style: TextStyle(
                            fontSize: 14,
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

            // Products List
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
                            Text(
                              'Productos',
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
                            ..._productos.map((producto) {
                              final quantity = _cart[producto.id] ?? 0;
                              final categoria = producto.categoria;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF2C2018)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? const Color(0xFF44403C)
                                            : const Color(0xFFE7E5E4),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Product Image
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.bakery_dining,
                                        color: primaryColor,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Product Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            producto.nombre,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1B130D),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            categoria?.nombre ??
                                                'Sin categoría',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  isDark
                                                      ? const Color(0xFFA8A29E)
                                                      : const Color(0xFF78716C),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${producto.precio.toStringAsFixed(0)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Quantity Controls
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color:
                                            isDark
                                                ? const Color(0xFF1C1917)
                                                : const Color(0xFFF8F7F6),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isDark
                                                  ? const Color(0xFF44403C)
                                                  : const Color(0xFFE7E5E4),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          // Decrement Button
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: ElevatedButton(
                                              onPressed:
                                                  quantity > 0
                                                      ? () => _decrementProduct(
                                                        producto.id,
                                                      )
                                                      : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    isDark
                                                        ? const Color(
                                                          0xFF2C2018,
                                                        )
                                                        : Colors.white,
                                                foregroundColor:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF44403C,
                                                        ),
                                                elevation: 1,
                                                shadowColor: Colors.black
                                                    .withOpacity(0.1),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding: EdgeInsets.zero,
                                                disabledBackgroundColor:
                                                    isDark
                                                        ? const Color(
                                                          0xFF1C1917,
                                                        )
                                                        : const Color(
                                                          0xFFE7E5E4,
                                                        ),
                                                disabledForegroundColor:
                                                    isDark
                                                        ? const Color(
                                                          0xFF78716C,
                                                        )
                                                        : const Color(
                                                          0xFFA8A29E,
                                                        ),
                                              ),
                                              child: const Icon(
                                                Icons.remove,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                          // Quantity Display
                                          SizedBox(
                                            width: 40,
                                            height: 32,
                                            child: Center(
                                              child: Text(
                                                quantity.toString(),
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      quantity > 0
                                                          ? (isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF1B130D,
                                                              ))
                                                          : (isDark
                                                              ? const Color(
                                                                0xFF78716C,
                                                              )
                                                              : const Color(
                                                                0xFFA8A29E,
                                                              )),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Increment Button
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: ElevatedButton(
                                              onPressed:
                                                  () => _incrementProduct(
                                                    producto.id,
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primaryColor,
                                                foregroundColor: Colors.white,
                                                elevation: 2,
                                                shadowColor: primaryColor
                                                    .withOpacity(0.3),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: const Icon(
                                                Icons.add,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            // Bottom spacing for fixed footer
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
      // Fixed Footer
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: isSmallScreen ? 16 : 20,
          right: isSmallScreen ? 16 : 20,
          top: 12,
          bottom: mediaQuery.padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2018) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total a cobrar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark
                            ? const Color(0xFFA8A29E)
                            : const Color(0xFF78716C),
                  ),
                ),
                Text(
                  '\$${_totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _registerSale,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payments, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      'REGISTRAR VENTA',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
