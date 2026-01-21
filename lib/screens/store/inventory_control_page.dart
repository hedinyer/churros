import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../models/producto.dart';
import '../../models/categoria.dart';
import '../../services/supabase_service.dart';

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
  Map<int, Categoria> _categoriasMap = {};
  int _selectedCategoriaFilter =
      -1; // -1 = Todos, 0 = Sin categoría, >0 = categoriaId
  Map<int, int> _inventarioInicial = {}; // productoId -> cantidad inicial
  Map<int, int> _ventasHoy = {}; // productoId -> cantidad vendida
  Map<int, int> _inventarioActual = {}; // productoId -> cantidad actual
  final Set<int> _productosParaRecargar =
      {}; // productoId -> productos seleccionados para recarga
  final Map<int, int> _cantidadesRecarga =
      {}; // productoId -> cantidad a recargar

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
      // Cargar productos y categorías
      final productos = await SupabaseService.getProductosActivos();
      final categorias = await SupabaseService.getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};

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
        // Ordenar productos por inventario actual descendente (mayor a menor)
        _productos =
            productos..sort((a, b) {
              final inventarioA = inventarioActual[a.id] ?? 0;
              final inventarioB = inventarioActual[b.id] ?? 0;
              return inventarioB.compareTo(inventarioA);
            });
        _categoriasMap = categoriasMap;
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
    if (inicial == 0) return 'NORMAL';
    final porcentaje = (disponible / inicial) * 100;
    if (porcentaje <= 10) return 'CRÍTICO';
    if (porcentaje <= 30) return 'POCO STOCK';
    return 'NORMAL';
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

  Map<int?, List<Producto>> _getProductosAgrupadosPorCategoria() {
    final grupos = <int?, List<Producto>>{};
    for (final producto in _productos) {
      final categoriaId = producto.categoria?.id;
      if (!grupos.containsKey(categoriaId)) {
        grupos[categoriaId] = [];
      }
      grupos[categoriaId]!.add(producto);
    }
    return grupos;
  }

  List<Producto> _getProductosFiltrados() {
    if (_selectedCategoriaFilter == -1) {
      // Mostrar todos
      return _productos;
    } else if (_selectedCategoriaFilter == 0) {
      // Mostrar solo sin categoría
      return _productos.where((p) => p.categoria == null).toList();
    } else {
      // Mostrar solo la categoría seleccionada
      return _productos
          .where((p) => p.categoria?.id == _selectedCategoriaFilter)
          .toList();
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

    // Tamaños adaptativos basados en pantalla (sin escalado de texto)
    final baseFontSize = isSmallScreen ? 16.0 : 18.0;
    final titleFontSize = (baseFontSize * 1.25 * textScaleFactor).clamp(
      16.0,
      24.0,
    );
    final bodyFontSize = (baseFontSize * textScaleFactor).clamp(14.0, 20.0);
    final smallFontSize = (baseFontSize * 0.875 * textScaleFactor).clamp(
      12.0,
      16.0,
    );
    final largeFontSize = (baseFontSize * 1.5 * textScaleFactor).clamp(
      20.0,
      32.0,
    );

    // Espaciado adaptativo
    final paddingHorizontal = isSmallScreen ? 16.0 : 20.0;
    final paddingVertical = (12.0 * textScaleFactor).clamp(8.0, 16.0);
    final spacingSmall = (8.0 * textScaleFactor).clamp(4.0, 12.0);
    final spacingMedium = (16.0 * textScaleFactor).clamp(12.0, 20.0);

    // Deshabilitar escalado de texto del sistema
    final mediaQueryWithoutTextScale = mediaQuery.copyWith(
      textScaler: TextScaler.linear(1.0),
    );

    return MediaQuery(
      data: mediaQueryWithoutTextScale,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Header - Sticky with backdrop blur
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
                            size: (24 * textScaleFactor).clamp(20.0, 28.0),
                          ),
                          style: IconButton.styleFrom(
                            padding: EdgeInsets.all(
                              (4 * textScaleFactor).clamp(2.0, 8.0),
                            ),
                            shape: const CircleBorder(),
                            minimumSize: Size(
                              (48 * textScaleFactor).clamp(40.0, 56.0),
                              (48 * textScaleFactor).clamp(40.0, 56.0),
                            ),
                          ),
                        ),
                        SizedBox(width: spacingMedium),
                        // Title
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'INVENTARIO DEL DÍA',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: (40 * textScaleFactor).clamp(32.0, 48.0),
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _isLoading ? 0.3 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: paddingHorizontal,
                            vertical: spacingMedium * 1.5,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isSmallScreen ? double.infinity : 448,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date Section
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Fecha',
                                              style: TextStyle(
                                                fontSize: 8,
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
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(height: spacingSmall / 2),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              _getFormattedDate(),
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1B130D,
                                                        ),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: spacingSmall),
                                    TextButton(
                                      onPressed: _loadData,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Actualizar',
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 8,
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor: primaryColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  margin: EdgeInsets.only(
                                    top: spacingMedium,
                                    bottom: spacingMedium,
                                  ),
                                  height: 1,
                                  color:
                                      isDark
                                          ? const Color(0xFF44403C)
                                          : const Color(0xFFE7E5E4),
                                ),
                                SizedBox(height: spacingMedium),

                                // Category Filter
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ChoiceChip(
                                        label: Text(
                                          'Todos',
                                          style: TextStyle(fontSize: 8),
                                        ),
                                        selected:
                                            _selectedCategoriaFilter == -1,
                                        selectedColor: primaryColor.withOpacity(
                                          0.15,
                                        ),
                                        backgroundColor:
                                            isDark
                                                ? const Color(0xFF2C2018)
                                                : Colors.white,
                                        side: BorderSide(
                                          color:
                                              _selectedCategoriaFilter == -1
                                                  ? primaryColor
                                                  : (isDark
                                                      ? const Color(0xFF44403C)
                                                      : const Color(
                                                        0xFFE7E5E4,
                                                      )),
                                        ),
                                        onSelected: (_) {
                                          setState(
                                            () => _selectedCategoriaFilter = -1,
                                          );
                                        },
                                      ),
                                      SizedBox(width: spacingMedium),
                                      ..._getProductosAgrupadosPorCategoria().keys.map((
                                        categoriaId,
                                      ) {
                                        final isUncategorized =
                                            categoriaId == null;
                                        final chipId =
                                            isUncategorized ? 0 : categoriaId;

                                        // Obtener el nombre de la categoría
                                        String label;
                                        if (isUncategorized) {
                                          label = 'Sin categoría';
                                        } else {
                                          // Intentar obtener del mapa primero
                                          final categoria =
                                              _categoriasMap[categoriaId];
                                          if (categoria != null) {
                                            label = categoria.nombre;
                                          } else {
                                            // Si no está en el mapa, obtener del primer producto de esa categoría
                                            final productosDeCategoria =
                                                _getProductosAgrupadosPorCategoria()[categoriaId];
                                            if (productosDeCategoria != null &&
                                                productosDeCategoria
                                                    .isNotEmpty) {
                                              label =
                                                  productosDeCategoria
                                                      .first
                                                      .categoria
                                                      ?.nombre ??
                                                  'Categoría';
                                            } else {
                                              label = 'Categoría';
                                            }
                                          }
                                        }

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            right: spacingSmall,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(
                                              label,
                                              style: TextStyle(fontSize: 8),
                                            ),
                                            selected:
                                                _selectedCategoriaFilter ==
                                                chipId,
                                            selectedColor: primaryColor
                                                .withOpacity(0.15),
                                            backgroundColor:
                                                isDark
                                                    ? const Color(0xFF2C2018)
                                                    : Colors.white,
                                            side: BorderSide(
                                              color:
                                                  _selectedCategoriaFilter ==
                                                          chipId
                                                      ? primaryColor
                                                      : (isDark
                                                          ? const Color(
                                                            0xFF44403C,
                                                          )
                                                          : const Color(
                                                            0xFFE7E5E4,
                                                          )),
                                            ),
                                            onSelected: (_) {
                                              setState(
                                                () =>
                                                    _selectedCategoriaFilter =
                                                        chipId,
                                              );
                                            },
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                SizedBox(height: spacingMedium),

                                // Products List
                                ..._getProductosFiltrados().map<Widget>((
                                  producto,
                                ) {
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
                                    margin: EdgeInsets.only(
                                      bottom: spacingMedium,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(0xFF2C2018)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
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
                                          color: Colors.black.withOpacity(0.05),
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
                                              width: (6 * textScaleFactor)
                                                  .clamp(4.0, 8.0),
                                              decoration: BoxDecoration(
                                                color:
                                                    isCritical
                                                        ? Colors.red.shade600
                                                        : Colors.red.shade500,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        12,
                                                      ),
                                                      bottomLeft:
                                                          Radius.circular(12),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        Padding(
                                          padding: EdgeInsets.only(
                                            left:
                                                (isCritical || isLowStock)
                                                    ? (8 * textScaleFactor)
                                                        .clamp(6.0, 12.0)
                                                    : spacingMedium,
                                            right: spacingMedium,
                                            top: spacingMedium,
                                            bottom: spacingMedium,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Product Info
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
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
                                                              child: FittedBox(
                                                                fit:
                                                                    BoxFit
                                                                        .scaleDown,
                                                                alignment:
                                                                    Alignment
                                                                        .centerLeft,
                                                                child: Text(
                                                                  producto
                                                                      .nombre,
                                                                  style: TextStyle(
                                                                    fontSize: 8,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    height: 1.2,
                                                                    color:
                                                                        isDark
                                                                            ? Colors.white
                                                                            : const Color(
                                                                              0xFF1B130D,
                                                                            ),
                                                                  ),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                              width:
                                                                  spacingSmall,
                                                            ),
                                                            // Status badge
                                                            FittedBox(
                                                              fit:
                                                                  BoxFit
                                                                      .scaleDown,
                                                              child: Container(
                                                                padding: EdgeInsets.symmetric(
                                                                  horizontal: (8 *
                                                                          textScaleFactor)
                                                                      .clamp(
                                                                        6.0,
                                                                        12.0,
                                                                      ),
                                                                  vertical: (4 *
                                                                          textScaleFactor)
                                                                      .clamp(
                                                                        2.0,
                                                                        6.0,
                                                                      ),
                                                                ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      isCritical
                                                                          ? Colors
                                                                              .red
                                                                              .shade600
                                                                          : isLowStock
                                                                          ? isDark
                                                                              ? Colors.red.withOpacity(
                                                                                0.4,
                                                                              )
                                                                              : Colors.red.withOpacity(0.1)
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
                                                                        size: (14 *
                                                                                textScaleFactor)
                                                                            .clamp(
                                                                              12.0,
                                                                              18.0,
                                                                            ),
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
                                                                      SizedBox(
                                                                        width:
                                                                            spacingSmall /
                                                                            2,
                                                                      ),
                                                                    FittedBox(
                                                                      fit:
                                                                          BoxFit
                                                                              .scaleDown,
                                                                      child: Text(
                                                                        estado,
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              8,
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
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        SizedBox(
                                                          height:
                                                              spacingSmall / 2,
                                                        ),
                                                        FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment:
                                                              Alignment
                                                                  .centerLeft,
                                                          child: Text(
                                                            'Unidad: ${producto.unidadMedida}',
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              color:
                                                                  isDark
                                                                      ? const Color(
                                                                        0xFF9A6C4C,
                                                                      )
                                                                      : const Color(
                                                                        0xFF9A6C4C,
                                                                      ),
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: spacingMedium),

                                              // Stats Grid
                                              Container(
                                                margin: EdgeInsets.only(
                                                  left:
                                                      (isCritical || isLowStock)
                                                          ? (8 * textScaleFactor)
                                                              .clamp(6.0, 12.0)
                                                          : 0,
                                                ),
                                                padding: EdgeInsets.all(
                                                  (12 * textScaleFactor).clamp(
                                                    8.0,
                                                    16.0,
                                                  ),
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      isDark
                                                          ? Colors.black
                                                              .withOpacity(0.2)
                                                          : const Color(
                                                            0xFFF8F7F6,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                                              fontSize: 8,
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
                                                            ).format(inicial),
                                                            style: TextStyle(
                                                              fontSize: 8,
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
                                                                fontSize: 8,
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
                                                              ).format(vendido),
                                                              style: TextStyle(
                                                                fontSize: 8,
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
                                                                fontSize: 8,
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
                                                                fontSize: 8,
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
                                                      (isCritical || isLowStock)
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
                                                            .add(producto.id);
                                                      }
                                                    });
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        _productosParaRecargar
                                                                .contains(
                                                                  producto.id,
                                                                )
                                                            ? primaryColor
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
                                                                  producto.id,
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
                                                        (isCritical ||
                                                                _productosParaRecargar
                                                                    .contains(
                                                                      producto
                                                                          .id,
                                                                    ))
                                                            ? 4
                                                            : 0,
                                                    shadowColor:
                                                        (isCritical ||
                                                                _productosParaRecargar
                                                                    .contains(
                                                                      producto
                                                                          .id,
                                                                    ))
                                                            ? primaryColor
                                                                .withOpacity(
                                                                  0.3,
                                                                )
                                                            : null,
                                                    padding: EdgeInsets.symmetric(
                                                      vertical: (12 *
                                                              textScaleFactor)
                                                          .clamp(10.0, 16.0),
                                                      horizontal: spacingMedium,
                                                    ),
                                                    minimumSize: Size(
                                                      0,
                                                      (48 * textScaleFactor)
                                                          .clamp(44.0, 56.0),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      side: BorderSide(
                                                        color: primaryColor,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          _productosParaRecargar
                                                                  .contains(
                                                                    producto.id,
                                                                  )
                                                              ? Icons.check
                                                              : isCritical
                                                              ? Icons
                                                                  .priority_high
                                                              : isLowStock
                                                              ? Icons.add_circle
                                                              : Icons.add,
                                                          size: (20 *
                                                                  textScaleFactor)
                                                              .clamp(
                                                                18.0,
                                                                24.0,
                                                              ),
                                                        ),
                                                        SizedBox(
                                                          width: spacingSmall,
                                                        ),
                                                        Text(
                                                          _productosParaRecargar
                                                                  .contains(
                                                                    producto.id,
                                                                  )
                                                              ? 'Agregado para Recargar'
                                                              : isCritical
                                                              ? 'Recargar Urgente'
                                                              : isLowStock
                                                              ? 'Recargar Stock'
                                                              : 'Recargar',
                                                          style: TextStyle(
                                                            fontSize: 8,
                                                            fontWeight:
                                                                isCritical ||
                                                                        isLowStock ||
                                                                        _productosParaRecargar.contains(
                                                                          producto
                                                                              .id,
                                                                        )
                                                                    ? FontWeight
                                                                        .bold
                                                                    : FontWeight
                                                                        .w500,
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ],
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
                                }),
                                SizedBox(
                                  height: (40 * textScaleFactor).clamp(
                                    32.0,
                                    48.0,
                                  ),
                                ),
                              ],
                            ),
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
                  bottom:
                      (24 * textScaleFactor).clamp(16.0, 32.0) +
                      mediaQuery.padding.bottom,
                  right: (24 * textScaleFactor).clamp(16.0, 32.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        // Inicializar cantidades de recarga con valores por defecto
                        _cantidadesRecarga.clear();
                        for (final productoId in _productosParaRecargar) {
                          _cantidadesRecarga[productoId] =
                              1; // valor por defecto
                        }

                        // Mostrar diálogo de confirmación mejorado
                        final dialogMediaQuery = MediaQuery.of(context);
                        // Deshabilitar escalado de texto del sistema - usar siempre 1.0
                        final dialogTextScale = 1.0;
                        final dialogScreenWidth = dialogMediaQuery.size.width;
                        final dialogScreenHeight = dialogMediaQuery.size.height;
                        final dialogIsSmallScreen = dialogScreenWidth < 600;
                        final dialogPadding =
                            (dialogIsSmallScreen ? 16.0 : 20.0) *
                            dialogTextScale.clamp(0.9, 1.1);
                        final dialogTitleSize = (20.0 * dialogTextScale).clamp(
                          18.0,
                          24.0,
                        );
                        final dialogBodySize = (16.0 * dialogTextScale).clamp(
                          14.0,
                          20.0,
                        );
                        final dialogSmallSize = (14.0 * dialogTextScale).clamp(
                          12.0,
                          18.0,
                        );
                        final dialogSpacing = (16.0 * dialogTextScale).clamp(
                          12.0,
                          20.0,
                        );
                        final dialogMaxHeight = (dialogScreenHeight * 0.75);
                        final dialogMaxWidth =
                            (dialogIsSmallScreen
                                ? dialogScreenWidth * 0.9
                                : 500.0);

                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            final isDarkDialog =
                                Theme.of(context).brightness == Brightness.dark;
                            // Deshabilitar escalado de texto del sistema en el diálogo
                            final dialogMediaQueryWithoutTextScale =
                                MediaQuery.of(
                                  context,
                                ).copyWith(textScaler: TextScaler.linear(1.0));

                            return MediaQuery(
                              data: dialogMediaQueryWithoutTextScale,
                              child: StatefulBuilder(
                                builder:
                                    (context, setState) => Dialog(
                                      backgroundColor:
                                          isDarkDialog
                                              ? const Color(0xFF2C2018)
                                              : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Container(
                                        constraints: BoxConstraints(
                                          maxHeight: dialogMaxHeight,
                                          maxWidth: dialogMaxWidth,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Header
                                            Container(
                                              padding: EdgeInsets.all(
                                                dialogPadding,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isDarkDialog
                                                        ? const Color(
                                                          0xFF2C2018,
                                                        )
                                                        : Colors.white,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        16,
                                                      ),
                                                      topRight: Radius.circular(
                                                        16,
                                                      ),
                                                    ),
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color:
                                                        isDarkDialog
                                                            ? const Color(
                                                              0xFF44403C,
                                                            )
                                                            : Colors
                                                                .grey
                                                                .shade200,
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.inventory_2,
                                                    color: primaryColor,
                                                    size: (24 * dialogTextScale)
                                                        .clamp(20.0, 28.0),
                                                  ),
                                                  SizedBox(
                                                    width: dialogSpacing * 0.75,
                                                  ),
                                                  Expanded(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        'Confirmar Recarga',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              isDarkDialog
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .grey
                                                                      .shade900,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Content - Scrollable
                                            Flexible(
                                              child: SingleChildScrollView(
                                                padding: EdgeInsets.all(
                                                  dialogPadding,
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      child: Text(
                                                        '${_productosParaRecargar.length} producto(s) seleccionado(s)',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color:
                                                              isDarkDialog
                                                                  ? const Color(
                                                                    0xFFA8A29E,
                                                                  )
                                                                  : Colors
                                                                      .grey
                                                                      .shade600,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: dialogSpacing,
                                                    ),
                                                    // Lista de productos con cantidades
                                                    ..._productosParaRecargar.map<
                                                      Widget
                                                    >((productoId) {
                                                      final producto =
                                                          _productos.firstWhere(
                                                            (p) =>
                                                                p.id ==
                                                                productoId,
                                                          );
                                                      final disponible =
                                                          _getCantidadDisponible(
                                                            productoId,
                                                          );
                                                      final cantidadRecarga =
                                                          _cantidadesRecarga[productoId] ??
                                                          1;

                                                      return Container(
                                                        margin: EdgeInsets.only(
                                                          bottom:
                                                              dialogSpacing *
                                                              0.75,
                                                        ),
                                                        padding: EdgeInsets.all(
                                                          (12 * dialogTextScale)
                                                              .clamp(8.0, 16.0),
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              isDarkDialog
                                                                  ? const Color(
                                                                    0xFF1C1917,
                                                                  )
                                                                  : Colors
                                                                      .grey
                                                                      .shade50,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                isDarkDialog
                                                                    ? const Color(
                                                                      0xFF44403C,
                                                                    )
                                                                    : Colors
                                                                        .grey
                                                                        .shade200,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: FittedBox(
                                                                    fit:
                                                                        BoxFit
                                                                            .scaleDown,
                                                                    alignment:
                                                                        Alignment
                                                                            .centerLeft,
                                                                    child: Text(
                                                                      producto
                                                                          .nombre,
                                                                      style: TextStyle(
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        fontSize:
                                                                            8,

                                                                        color:
                                                                            isDarkDialog
                                                                                ? Colors.white
                                                                                : Colors.black87,
                                                                      ),
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width:
                                                                      dialogSpacing *
                                                                      0.5,
                                                                ),
                                                                FittedBox(
                                                                  fit:
                                                                      BoxFit
                                                                          .scaleDown,
                                                                  child: Container(
                                                                    padding: EdgeInsets.symmetric(
                                                                      horizontal: (8 *
                                                                              dialogTextScale)
                                                                          .clamp(
                                                                            6.0,
                                                                            12.0,
                                                                          ),
                                                                      vertical: (4 *
                                                                              dialogTextScale)
                                                                          .clamp(
                                                                            2.0,
                                                                            6.0,
                                                                          ),
                                                                    ),
                                                                    decoration: BoxDecoration(
                                                                      color:
                                                                          disponible ==
                                                                                  0
                                                                              ? Colors.red.shade50
                                                                              : primaryColor.withOpacity(
                                                                                0.1,
                                                                              ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            4,
                                                                          ),
                                                                      border: Border.all(
                                                                        color:
                                                                            disponible ==
                                                                                    0
                                                                                ? Colors.red.shade200
                                                                                : primaryColor.withOpacity(0.3),
                                                                        width:
                                                                            1,
                                                                      ),
                                                                    ),
                                                                    child: FittedBox(
                                                                      fit:
                                                                          BoxFit
                                                                              .scaleDown,
                                                                      child: Text(
                                                                        'Stock: $disponible',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              8,
                                                                          color:
                                                                              disponible ==
                                                                                      0
                                                                                  ? Colors.red.shade700
                                                                                  : primaryColor,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                        maxLines:
                                                                            1,
                                                                        overflow:
                                                                            TextOverflow.ellipsis,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            SizedBox(
                                                              height:
                                                                  dialogSpacing *
                                                                  0.75,
                                                            ),
                                                            Row(
                                                              children: [
                                                                FittedBox(
                                                                  fit:
                                                                      BoxFit
                                                                          .scaleDown,
                                                                  child: Text(
                                                                    'Cantidad:',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          8,
                                                                      color:
                                                                          isDarkDialog
                                                                              ? const Color(
                                                                                0xFFA8A29E,
                                                                              )
                                                                              : Colors.grey.shade700,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width:
                                                                      dialogSpacing *
                                                                      0.5,
                                                                ),
                                                                SizedBox(
                                                                  width: (70 *
                                                                          dialogTextScale)
                                                                      .clamp(
                                                                        60.0,
                                                                        80.0,
                                                                      ),
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
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          8,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color:
                                                                          isDarkDialog
                                                                              ? Colors.white
                                                                              : Colors.black87,
                                                                    ),
                                                                    decoration: InputDecoration(
                                                                      isDense:
                                                                          true,
                                                                      contentPadding: EdgeInsets.symmetric(
                                                                        horizontal: (8 *
                                                                                dialogTextScale)
                                                                            .clamp(
                                                                              6.0,
                                                                              12.0,
                                                                            ),
                                                                        vertical: (10 *
                                                                                dialogTextScale)
                                                                            .clamp(
                                                                              8.0,
                                                                              14.0,
                                                                            ),
                                                                      ),
                                                                      filled:
                                                                          true,
                                                                      fillColor:
                                                                          isDarkDialog
                                                                              ? const Color(
                                                                                0xFF2C2018,
                                                                              )
                                                                              : Colors.white,
                                                                      border: OutlineInputBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                        borderSide: BorderSide(
                                                                          color:
                                                                              isDarkDialog
                                                                                  ? const Color(
                                                                                    0xFF44403C,
                                                                                  )
                                                                                  : Colors.grey.shade300,
                                                                        ),
                                                                      ),
                                                                      enabledBorder: OutlineInputBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                        borderSide: BorderSide(
                                                                          color:
                                                                              isDarkDialog
                                                                                  ? const Color(
                                                                                    0xFF44403C,
                                                                                  )
                                                                                  : Colors.grey.shade300,
                                                                        ),
                                                                      ),
                                                                      focusedBorder: OutlineInputBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              6,
                                                                            ),
                                                                        borderSide: BorderSide(
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
                                                                SizedBox(
                                                                  width:
                                                                      dialogSpacing *
                                                                      0.5,
                                                                ),
                                                                FittedBox(
                                                                  fit:
                                                                      BoxFit
                                                                          .scaleDown,
                                                                  child: Text(
                                                                    producto
                                                                        .unidadMedida,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          8,
                                                                      color:
                                                                          isDarkDialog
                                                                              ? const Color(
                                                                                0xFFA8A29E,
                                                                              )
                                                                              : Colors.grey.shade600,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                const Spacer(),
                                                                FittedBox(
                                                                  fit:
                                                                      BoxFit
                                                                          .scaleDown,
                                                                  child: Text(
                                                                    'Final: ${disponible + cantidadRecarga}',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          8,
                                                                      color:
                                                                          isDarkDialog
                                                                              ? const Color(
                                                                                0xFFA8A29E,
                                                                              )
                                                                              : Colors.grey.shade600,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }),
                                                    SizedBox(
                                                      height: dialogSpacing,
                                                    ),
                                                    // Resumen
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
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
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  Colors
                                                                      .grey
                                                                      .shade800,
                                                            ),
                                                          ),
                                                          Text(
                                                            '${_cantidadesRecarga.values.fold(0, (sum, cantidad) => sum + cantidad)}',
                                                            style: TextStyle(
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  primaryColor,
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
                                              padding: EdgeInsets.all(
                                                dialogPadding,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isDarkDialog
                                                        ? const Color(
                                                          0xFF2C2018,
                                                        )
                                                        : Colors.white,
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      bottomLeft:
                                                          Radius.circular(16),
                                                      bottomRight:
                                                          Radius.circular(16),
                                                    ),
                                                border: Border(
                                                  top: BorderSide(
                                                    color:
                                                        isDarkDialog
                                                            ? const Color(
                                                              0xFF44403C,
                                                            )
                                                            : Colors
                                                                .grey
                                                                .shade200,
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
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                dialogSpacing *
                                                                1.25,
                                                            vertical:
                                                                dialogSpacing *
                                                                0.75,
                                                          ),
                                                    ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        'Cancelar',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color:
                                                              isDarkDialog
                                                                  ? const Color(
                                                                    0xFFA8A29E,
                                                                  )
                                                                  : Colors
                                                                      .grey
                                                                      .shade700,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: dialogSpacing * 0.75,
                                                  ),
                                                  ElevatedButton.icon(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          primaryColor,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal:
                                                                dialogSpacing *
                                                                1.25,
                                                            vertical:
                                                                dialogSpacing *
                                                                0.75,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    icon: Icon(
                                                      Icons.check,
                                                      size: (18 *
                                                              dialogTextScale)
                                                          .clamp(16.0, 20.0),
                                                    ),
                                                    label: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        'Confirmar',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
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
                        width: (56 * textScaleFactor).clamp(48.0, 64.0),
                        height: (56 * textScaleFactor).clamp(48.0, 64.0),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: (28 * textScaleFactor).clamp(24.0, 32.0),
                            ),
                            if (_productosParaRecargar.isNotEmpty)
                              Positioned(
                                top: (4 * textScaleFactor).clamp(2.0, 6.0),
                                right: (4 * textScaleFactor).clamp(2.0, 6.0),
                                child: Container(
                                  width: (20 * textScaleFactor).clamp(
                                    18.0,
                                    24.0,
                                  ),
                                  height: (20 * textScaleFactor).clamp(
                                    18.0,
                                    24.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primaryColor,
                                      width: (2 * textScaleFactor).clamp(
                                        1.5,
                                        3.0,
                                      ),
                                    ),
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _productosParaRecargar.length
                                            .toString(),
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 8,

                                          fontWeight: FontWeight.bold,
                                        ),
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
      ),
    );
  }
}
