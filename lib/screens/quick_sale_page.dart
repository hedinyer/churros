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
  Map<int, int> _inventario = {}; // productoId -> cantidad disponible
  bool _isLoading = true;
  final bool _isOnline = true;
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
        _inventario = inventario;
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
    final stockDisponible = _inventario[productoId] ?? 0;
    final cantidadActual = _cart[productoId] ?? 0;
    
    // Validar que no se exceda el stock disponible
    if (cantidadActual < stockDisponible) {
      setState(() {
        _cart[productoId] = cantidadActual + 1;
      });
    }
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
        final dialogMediaQuery = MediaQuery.of(context);
        // Deshabilitar escalado de texto del sistema - usar siempre 1.0
        final dialogTextScale = 1.0;
        final dialogScreenWidth = dialogMediaQuery.size.width;
        final dialogIsSmallScreen = dialogScreenWidth < 600;
        final dialogPadding = (dialogIsSmallScreen ? 16.0 : 24.0) * dialogTextScale.clamp(0.9, 1.1);
        final dialogTitleSize = (22.0 * dialogTextScale).clamp(18.0, 28.0);
        final dialogBodySize = (16.0 * dialogTextScale).clamp(14.0, 20.0);
        final dialogSmallSize = (14.0 * dialogTextScale).clamp(12.0, 18.0);
        final dialogLargeSize = (36.0 * dialogTextScale).clamp(28.0, 44.0);
        final dialogSpacing = (24.0 * dialogTextScale).clamp(16.0, 32.0);

        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: dialogIsSmallScreen ? dialogScreenWidth * 0.9 : 500,
                  maxHeight: dialogMediaQuery.size.height * 0.9,
                ),
                padding: EdgeInsets.all(dialogPadding),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2018) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: (48 * dialogTextScale).clamp(40.0, 56.0),
                            height: (48 * dialogTextScale).clamp(40.0, 56.0),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.payments,
                              color: primaryColor,
                              size: (28 * dialogTextScale).clamp(24.0, 32.0),
                            ),
                          ),
                          SizedBox(width: (16 * dialogTextScale).clamp(12.0, 20.0)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Confirmar Venta',
                                    style: TextStyle(
                                      fontSize: dialogTitleSize,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF1B130D),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(height: (4 * dialogTextScale).clamp(2.0, 6.0)),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Revisa los detalles antes de continuar',
                                    style: TextStyle(
                                      fontSize: dialogSmallSize,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: dialogSpacing),

                      // Total destacado
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all((20 * dialogTextScale).clamp(16.0, 24.0)),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Total a Cobrar',
                                style: TextStyle(
                                  fontSize: dialogSmallSize,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? const Color(0xFFA8A29E)
                                          : const Color(0xFF78716C),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: (8 * dialogTextScale).clamp(4.0, 12.0)),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '\$${_totalAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: dialogLargeSize,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: -1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: dialogSpacing),

                      // Selector de método de pago
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Método de Pago',
                          style: TextStyle(
                            fontSize: dialogBodySize,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1B130D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: (12 * dialogTextScale).clamp(8.0, 16.0)),
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
                              padding: EdgeInsets.symmetric(
                                vertical: (18 * dialogTextScale).clamp(14.0, 22.0),
                                horizontal: (16 * dialogTextScale).clamp(12.0, 20.0),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.money,
                                    color:
                                        metodoPagoSeleccionado == 'efectivo'
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFA8A29E)
                                                : const Color(0xFF78716C)),
                                    size: (24 * dialogTextScale).clamp(20.0, 28.0),
                                  ),
                                  SizedBox(width: (12 * dialogTextScale).clamp(8.0, 16.0)),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Efectivo',
                                        style: TextStyle(
                                          fontSize: dialogBodySize,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              metodoPagoSeleccionado == 'efectivo'
                                                  ? Colors.white
                                                  : (isDark
                                                      ? const Color(0xFFA8A29E)
                                                      : const Color(0xFF78716C)),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: (12 * dialogTextScale).clamp(8.0, 16.0)),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                metodoPagoSeleccionado = 'transferencia';
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: (18 * dialogTextScale).clamp(14.0, 22.0),
                                horizontal: (16 * dialogTextScale).clamp(12.0, 20.0),
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_balance,
                                    color:
                                        metodoPagoSeleccionado == 'transferencia'
                                            ? Colors.white
                                            : (isDark
                                                ? const Color(0xFFA8A29E)
                                                : const Color(0xFF78716C)),
                                    size: (24 * dialogTextScale).clamp(20.0, 28.0),
                                  ),
                                  SizedBox(width: (12 * dialogTextScale).clamp(8.0, 16.0)),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Transferencia',
                                        style: TextStyle(
                                          fontSize: dialogBodySize,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              metodoPagoSeleccionado ==
                                                      'transferencia'
                                                  ? Colors.white
                                                  : (isDark
                                                      ? const Color(0xFFA8A29E)
                                                      : const Color(0xFF78716C)),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: dialogSpacing),

                      // Resumen de productos
                      Container(
                        padding: EdgeInsets.all((16 * dialogTextScale).clamp(12.0, 20.0)),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF1C1917)
                                  : const Color(0xFFF8F7F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Resumen',
                                style: TextStyle(
                                  fontSize: dialogSmallSize,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? const Color(0xFFA8A29E)
                                          : const Color(0xFF78716C),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: (8 * dialogTextScale).clamp(4.0, 12.0)),
                            ..._cart.entries.map((entry) {
                              final producto = _productos.firstWhere(
                                (p) => p.id == entry.key,
                              );
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: (8 * dialogTextScale).clamp(4.0, 12.0),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${producto.nombre} x${entry.value}',
                                          style: TextStyle(
                                            fontSize: dialogSmallSize,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: (8 * dialogTextScale).clamp(4.0, 12.0)),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '\$${(producto.precio * entry.value).toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: dialogSmallSize,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : const Color(0xFF1B130D),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      SizedBox(height: dialogSpacing),

                      // Botones de acción
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: (16 * dialogTextScale).clamp(12.0, 20.0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Cancelar',
                                  style: TextStyle(
                                    fontSize: dialogBodySize,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark
                                            ? const Color(0xFFA8A29E)
                                            : const Color(0xFF78716C),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: (12 * dialogTextScale).clamp(8.0, 16.0)),
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
                                padding: EdgeInsets.symmetric(
                                  vertical: (16 * dialogTextScale).clamp(12.0, 20.0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: (20 * dialogTextScale).clamp(18.0, 24.0),
                                    ),
                                    SizedBox(width: (8 * dialogTextScale).clamp(4.0, 12.0)),
                                    Text(
                                      'Confirmar',
                                      style: TextStyle(
                                        fontSize: dialogBodySize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
          _inventario = inventario;
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
    // Deshabilitar escalado de texto del sistema - usar siempre 1.0
    final textScaleFactor = 1.0;
    final isSmallScreen = screenWidth < 600;
    final isVerySmallScreen = screenWidth < 400;
    
    // Tamaños adaptativos basados en pantalla (sin escalado de texto)
    final baseFontSize = isSmallScreen ? 16.0 : 18.0;
    final titleFontSize = (baseFontSize * 1.25 * textScaleFactor).clamp(16.0, 24.0);
    final bodyFontSize = (baseFontSize * textScaleFactor).clamp(14.0, 20.0);
    final smallFontSize = (baseFontSize * 0.875 * textScaleFactor).clamp(12.0, 16.0);
    final largeFontSize = (baseFontSize * 1.5 * textScaleFactor).clamp(20.0, 32.0);
    final extraLargeFontSize = (baseFontSize * 2.0 * textScaleFactor).clamp(24.0, 40.0);
    
    // Espaciado adaptativo
    final paddingHorizontal = isSmallScreen ? 16.0 : 20.0;
    final paddingVertical = (12.0 * textScaleFactor).clamp(8.0, 16.0);
    final spacingSmall = (8.0 * textScaleFactor).clamp(4.0, 12.0);
    final spacingMedium = (16.0 * textScaleFactor).clamp(12.0, 20.0);

    // Deshabilitar escalado de texto del sistema
    final mediaQueryWithoutTextScale = mediaQuery.copyWith(textScaleFactor: 1.0);

    return MediaQuery(
      data: mediaQueryWithoutTextScale,
      child: Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: paddingHorizontal,
                vertical: paddingVertical,
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
                mainAxisSize: MainAxisSize.min,
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
                          size: (24 * textScaleFactor).clamp(20.0, 28.0),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          minimumSize: Size(
                            (48 * textScaleFactor).clamp(40.0, 56.0),
                            (48 * textScaleFactor).clamp(40.0, 56.0),
                          ),
                          padding: EdgeInsets.all(
                            (8 * textScaleFactor).clamp(4.0, 12.0),
                          ),
                        ),
                      ),
                      SizedBox(width: spacingSmall),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.sucursal.nombre,
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(height: spacingSmall / 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Cajero: ${widget.currentUser.userId}',
                                style: TextStyle(
                                  fontSize: smallFontSize,
                                  color:
                                      isDark
                                          ? const Color(0xFFA8A29E)
                                          : const Color(0xFF78716C),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: spacingSmall),
                      // Online/Offline Status
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (12 * textScaleFactor).clamp(8.0, 16.0),
                            vertical: (4 * textScaleFactor).clamp(4.0, 8.0),
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
                                size: (18 * textScaleFactor).clamp(14.0, 22.0),
                                color:
                                    _isOnline
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                              ),
                              SizedBox(width: spacingSmall / 2),
                              Text(
                                _isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontSize: smallFontSize,
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
                      ),
                    ],
                  ),
                  SizedBox(height: spacingSmall),
                  // Inventario Total
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: (12 * textScaleFactor).clamp(8.0, 16.0),
                      vertical: (8 * textScaleFactor).clamp(6.0, 12.0),
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
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: primaryColor,
                                size: (20 * textScaleFactor).clamp(16.0, 24.0),
                              ),
                              SizedBox(width: spacingSmall / 2),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Inventario Total',
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          isDark
                                              ? const Color(0xFFD6D3D1)
                                              : const Color(0xFF44403C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: spacingSmall),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$_totalInventario unid.',
                            style: TextStyle(
                              fontSize: bodyFontSize,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: paddingHorizontal,
                  vertical: spacingMedium,
                ),
                child: AnimatedOpacity(
                  opacity: _isLoading ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Productos',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark
                                    ? Colors.white
                                    : const Color(0xFF1B130D),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: spacingMedium),
                      if (_productos.isEmpty && _isLoading)
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                primaryColor,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._productos.map<Widget>((producto) {
                              final quantity = _cart[producto.id] ?? 0;
                              final categoria = producto.categoria;
                              final stockDisponible = _inventario[producto.id] ?? 0;
                              final iconSize = (isVerySmallScreen ? 60.0 : 80.0) * textScaleFactor.clamp(0.9, 1.1);
                              final buttonSize = (40.0 * textScaleFactor).clamp(36.0, 48.0);

                              return Container(
                                margin: EdgeInsets.only(bottom: spacingMedium),
                                padding: EdgeInsets.all(
                                  (12 * textScaleFactor).clamp(8.0, 16.0),
                                ),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Image
                                        Container(
                                          width: iconSize,
                                          height: iconSize,
                                          decoration: BoxDecoration(
                                            color: primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.bakery_dining,
                                            color: primaryColor,
                                            size: (iconSize * 0.5).clamp(30.0, 50.0),
                                          ),
                                        ),
                                        SizedBox(width: spacingMedium),
                                        // Product Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  producto.nombre,
                                                  style: TextStyle(
                                                    fontSize: titleFontSize,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                            : const Color(0xFF1B130D),
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(height: spacingSmall / 2),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        categoria?.nombre ??
                                                            'Sin categoría',
                                                        style: TextStyle(
                                                          fontSize: smallFontSize,
                                                          color:
                                                              isDark
                                                                  ? const Color(0xFFA8A29E)
                                                                  : const Color(0xFF78716C),
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(width: spacingSmall),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: (6 * textScaleFactor).clamp(4.0, 8.0),
                                                      vertical: (2 * textScaleFactor).clamp(2.0, 4.0),
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: stockDisponible > 0
                                                          ? const Color(0xFF10B981).withOpacity(0.1)
                                                          : Colors.red.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        'Stock: $stockDisponible',
                                                        style: TextStyle(
                                                          fontSize: smallFontSize * 0.9,
                                                          fontWeight: FontWeight.w600,
                                                          color: stockDisponible > 0
                                                              ? const Color(0xFF10B981)
                                                              : Colors.red,
                                                        ),
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: spacingSmall / 2),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  '\$${producto.precio.toStringAsFixed(0)}',
                                                  style: TextStyle(
                                                    fontSize: largeFontSize,
                                                    fontWeight: FontWeight.bold,
                                                    color: primaryColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Quantity Controls - Esquina inferior derecha
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        margin: EdgeInsets.only(top: spacingSmall),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: (4 * textScaleFactor).clamp(2.0, 6.0),
                                          vertical: (4 * textScaleFactor).clamp(2.0, 6.0),
                                        ),
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
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Decrement Button
                                            SizedBox(
                                              width: buttonSize,
                                              height: buttonSize,
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
                                                  minimumSize: Size(
                                                    buttonSize,
                                                    buttonSize,
                                                  ),
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
                                                child: Icon(
                                                  Icons.remove,
                                                  size: (20 * textScaleFactor).clamp(18.0, 24.0),
                                                ),
                                              ),
                                            ),
                                            // Quantity Display
                                            Container(
                                              width: (40 * textScaleFactor).clamp(36.0, 48.0),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: (8 * textScaleFactor).clamp(4.0, 12.0),
                                              ),
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    quantity.toString(),
                                                    style: TextStyle(
                                                      fontSize: bodyFontSize * 1.1,
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
                                            ),
                                            // Increment Button
                                            SizedBox(
                                              width: buttonSize,
                                              height: buttonSize,
                                              child: ElevatedButton(
                                                onPressed: (stockDisponible > 0 && quantity < stockDisponible)
                                                    ? () => _incrementProduct(
                                                      producto.id,
                                                    )
                                                    : null,
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
                                                  minimumSize: Size(
                                                    buttonSize,
                                                    buttonSize,
                                                  ),
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
                                                child: Icon(
                                                  Icons.add,
                                                  size: (20 * textScaleFactor).clamp(18.0, 24.0),
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
                            }),
                            // Bottom spacing for fixed footer
                            SizedBox(height: (100 * textScaleFactor).clamp(80.0, 120.0)),
                          ],
                        ),
                      ),
                ),
            ),
          ],
        ),
      ),
      // Fixed Footer
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: paddingHorizontal,
          right: paddingHorizontal,
          top: paddingVertical,
          bottom: mediaQuery.padding.bottom + paddingVertical,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Total a cobrar',
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? const Color(0xFFA8A29E)
                                : const Color(0xFF78716C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(width: spacingSmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '\$${_totalAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: extraLargeFontSize,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                      letterSpacing: -1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacingMedium),
            SizedBox(
              width: double.infinity,
              height: (56 * textScaleFactor).clamp(48.0, 64.0),
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.payments,
                        size: (28 * textScaleFactor).clamp(24.0, 32.0),
                      ),
                      SizedBox(width: spacingSmall),
                      Text(
                        'REGISTRAR VENTA',
                        style: TextStyle(
                          fontSize: bodyFontSize * 1.1,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
