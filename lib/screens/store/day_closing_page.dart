import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../models/producto.dart';
import '../../models/categoria.dart';
import '../../services/supabase_service.dart';
import '../../main.dart';

class DayClosingPage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const DayClosingPage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<DayClosingPage> createState() => _DayClosingPageState();
}

class _DayClosingPageState extends State<DayClosingPage> {
  bool _isLoading = true;
  List<Producto> _productos = [];
  Map<int, Categoria> _categoriasMap = {};
  Map<int, int> _inventarioInicial = {}; // productoId -> cantidad inicial
  Map<int, int> _inventarioActual = {}; // productoId -> cantidad actual
  Map<int, int> _existenciaFinal = {}; // productoId -> existencia final
  Map<int, int> _sobrantes = {}; // productoId -> sobrantes
  Map<int, int> _vencido = {}; // productoId -> vencido/mal estado
  double _totalVentasHoy = 0.0;
  double _totalGastosHoy = 0.0;
  int _totalDesperdicio = 0;
  int? _aperturaId;
  // Filtro de categorías: -1 = Todas, 0 = Sin categoría, >0 = categoria_id
  int _selectedCategoriaFilter = -1;

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

      // Cargar apertura del día actual
      final apertura = await SupabaseService.getAperturaDiaActual(
        widget.sucursal.id,
      );

      // Cargar inventario inicial
      final inventarioInicial = await SupabaseService.getInventarioInicialHoy(
        widget.sucursal.id,
      );

      // Cargar inventario actual
      final inventarioActual = await SupabaseService.getInventarioActual(
        widget.sucursal.id,
      );

      // Cargar ventas del día
      final resumenVentas = await SupabaseService.getResumenVentasHoy(
        widget.sucursal.id,
      );

      // Cargar gastos del día
      final gastos = await SupabaseService.getGastosPuntoVenta(
        sucursalId: widget.sucursal.id,
      );
      final totalGastos = gastos.fold<double>(
        0.0,
        (sum, gasto) => sum + ((gasto['monto'] as num?)?.toDouble() ?? 0.0),
      );

      // Inicializar valores
      final existenciaFinal = <int, int>{};
      final sobrantes = <int, int>{};
      final vencido = <int, int>{};

      for (final producto in productos) {
        final actual = inventarioActual[producto.id] ?? 0;
        existenciaFinal[producto.id] = actual;
        sobrantes[producto.id] = 0;
        vencido[producto.id] = 0;
      }

      setState(() {
        // Ordenar productos por inventario actual descendente (mayor a menor)
        _productos = productos..sort((a, b) {
          final inventarioA = inventarioActual[a.id] ?? 0;
          final inventarioB = inventarioActual[b.id] ?? 0;
          return inventarioB.compareTo(inventarioA);
        });
        _categoriasMap = categoriasMap;
        _inventarioInicial = inventarioInicial;
        _inventarioActual = inventarioActual;
        _existenciaFinal = existenciaFinal;
        _sobrantes = sobrantes;
        _vencido = vencido;
        _totalVentasHoy = (resumenVentas['total'] as num).toDouble();
        _totalGastosHoy = totalGastos;
        _aperturaId = apertura?.id;
        _isLoading = false;
      });

      // Mostrar advertencia si no hay apertura
      if (apertura == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ No se encontró una apertura del día. Debes abrir la tienda primero.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }

      _calcularDesperdicio();
    } catch (e) {
      print('Error cargando datos de cierre: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calcularDesperdicio() {
    int total = 0;
    for (final cantidad in _vencido.values) {
      total += cantidad;
    }
    setState(() {
      _totalDesperdicio = total;
    });
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    final turno = now.hour < 14 ? 'AM' : 'PM';
    return '$weekday, ${now.day} $month • Turno $turno';
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

  List<int?> _getCategoriasDisponiblesEnProductos() {
    final ids = <int?>{};
    for (final p in _productos) {
      ids.add(p.categoria?.id);
    }
    final list = ids.toList();
    // Ordenar: primero sin categoría (null), luego por nombre de categoría
    list.sort((a, b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      final nameA = _categoriasMap[a]?.nombre ?? '';
      final nameB = _categoriasMap[b]?.nombre ?? '';
      return nameA.compareTo(nameB);
    });
    return list;
  }

  Widget _buildCategoryFilter({
    required bool isDark,
    required Color primaryColor,
    required double textScaleFactor,
    required double smallFontSize,
    required double spacingSmall,
    required double spacingMedium,
    required double paddingHorizontal,
  }) {
    final categoriasDisponibles = _getCategoriasDisponiblesEnProductos();

    // Si solo hay una "categoría" (o ninguna), no mostramos filtro
    if (categoriasDisponibles.length <= 1) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        paddingHorizontal,
        spacingSmall,
        paddingHorizontal,
        spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtrar por categoría',
            style: TextStyle(
              fontSize: smallFontSize,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF9A6C4C),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: spacingSmall),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(
                    'Todos',
                    style: TextStyle(fontSize: smallFontSize),
                  ),
                  selected: _selectedCategoriaFilter == -1,
                  selectedColor: primaryColor.withOpacity(0.15),
                  backgroundColor:
                      isDark ? const Color(0xFF2C2018) : Colors.white,
                  side: BorderSide(
                    color: _selectedCategoriaFilter == -1
                        ? primaryColor
                        : (isDark
                            ? const Color(0xFF44403C)
                            : const Color(0xFFE7E5E4)),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategoriaFilter = -1);
                  },
                ),
                SizedBox(width: spacingMedium),
                ...categoriasDisponibles.map((categoriaId) {
                  final isUncategorized = categoriaId == null;
                  final chipId = isUncategorized ? 0 : categoriaId;
                  final label = isUncategorized
                      ? 'Sin categoría'
                      : (_categoriasMap[categoriaId]?.nombre ?? 'Categoría');

                  return Padding(
                    padding: EdgeInsets.only(right: spacingSmall),
                    child: ChoiceChip(
                      label: Text(
                        label,
                        style: TextStyle(fontSize: smallFontSize),
                      ),
                      selected: _selectedCategoriaFilter == chipId,
                      selectedColor: primaryColor.withOpacity(0.15),
                      backgroundColor:
                          isDark ? const Color(0xFF2C2018) : Colors.white,
                      side: BorderSide(
                        color: _selectedCategoriaFilter == chipId
                            ? primaryColor
                            : (isDark
                                ? const Color(0xFF44403C)
                                : const Color(0xFFE7E5E4)),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategoriaFilter = chipId);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
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
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
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
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Cierre del Día',
                              style: TextStyle(
                                fontSize: titleFontSize,
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: (8 * textScaleFactor).clamp(
                                6.0,
                                12.0,
                              ),
                              vertical: (4 * textScaleFactor).clamp(2.0, 6.0),
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_done,
                                  size: (16 * textScaleFactor).clamp(
                                    14.0,
                                    20.0,
                                  ),
                                  color:
                                      isDark
                                          ? Colors.green.shade300
                                          : Colors.green.shade700,
                                ),
                                SizedBox(width: spacingSmall / 2),
                                Text(
                                  'Guardado',
                                  style: TextStyle(
                                    fontSize: smallFontSize,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark
                                            ? Colors.green.shade300
                                            : Colors.green.shade700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacingSmall),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: (16 * textScaleFactor).clamp(14.0, 20.0),
                          color:
                              isDark
                                  ? const Color(0xFF9A6C4C)
                                  : const Color(0xFF9A6C4C),
                        ),
                        SizedBox(width: spacingSmall / 2),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _getFormattedDate(),
                              style: TextStyle(
                                fontSize: smallFontSize,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF9A6C4C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: AnimatedOpacity(
                  opacity: _isLoading ? 0.3 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: (100 * textScaleFactor).clamp(80.0, 120.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Stats Cards
                        Padding(
                          padding: EdgeInsets.all(spacingMedium),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(spacingMedium),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? const Color(0xFF2C2018)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? const Color(0xFF44403C)
                                              : const Color(0xFFE7E5E4),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.payments,
                                            size: (20 * textScaleFactor).clamp(
                                              18.0,
                                              24.0,
                                            ),
                                            color:
                                                isDark
                                                    ? const Color(0xFF9A6C4C)
                                                    : const Color(0xFF9A6C4C),
                                          ),
                                          SizedBox(width: spacingSmall / 2),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'TOTAL',
                                                style: TextStyle(
                                                  fontSize: smallFontSize * 0.8,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
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
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacingSmall),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          NumberFormat.currency(
                                            symbol: '\$',
                                            decimalDigits: 0,
                                          ).format(_totalVentasHoy - _totalGastosHoy),
                                          style: TextStyle(
                                            fontSize: largeFontSize,
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
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: spacingMedium),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.all(spacingMedium),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: (20 * textScaleFactor).clamp(
                                              18.0,
                                              24.0,
                                            ),
                                            color: Colors.red.shade600,
                                          ),
                                          SizedBox(width: spacingSmall / 2),
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'DESPERDICIO',
                                                style: TextStyle(
                                                  fontSize: smallFontSize * 0.8,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                  color: Colors.red.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacingSmall),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '$_totalDesperdicio Unid.',
                                          style: TextStyle(
                                            fontSize: largeFontSize,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Products by Category
                        _buildCategoryFilter(
                          isDark: isDark,
                          primaryColor: primaryColor,
                          textScaleFactor: textScaleFactor,
                          smallFontSize: smallFontSize,
                          spacingSmall: spacingSmall,
                          spacingMedium: spacingMedium,
                          paddingHorizontal: paddingHorizontal,
                        ),
                        ..._getProductosAgrupadosPorCategoria().entries.map<
                          Widget
                        >((entry) {
                          final categoriaId = entry.key;
                          final productos = entry.value;
                          final categoria =
                              categoriaId != null
                                  ? _categoriasMap[categoriaId]
                                  : null;

                          // Aplicar filtro
                          if (_selectedCategoriaFilter != -1) {
                            final filtroId = _selectedCategoriaFilter;
                            final entryId = categoriaId == null ? 0 : categoriaId;
                            if (entryId != filtroId) {
                              return const SizedBox.shrink();
                            }
                          }

                          // Skip productos que no requieren conteo (como bebidas)
                          final productosConConteo = productos;

                          if (productosConConteo.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: paddingHorizontal,
                                  vertical: spacingSmall,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: (24 * textScaleFactor).clamp(
                                        20.0,
                                        28.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    SizedBox(width: spacingSmall),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          categoria?.nombre ?? 'Sin Categoría',
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
                                    ),
                                  ],
                                ),
                              ),
                              ...productosConConteo.map((producto) {
                                return _buildProductCard(
                                  producto: producto,
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                  textScaleFactor: textScaleFactor,
                                  isSmallScreen: isSmallScreen,
                                  isVerySmallScreen: isVerySmallScreen,
                                  titleFontSize: titleFontSize,
                                  bodyFontSize: bodyFontSize,
                                  smallFontSize: smallFontSize,
                                  largeFontSize: largeFontSize,
                                  spacingSmall: spacingSmall,
                                  spacingMedium: spacingMedium,
                                  paddingHorizontal: paddingHorizontal,
                                );
                              }),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // Sticky Bottom Actions
              Container(
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
                      color:
                          isDark
                              ? const Color(0xFF44403C)
                              : const Color(0xFFE7E5E4),
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
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
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Verificaste todo?',
                              style: TextStyle(
                                fontSize: bodyFontSize,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF9A6C4C),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // TODO: Implementar reportar problema
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Reportar problema',
                              style: TextStyle(
                                fontSize: smallFontSize,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: spacingMedium),
                    SizedBox(
                      width: double.infinity,
                      height: (56 * textScaleFactor).clamp(48.0, 64.0),
                      child: ElevatedButton(
                        onPressed:
                            _aperturaId == null
                                ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '⚠️ No puedes cerrar el día sin una apertura. Debes abrir la tienda primero desde el menú principal.',
                                      ),
                                      backgroundColor: Colors.orange,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                                : () => _showConfirmDialog(
                                  context,
                                  isDark,
                                  primaryColor,
                                  textScaleFactor: textScaleFactor,
                                  isSmallScreen: isSmallScreen,
                                  titleFontSize: titleFontSize,
                                  bodyFontSize: bodyFontSize,
                                  smallFontSize: smallFontSize,
                                  spacingSmall: spacingSmall,
                                  spacingMedium: spacingMedium,
                                  paddingHorizontal: paddingHorizontal,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _aperturaId == null ? Colors.grey : primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: _aperturaId == null ? 0 : 4,
                          shadowColor:
                              _aperturaId == null
                                  ? null
                                  : primaryColor.withOpacity(0.3),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _aperturaId == null
                                    ? Icons.lock_outline
                                    : Icons.lock,
                                size: (24 * textScaleFactor).clamp(20.0, 28.0),
                              ),
                              SizedBox(width: spacingSmall),
                              Text(
                                _aperturaId == null
                                    ? 'SIN APERTURA'
                                    : 'CERRAR DÍA',
                                style: TextStyle(
                                  fontSize: bodyFontSize * 1.1,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard({
    required Producto producto,
    required bool isDark,
    required Color primaryColor,
    required double textScaleFactor,
    required bool isSmallScreen,
    required bool isVerySmallScreen,
    required double titleFontSize,
    required double bodyFontSize,
    required double smallFontSize,
    required double largeFontSize,
    required double spacingSmall,
    required double spacingMedium,
    required double paddingHorizontal,
  }) {
    final inicial = _inventarioInicial[producto.id] ?? 0;
    final existenciaActual = _inventarioActual[producto.id] ?? 0;
    final existenciaFinal = _existenciaFinal[producto.id] ?? 0;
    final sobrantes = _sobrantes[producto.id] ?? 0;
    final vencido = _vencido[producto.id] ?? 0;

    final iconSize =
        (isVerySmallScreen ? 40.0 : 48.0) * textScaleFactor.clamp(0.9, 1.1);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: paddingHorizontal,
        vertical: spacingSmall,
      ),
      padding: EdgeInsets.all(spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF44403C) : const Color(0xFFE7E5E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: spacingSmall / 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Stock Inicial: $inicial ${producto.unidadMedida}',
                        style: TextStyle(
                          fontSize: smallFontSize,
                          color:
                              isDark
                                  ? const Color(0xFF9A6C4C)
                                  : const Color(0xFF9A6C4C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacingSmall),
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bakery_dining,
                  color: primaryColor,
                  size: (iconSize * 0.5).clamp(20.0, 28.0),
                ),
              ),
            ],
          ),
          SizedBox(height: spacingMedium),

          // Existencia Final
          Container(
            padding: EdgeInsets.all((12 * textScaleFactor).clamp(8.0, 16.0)),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Existencia Final',
                      style: TextStyle(
                        fontSize: bodyFontSize,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? Colors.grey.shade200
                                : const Color(0xFF1B130D),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(width: spacingSmall),
                _buildStepperInput(
                  value: existenciaFinal,
                  onChanged: (newValue) {
                    setState(() {
                      // Validar que la existencia final no sea menor a 0
                      // y que la suma de existencia final + sobrantes + vencidos no exceda la existencia actual
                      final sobrantesActual = _sobrantes[producto.id] ?? 0;
                      final vencidoActual = _vencido[producto.id] ?? 0;
                      final maxExistenciaFinal = existenciaActual - sobrantesActual - vencidoActual;
                      
                      final nuevaExistenciaFinal = newValue.clamp(0, maxExistenciaFinal);
                      _existenciaFinal[producto.id] = nuevaExistenciaFinal;
                    });
                  },
                  isDark: isDark,
                  primaryColor: primaryColor,
                  textScaleFactor: textScaleFactor,
                  bodyFontSize: bodyFontSize,
                  maxValue: existenciaActual - sobrantes - vencido,
                ),
              ],
            ),
          ),

          SizedBox(height: spacingMedium),

          // Sobrantes y Vencido
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(
                    (8 * textScaleFactor).clamp(6.0, 12.0),
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sobrantes',
                          style: TextStyle(
                            fontSize: smallFontSize,
                            fontWeight: FontWeight.w500,
                            color:
                                isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: spacingSmall),
                      _buildSmallStepperInput(
                        value: sobrantes,
                        onChanged: (newValue) {
                          setState(() {
                            final oldSobrantes = _sobrantes[producto.id] ?? 0;
                            final diferencia = newValue - oldSobrantes;
                            final existenciaFinalActual = _existenciaFinal[producto.id] ?? existenciaActual;
                            
                            // Validar que la suma de sobrantes + vencidos no exceda la existencia actual
                            final vencidoActual = _vencido[producto.id] ?? 0;
                            final totalSobrantesVencidos = newValue + vencidoActual;
                            
                            if (totalSobrantesVencidos > existenciaActual) {
                              // Limitar sobrantes al máximo permitido
                              final maxSobrantes = existenciaActual - vencidoActual;
                              _sobrantes[producto.id] = maxSobrantes.clamp(0, existenciaActual);
                              return;
                            }
                            
                            // Actualizar sobrantes
                            _sobrantes[producto.id] = newValue;
                            
                            // Ajustar existencia final: si aumentan sobrantes, disminuye existencia final
                            final nuevaExistenciaFinal = (existenciaFinalActual - diferencia).clamp(0, existenciaActual);
                            _existenciaFinal[producto.id] = nuevaExistenciaFinal;
                          });
                        },
                        isDark: isDark,
                        color: Colors.grey,
                        textScaleFactor: textScaleFactor,
                        smallFontSize: smallFontSize,
                        maxValue: existenciaActual - vencido,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: spacingMedium),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(
                    (8 * textScaleFactor).clamp(6.0, 12.0),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Vencido / Mal Estado',
                          style: TextStyle(
                            fontSize: smallFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: spacingSmall),
                      _buildSmallStepperInput(
                        value: vencido,
                        onChanged: (newValue) {
                          setState(() {
                            final oldVencido = _vencido[producto.id] ?? 0;
                            final diferencia = newValue - oldVencido;
                            final existenciaFinalActual = _existenciaFinal[producto.id] ?? existenciaActual;
                            
                            // Validar que la suma de sobrantes + vencidos no exceda la existencia actual
                            final sobrantesActual = _sobrantes[producto.id] ?? 0;
                            final totalSobrantesVencidos = sobrantesActual + newValue;
                            
                            if (totalSobrantesVencidos > existenciaActual) {
                              // Limitar vencidos al máximo permitido
                              final maxVencido = existenciaActual - sobrantesActual;
                              _vencido[producto.id] = maxVencido.clamp(0, existenciaActual);
                              _calcularDesperdicio();
                              return;
                            }
                            
                            // Actualizar vencidos
                            _vencido[producto.id] = newValue;
                            _calcularDesperdicio();
                            
                            // Ajustar existencia final: si aumentan vencidos, disminuye existencia final
                            final nuevaExistenciaFinal = (existenciaFinalActual - diferencia).clamp(0, existenciaActual);
                            _existenciaFinal[producto.id] = nuevaExistenciaFinal;
                          });
                        },
                        isDark: isDark,
                        color: Colors.red,
                        textScaleFactor: textScaleFactor,
                        smallFontSize: smallFontSize,
                        maxValue: existenciaActual - sobrantes,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperInput({
    required int value,
    required Function(int) onChanged,
    required bool isDark,
    required Color primaryColor,
    required double textScaleFactor,
    required double bodyFontSize,
    int? maxValue,
  }) {
    final buttonSize = (40.0 * textScaleFactor).clamp(36.0, 48.0);
    final textWidth = (48.0 * textScaleFactor).clamp(40.0, 56.0);
    final maxAllowed = maxValue ?? double.infinity.toInt();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (value > 0) {
                  onChanged(value - 1);
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: primaryColor,
                  size: (20 * textScaleFactor).clamp(18.0, 24.0),
                ),
              ),
            ),
          ),
          Container(
            width: textWidth,
            height: buttonSize,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value.toString(),
                style: TextStyle(
                  fontSize: bodyFontSize * 1.1,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B130D),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (value < maxAllowed) {
                  onChanged(value + 1);
                }
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value >= maxAllowed 
                      ? primaryColor.withOpacity(0.5)
                      : primaryColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: Colors.white,
                  size: (20 * textScaleFactor).clamp(18.0, 24.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStepperInput({
    required int value,
    required Function(int) onChanged,
    required bool isDark,
    required MaterialColor color,
    required double textScaleFactor,
    required double smallFontSize,
    int? maxValue,
  }) {
    final height = (32.0 * textScaleFactor).clamp(28.0, 40.0);
    final buttonWidth = (24.0 * textScaleFactor).clamp(20.0, 32.0);
    final textWidth = (32.0 * textScaleFactor).clamp(28.0, 40.0);
    final maxAllowed = maxValue ?? double.infinity.toInt();

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (value > 0) {
                  onChanged(value - 1);
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
              child: Container(
                width: buttonWidth,
                height: height,
                alignment: Alignment.center,
                child: Icon(
                  Icons.remove,
                  color: color.shade400,
                  size: (16 * textScaleFactor).clamp(14.0, 20.0),
                ),
              ),
            ),
          ),
          Container(
            width: textWidth,
            height: height,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value.toString(),
                style: TextStyle(
                  fontSize: smallFontSize,
                  fontWeight: FontWeight.w600,
                  color: color.shade600,
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (value < maxAllowed) {
                  onChanged(value + 1);
                }
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              child: Container(
                width: buttonWidth,
                height: height,
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: value >= maxAllowed 
                      ? color.shade200 
                      : color.shade400,
                  size: (16 * textScaleFactor).clamp(14.0, 20.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    bool isDark,
    Color primaryColor, {
    required double textScaleFactor,
    required bool isSmallScreen,
    required double titleFontSize,
    required double bodyFontSize,
    required double smallFontSize,
    required double spacingSmall,
    required double spacingMedium,
    required double paddingHorizontal,
  }) {
    // Guardar el contexto de la página principal antes de mostrar el modal
    final pageContext = context;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2018) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: EdgeInsets.all(paddingHorizontal * 1.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: (48 * textScaleFactor).clamp(40.0, 56.0),
                  height: (4 * textScaleFactor).clamp(3.0, 6.0),
                  margin: EdgeInsets.only(bottom: spacingMedium * 1.5),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: (64 * textScaleFactor).clamp(56.0, 72.0),
                  height: (64 * textScaleFactor).clamp(56.0, 72.0),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning,
                    color: primaryColor,
                    size: (32 * textScaleFactor).clamp(28.0, 40.0),
                  ),
                ),
                SizedBox(height: spacingMedium),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '¿Confirmar Cierre?',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: spacingMedium),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Al confirmar, se generará el reporte final y se bloqueará la edición de este turno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: bodyFontSize,
                      color:
                          isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF9A6C4C),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: spacingSmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Total Caja: ${NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(_totalVentasHoy - _totalGastosHoy)}',
                    style: TextStyle(
                      fontSize: bodyFontSize * 1.1,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark
                              ? Colors.grey.shade300
                              : const Color(0xFF1B130D),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(height: spacingMedium * 1.5),
                SizedBox(
                  width: double.infinity,
                  height: (48 * textScaleFactor).clamp(44.0, 56.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      // Validar que existe apertura
                      if (_aperturaId == null) {
                        Navigator.pop(context); // Cerrar modal primero
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚠️ No se puede cerrar el día sin una apertura. Por favor, abre la tienda primero desde el menú "Apertura de Punto".',
                            ),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 5),
                          ),
                        );
                        return;
                      }

                      // Cerrar el modal de confirmación primero
                      Navigator.pop(context);

                      try {
                        // Guardar cierre del día (sin mostrar loading)
                        final exito = await SupabaseService.guardarCierreDia(
                          sucursalId: widget.sucursal.id,
                          aperturaId: _aperturaId!,
                          usuarioCierreId: widget.currentUser.id,
                          existenciaFinal: _existenciaFinal,
                          sobrantes: _sobrantes,
                          vencido: _vencido,
                          totalVentas: _totalVentasHoy,
                          observaciones: 'Cierre del día completado',
                        );

                        if (exito) {
                          // Cerrar sesión y navegar al login
                          if (pageContext.mounted) {
                            // Mostrar mensaje de éxito
                            ScaffoldMessenger.of(pageContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✓ Cierre del día completado exitosamente. Cerrando sesión...',
                                ),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            
                            // Esperar un momento para que se vea el mensaje
                            await Future.delayed(const Duration(seconds: 1));
                            
                            // Navegar al login y limpiar todo el stack
                            if (pageContext.mounted) {
                              Navigator.of(pageContext).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                                (route) => false, // Elimina todas las rutas anteriores
                              );
                            }
                          }
                        } else {
                          // Mostrar error si falla
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '✗ Error al guardar el cierre. Verifica que no exista un cierre previo.',
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        print('Error guardando cierre: $e');

                        // Mostrar error
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✗ Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Sí, Cerrar Turno',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: spacingMedium),
                SizedBox(
                  width: double.infinity,
                  height: (48 * textScaleFactor).clamp(44.0, 56.0),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF9A6C4C),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
