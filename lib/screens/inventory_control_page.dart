import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sucursal.dart';
import '../models/user.dart';
import '../models/producto.dart';
import '../services/supabase_service.dart';

class InventoryControlPage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const InventoryControlPage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<InventoryControlPage> createState() => _InventoryControlPageState();
}

class _InventoryControlPageState extends State<InventoryControlPage> {
  bool _isLoading = true;
  List<Producto> _productos = [];
  Map<int, int> _inventarioInicial = {}; // productoId -> cantidad inicial
  Map<int, int> _ventasHoy = {}; // productoId -> cantidad vendida
  Map<int, int> _inventarioActual = {}; // productoId -> cantidad actual
  Set<int> _productosParaRecargar =
      {}; // productoId -> productos seleccionados para recarga
  Map<int, int> _cantidadesRecarga = {}; // productoId -> cantidad a recargar

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

      // Cargar inventario inicial de la apertura del día
      final inventarioInicial = await SupabaseService.getInventarioInicialHoy(
        widget.sucursal.id,
      );

      // Cargar ventas del día por producto
      final ventasHoy = await SupabaseService.getVentasHoyPorProducto(
        widget.sucursal.id,
      );

      // Cargar inventario actual
      final inventarioActual = await SupabaseService.getInventarioActual(
        widget.sucursal.id,
      );

      setState(() {
        _productos = productos;
        _inventarioInicial = inventarioInicial;
        _ventasHoy = ventasHoy;
        _inventarioActual = inventarioActual;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de inventario: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _getCantidadInicial(int productoId) {
    return _inventarioInicial[productoId] ?? 0;
  }

  int _getCantidadVendida(int productoId) {
    return _ventasHoy[productoId] ?? 0;
  }

  int _getCantidadDisponible(int productoId) {
    return _inventarioActual[productoId] ?? 0;
  }

  String _getEstadoStock(int disponible, int inicial) {
    if (disponible == 0) return 'CRÍTICO';
    if (inicial == 0) return 'Normal';
    final porcentaje = (disponible / inicial) * 100;
    if (porcentaje <= 10) return 'CRÍTICO';
    if (porcentaje <= 30) return 'Poco Stock';
    return 'Normal';
  }

  Color _getColorDisponible(String estado) {
    switch (estado) {
      case 'CRÍTICO':
        return Colors.red;
      case 'Poco Stock':
        return const Color(0xFFEC6D13); // primary color
      default:
        return const Color(0xFF1B130D);
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return 'Hoy, $weekday ${now.day} $month';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header - Sticky with backdrop blur
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
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
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                          size: 24,
                        ),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(4),
                          shape: const CircleBorder(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title
                      Expanded(
                        child: Text(
                          'Inventario del Día',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color:
                                isDark ? Colors.white : const Color(0xFF1B130D),
                          ),
                        ),
                      ),
                      // Empty space
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 24,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 448,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date Section
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Fecha',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF9A6C4C,
                                                        )
                                                        : const Color(
                                                          0xFF9A6C4C,
                                                        ),
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _getFormattedDate(),
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1B130D,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        TextButton(
                                          onPressed: _loadData,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Actualizar',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      margin: const EdgeInsets.only(
                                        top: 16,
                                        bottom: 16,
                                      ),
                                      height: 1,
                                      color:
                                          isDark
                                              ? const Color(0xFF44403C)
                                              : const Color(0xFFE7E5E4),
                                    ),
                                    const SizedBox(height: 16),

                                    // Products List
                                    ..._productos.map((producto) {
                                      final inicial = _getCantidadInicial(
                                        producto.id,
                                      );
                                      final vendido = _getCantidadVendida(
                                        producto.id,
                                      );
                                      final disponible = _getCantidadDisponible(
                                        producto.id,
                                      );
                                      final estado = _getEstadoStock(
                                        disponible,
                                        inicial,
                                      );
                                      final isCritical = estado == 'CRÍTICO';
                                      final isLowStock = estado == 'Poco Stock';

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isDark
                                                  ? const Color(0xFF2C2018)
                                                  : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color:
                                                isCritical
                                                    ? Colors.red.withOpacity(
                                                      isDark ? 0.5 : 0.3,
                                                    )
                                                    : isLowStock
                                                    ? Colors.red.withOpacity(
                                                      isDark ? 0.5 : 0.3,
                                                    )
                                                    : isDark
                                                    ? const Color(0xFF44403C)
                                                    : const Color(0xFFE7E5E4),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 1,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Left border indicator
                                            if (isCritical || isLowStock)
                                              Positioned(
                                                left: 0,
                                                top: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 6,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        isCritical
                                                            ? Colors
                                                                .red
                                                                .shade600
                                                            : Colors
                                                                .red
                                                                .shade500,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            Padding(
                                              padding: EdgeInsets.only(
                                                left:
                                                    (isCritical || isLowStock)
                                                        ? 8
                                                        : 16,
                                                right: 16,
                                                top: 16,
                                                bottom: 16,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Product Info
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Product Image Placeholder
                                                      Container(
                                                        width: 80,
                                                        height: 80,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isDark
                                                                  ? const Color(
                                                                    0xFF44403C,
                                                                  )
                                                                  : const Color(
                                                                    0xFFE7E5E4,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          Icons.image,
                                                          color:
                                                              isDark
                                                                  ? const Color(
                                                                    0xFF78716C,
                                                                  )
                                                                  : const Color(
                                                                    0xFF9A6C4C,
                                                                  ),
                                                          size: 40,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    producto
                                                                        .nombre,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          18,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      height:
                                                                          1.2,
                                                                      color:
                                                                          isDark
                                                                              ? Colors.white
                                                                              : const Color(
                                                                                0xFF1B130D,
                                                                              ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                // Status badge
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        isCritical
                                                                            ? Colors.red.shade600
                                                                            : isLowStock
                                                                            ? isDark
                                                                                ? Colors.red.withOpacity(
                                                                                  0.4,
                                                                                )
                                                                                : Colors.red.withOpacity(
                                                                                  0.1,
                                                                                )
                                                                            : isDark
                                                                            ? const Color(
                                                                              0xFF44403C,
                                                                            )
                                                                            : const Color(
                                                                              0xFFE7E5E4,
                                                                            ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      if (isCritical ||
                                                                          isLowStock)
                                                                        Icon(
                                                                          isCritical
                                                                              ? Icons.error
                                                                              : Icons.warning,
                                                                          size:
                                                                              14,
                                                                          color:
                                                                              isCritical
                                                                                  ? Colors.white
                                                                                  : isLowStock
                                                                                  ? (isDark
                                                                                      ? Colors.red.shade300
                                                                                      : Colors.red.shade700)
                                                                                  : null,
                                                                        ),
                                                                      if (isCritical ||
                                                                          isLowStock)
                                                                        const SizedBox(
                                                                          width:
                                                                              4,
                                                                        ),
                                                                      Text(
                                                                        estado,
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          color:
                                                                              isCritical
                                                                                  ? Colors.white
                                                                                  : isLowStock
                                                                                  ? (isDark
                                                                                      ? Colors.red.shade300
                                                                                      : Colors.red.shade700)
                                                                                  : (isDark
                                                                                      ? const Color(
                                                                                        0xFF78716C,
                                                                                      )
                                                                                      : const Color(
                                                                                        0xFF57534E,
                                                                                      )),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              'Unidad: ${producto.unidadMedida}',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    isDark
                                                                        ? const Color(
                                                                          0xFF9A6C4C,
                                                                        )
                                                                        : const Color(
                                                                          0xFF9A6C4C,
                                                                        ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 16),

                                                  // Stats Grid
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                      left:
                                                          (isCritical ||
                                                                  isLowStock)
                                                              ? 8
                                                              : 0,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          isDark
                                                              ? Colors.black
                                                                  .withOpacity(
                                                                    0.2,
                                                                  )
                                                              : const Color(
                                                                0xFFF8F7F6,
                                                              ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        // Inicial
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Inicial',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  color:
                                                                      isDark
                                                                          ? const Color(
                                                                            0xFF9A6C4C,
                                                                          )
                                                                          : const Color(
                                                                            0xFF9A6C4C,
                                                                          ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                NumberFormat(
                                                                  '#,###',
                                                                ).format(
                                                                  inicial,
                                                                ),
                                                                style: TextStyle(
                                                                  fontSize: 18,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      isDark
                                                                          ? Colors
                                                                              .white
                                                                          : const Color(
                                                                            0xFF1B130D,
                                                                          ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 1,
                                                          height: 40,
                                                          color:
                                                              isDark
                                                                  ? const Color(
                                                                    0xFF44403C,
                                                                  )
                                                                  : const Color(
                                                                    0xFFE7E5E4,
                                                                  ),
                                                        ),
                                                        // Vendido
                                                        Expanded(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Vendido',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color:
                                                                        isDark
                                                                            ? const Color(
                                                                              0xFF9A6C4C,
                                                                            )
                                                                            : const Color(
                                                                              0xFF9A6C4C,
                                                                            ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  NumberFormat(
                                                                    '#,###',
                                                                  ).format(
                                                                    vendido,
                                                                  ),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        18,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        isDark
                                                                            ? Colors.white
                                                                            : const Color(
                                                                              0xFF1B130D,
                                                                            ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 1,
                                                          height: 40,
                                                          color:
                                                              isDark
                                                                  ? const Color(
                                                                    0xFF44403C,
                                                                  )
                                                                  : const Color(
                                                                    0xFFE7E5E4,
                                                                  ),
                                                        ),
                                                        // Disponible
                                                        Expanded(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 8,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Disponible',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        isCritical
                                                                            ? (isDark
                                                                                ? Colors.red.shade400
                                                                                : Colors.red.shade600)
                                                                            : _getColorDisponible(
                                                                              estado,
                                                                            ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Text(
                                                                  NumberFormat(
                                                                    '#,###',
                                                                  ).format(
                                                                    disponible,
                                                                  ),
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        24,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    height: 1.0,
                                                                    color:
                                                                        isCritical
                                                                            ? (isDark
                                                                                ? Colors.red.shade400
                                                                                : Colors.red.shade600)
                                                                            : _getColorDisponible(
                                                                              estado,
                                                                            ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),

                                                  // Recargar Button
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                      left:
                                                          (isCritical ||
                                                                  isLowStock)
                                                              ? 8
                                                              : 0,
                                                    ),
                                                    width: double.infinity,
                                                    child: ElevatedButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          if (_productosParaRecargar
                                                              .contains(
                                                                producto.id,
                                                              )) {
                                                            _productosParaRecargar
                                                                .remove(
                                                                  producto.id,
                                                                );
                                                          } else {
                                                            _productosParaRecargar
                                                                .add(
                                                                  producto.id,
                                                                );
                                                          }
                                                        });
                                                      },
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            _productosParaRecargar
                                                                    .contains(
                                                                      producto
                                                                          .id,
                                                                    )
                                                                ? Colors.black
                                                                : isCritical
                                                                ? primaryColor
                                                                : isLowStock
                                                                ? primaryColor
                                                                    .withOpacity(
                                                                      0.1,
                                                                    )
                                                                : isDark
                                                                ? const Color(
                                                                  0xFF44403C,
                                                                )
                                                                : const Color(
                                                                  0xFFF8F7F6,
                                                                ),
                                                        foregroundColor:
                                                            _productosParaRecargar
                                                                    .contains(
                                                                      producto
                                                                          .id,
                                                                    )
                                                                ? Colors.white
                                                                : isCritical
                                                                ? Colors.white
                                                                : isLowStock
                                                                ? primaryColor
                                                                : isDark
                                                                ? Colors.white
                                                                : const Color(
                                                                  0xFF1B130D,
                                                                ),
                                                        elevation:
                                                            isCritical ? 4 : 0,
                                                        shadowColor:
                                                            isCritical
                                                                ? primaryColor
                                                                    .withOpacity(
                                                                      0.3,
                                                                    )
                                                                : null,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 12,
                                                              horizontal: 16,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            _productosParaRecargar
                                                                    .contains(
                                                                      producto
                                                                          .id,
                                                                    )
                                                                ? Icons.check
                                                                : isCritical
                                                                ? Icons
                                                                    .priority_high
                                                                : isLowStock
                                                                ? Icons
                                                                    .add_circle
                                                                : Icons.add,
                                                            size: 20,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            _productosParaRecargar
                                                                    .contains(
                                                                      producto
                                                                          .id,
                                                                    )
                                                                ? 'Agregado para Recargar'
                                                                : isCritical
                                                                ? 'Recargar Urgente'
                                                                : isLowStock
                                                                ? 'Recargar Stock'
                                                                : 'Recargar',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  isCritical ||
                                                                          isLowStock ||
                                                                          _productosParaRecargar.contains(
                                                                            producto.id,
                                                                          )
                                                                      ? FontWeight
                                                                          .bold
                                                                      : FontWeight
                                                                          .w500,
                                                            ),
                                                          ),
                                                        ],
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
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
            // Floating Action Button - Recargar productos seleccionados
            if (_productosParaRecargar.isNotEmpty)
              Positioned(
                bottom: 24,
                right: 24,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      // Inicializar cantidades de recarga con valores por defecto
                      _cantidadesRecarga.clear();
                      for (final productoId in _productosParaRecargar) {
                        _cantidadesRecarga[productoId] = 1; // valor por defecto
                      }

                      // Mostrar diálogo de confirmación mejorado
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) {
                          final screenHeight =
                              MediaQuery.of(context).size.height;
                          final screenWidth = MediaQuery.of(context).size.width;
                          final maxHeight = (screenHeight * 0.75).toDouble();
                          final maxWidth =
                              (screenWidth > 600 ? 500.0 : screenWidth * 0.9)
                                  .toDouble();

                          return StatefulBuilder(
                            builder:
                                (context, setState) => Dialog(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxHeight: maxHeight,
                                      maxWidth: maxWidth,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Header
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(16),
                                                  topRight: Radius.circular(16),
                                                ),
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.inventory_2,
                                                color: primaryColor,
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Confirmar Recarga',
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade900,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Content - Scrollable
                                        Flexible(
                                          child: SingleChildScrollView(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${_productosParaRecargar.length} producto(s) seleccionado(s)',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                // Lista de productos con cantidades
                                                ..._productosParaRecargar.map((
                                                  productoId,
                                                ) {
                                                  final producto = _productos
                                                      .firstWhere(
                                                        (p) =>
                                                            p.id == productoId,
                                                      );
                                                  final disponible =
                                                      _getCantidadDisponible(
                                                        productoId,
                                                      );
                                                  final cantidadRecarga =
                                                      _cantidadesRecarga[productoId] ??
                                                      1;

                                                  return Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 12,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade50,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      border: Border.all(
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade200,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                producto.nombre,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                  color:
                                                                      Colors
                                                                          .black87,
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical: 4,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    disponible ==
                                                                            0
                                                                        ? Colors
                                                                            .red
                                                                            .shade50
                                                                        : Colors
                                                                            .orange
                                                                            .shade50,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      4,
                                                                    ),
                                                                border: Border.all(
                                                                  color:
                                                                      disponible ==
                                                                              0
                                                                          ? Colors
                                                                              .red
                                                                              .shade200
                                                                          : Colors
                                                                              .orange
                                                                              .shade200,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                'Stock: $disponible',
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color:
                                                                      disponible ==
                                                                              0
                                                                          ? Colors
                                                                              .red
                                                                              .shade700
                                                                          : Colors
                                                                              .orange
                                                                              .shade700,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Text(
                                                              'Cantidad:',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade700,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            SizedBox(
                                                              width: 70,
                                                              child: TextFormField(
                                                                initialValue:
                                                                    cantidadRecarga
                                                                        .toString(),
                                                                keyboardType:
                                                                    TextInputType
                                                                        .number,
                                                                textAlign:
                                                                    TextAlign
                                                                        .center,
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                                decoration: InputDecoration(
                                                                  isDense: true,
                                                                  contentPadding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            10,
                                                                      ),
                                                                  filled: true,
                                                                  fillColor:
                                                                      Colors
                                                                          .white,
                                                                  border: OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                    borderSide: BorderSide(
                                                                      color:
                                                                          Colors
                                                                              .grey
                                                                              .shade300,
                                                                    ),
                                                                  ),
                                                                  enabledBorder: OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                    borderSide: BorderSide(
                                                                      color:
                                                                          Colors
                                                                              .grey
                                                                              .shade300,
                                                                    ),
                                                                  ),
                                                                  focusedBorder: OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                    borderSide:
                                                                        BorderSide(
                                                                          color:
                                                                              primaryColor,
                                                                          width:
                                                                              2,
                                                                        ),
                                                                  ),
                                                                ),
                                                                onChanged: (
                                                                  value,
                                                                ) {
                                                                  final cantidad =
                                                                      int.tryParse(
                                                                        value,
                                                                      ) ??
                                                                      1;
                                                                  if (cantidad >
                                                                      0) {
                                                                    setState(() {
                                                                      _cantidadesRecarga[productoId] =
                                                                          cantidad;
                                                                    });
                                                                  }
                                                                },
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              producto
                                                                  .unidadMedida,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade600,
                                                              ),
                                                            ),
                                                            const Spacer(),
                                                            Text(
                                                              'Final: ${disponible + cantidadRecarga}',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors
                                                                        .grey
                                                                        .shade600,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }).toList(),
                                                const SizedBox(height: 16),
                                                // Resumen
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: primaryColor
                                                          .withOpacity(0.2),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Total unidades:',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade800,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${_cantidadesRecarga.values.fold(0, (sum, cantidad) => sum + cantidad)}',
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: primaryColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Actions
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                const BorderRadius.only(
                                                  bottomLeft: Radius.circular(
                                                    16,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    16,
                                                  ),
                                                ),
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                      false,
                                                    ),
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 12,
                                                      ),
                                                ),
                                                child: Text(
                                                  'Cancelar',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      context,
                                                      true,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.inventory_2,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Confirmar',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          );
                        },
                      );

                      if (confirmed == true) {
                        // Mostrar loading
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder:
                              (context) => const Center(
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Guardando recarga...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                        );

                        try {
                          // Preparar datos de recarga
                          final productosRecarga = <int, int>{};
                          for (final productoId in _productosParaRecargar) {
                            final cantidad =
                                _cantidadesRecarga[productoId] ?? 1;
                            productosRecarga[productoId] = cantidad;
                          }

                          // Guardar recarga en Supabase
                          final exito =
                              await SupabaseService.guardarRecargaInventario(
                                sucursalId: widget.sucursal.id,
                                usuarioId: widget.currentUser.id,
                                productosRecarga: productosRecarga,
                                observaciones:
                                    'Recarga masiva desde inventario',
                              );

                          // Cerrar loading
                          Navigator.pop(context);

                          if (exito) {
                            final totalUnidades = _cantidadesRecarga.values
                                .fold(0, (sum, cantidad) => sum + cantidad);
                            final totalProductos =
                                _productosParaRecargar.length;

                            // Limpiar selección
                            setState(() {
                              _productosParaRecargar.clear();
                              _cantidadesRecarga.clear();
                            });

                            // Recargar datos para actualizar inventario
                            await _loadData();

                            // Mostrar mensaje de éxito
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '✓ Recarga guardada: $totalUnidades unidades en $totalProductos producto(s)',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } else {
                            // Mostrar error
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✗ Error al guardar la recarga. Intenta nuevamente.',
                                  ),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Cerrar loading si aún está abierto
                          if (context.mounted) {
                            Navigator.pop(context);
                          }

                          print('Error guardando recarga: $e');

                          // Mostrar error
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✗ Error: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 28,
                          ),
                          if (_productosParaRecargar.isNotEmpty)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _productosParaRecargar.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
