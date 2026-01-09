import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sucursal.dart';
import '../models/user.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../services/supabase_service.dart';
import 'dashboard_page.dart';

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
  int _totalDesperdicio = 0;
  int? _aperturaId;

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
        _productos = productos;
        _categoriasMap = categoriasMap;
        _inventarioInicial = inventarioInicial;
        _inventarioActual = inventarioActual;
        _existenciaFinal = existenciaFinal;
        _sobrantes = sobrantes;
        _vencido = vencido;
        _totalVentasHoy = (resumenVentas['total'] as num).toDouble();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                children: [
                  Row(
                    children: [
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
                      Expanded(
                        child: Text(
                          'Cierre del Día',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color:
                                isDark ? Colors.white : const Color(0xFF1B130D),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                              size: 16,
                              color:
                                  isDark
                                      ? Colors.green.shade300
                                      : Colors.green.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Guardado',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? Colors.green.shade300
                                        : Colors.green.shade700,
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
                        Icons.calendar_today,
                        size: 16,
                        color:
                            isDark
                                ? const Color(0xFF9A6C4C)
                                : const Color(0xFF9A6C4C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getFormattedDate(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF9A6C4C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary Stats Cards
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
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
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.payments,
                                                size: 20,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF9A6C4C,
                                                        )
                                                        : const Color(
                                                          0xFF9A6C4C,
                                                        ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'TOTAL VENDIDO',
                                                style: TextStyle(
                                                  fontSize: 11,
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
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            NumberFormat.currency(
                                              symbol: '\$',
                                              decimalDigits: 2,
                                            ).format(_totalVentasHoy),
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1B130D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
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
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 20,
                                                color: Colors.red.shade600,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'DESPERDICIO',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.2,
                                                  color: Colors.red.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '$_totalDesperdicio Unid.',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
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
                            ..._getProductosAgrupadosPorCategoria().entries.map((
                              entry,
                            ) {
                              final categoriaId = entry.key;
                              final productos = entry.value;
                              final categoria =
                                  categoriaId != null
                                      ? _categoriasMap[categoriaId]
                                      : null;

                              // Skip productos que no requieren conteo (como bebidas)
                              final productosConConteo = productos;

                              if (productosConConteo.isEmpty)
                                return const SizedBox.shrink();

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: primaryColor,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          categoria?.nombre ?? 'Sin Categoría',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
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
                                    );
                                  }),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
            ),

            // Sticky Bottom Actions
            Container(
              padding: const EdgeInsets.all(16),
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
                      Text(
                        'Verificaste todo?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? Colors.grey.shade400
                                  : const Color(0xFF9A6C4C),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Implementar reportar problema
                        },
                        child: Text(
                          'Reportar problema',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _aperturaId == null
                                ? Icons.lock_outline
                                : Icons.lock,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _aperturaId == null ? 'SIN APERTURA' : 'CERRAR DÍA',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
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
      ),
    );
  }

  Widget _buildProductCard({
    required Producto producto,
    required bool isDark,
    required Color primaryColor,
  }) {
    final inicial = _inventarioInicial[producto.id] ?? 0;
    final existenciaFinal = _existenciaFinal[producto.id] ?? 0;
    final sobrantes = _sobrantes[producto.id] ?? 0;
    final vencido = _vencido[producto.id] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stock Inicial: $inicial ${producto.unidadMedida}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? const Color(0xFF9A6C4C)
                                : const Color(0xFF9A6C4C),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.bakery_dining, color: primaryColor, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Existencia Final
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Existencia Final',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? Colors.grey.shade200 : const Color(0xFF1B130D),
                  ),
                ),
                _buildStepperInput(
                  value: existenciaFinal,
                  onChanged: (newValue) {
                    setState(() {
                      _existenciaFinal[producto.id] = newValue;
                    });
                  },
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sobrantes y Vencido
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
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
                    children: [
                      Text(
                        'Sobrantes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSmallStepperInput(
                        value: sobrantes,
                        onChanged: (newValue) {
                          setState(() {
                            _sobrantes[producto.id] = newValue;
                          });
                        },
                        isDark: isDark,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vencido / Mal Estado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildSmallStepperInput(
                        value: vencido,
                        onChanged: (newValue) {
                          setState(() {
                            _vencido[producto.id] = newValue;
                            _calcularDesperdicio();
                          });
                        },
                        isDark: isDark,
                        color: Colors.red,
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
  }) {
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
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(Icons.remove, color: primaryColor, size: 20),
              ),
            ),
          ),
          Container(
            width: 48,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                onChanged(value + 1);
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
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
  }) {
    return Container(
      height: 32,
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
                width: 24,
                height: 32,
                alignment: Alignment.center,
                child: Icon(Icons.remove, color: color.shade400, size: 16),
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              value.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color.shade600,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                onChanged(value + 1);
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              child: Container(
                width: 24,
                height: 32,
                alignment: Alignment.center,
                child: Icon(Icons.add, color: color.shade400, size: 16),
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
    Color primaryColor,
  ) {
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning, color: primaryColor, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Confirmar Cierre?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Al confirmar, se generará el reporte final y se bloqueará la edición de este turno.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark ? Colors.grey.shade400 : const Color(0xFF9A6C4C),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Caja: ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(_totalVentasHoy)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isDark ? Colors.grey.shade300 : const Color(0xFF1B130D),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
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
                          // Navegar directamente al dashboard usando el contexto de la página principal
                          if (pageContext.mounted) {
                            Navigator.of(pageContext).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder:
                                    (context) => DashboardPage(
                                      sucursal: widget.sucursal,
                                      currentUser: widget.currentUser,
                                    ),
                              ),
                              (route) =>
                                  false, // Elimina todas las rutas anteriores
                            );
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
                    child: const Text(
                      'Sí, Cerrar Turno',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark
                              ? Colors.grey.shade400
                              : const Color(0xFF9A6C4C),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
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
