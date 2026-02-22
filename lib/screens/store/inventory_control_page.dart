import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        // Filtrar productos: excluir los que tienen "x10" o "x 10" en el nombre o unidad de medida, y los que tienen "frito" en el nombre
        final productosFiltrados = productos.where((producto) {
          final nombre = producto.nombre.toLowerCase();
          final unidadMedida = producto.unidadMedida.toLowerCase().trim();
          
          // Excluir si el nombre contiene "x10" o "x 10"
          final nombreContieneX10 = nombre.contains('x10') || nombre.contains('x 10');
          
          // Excluir si la unidad de medida es "x10" o "x 10"
          final unidadEsX10 = unidadMedida == 'x10' || unidadMedida == 'x 10';
          
          // Excluir si el nombre contiene "frito"
          final nombreContieneFrito = nombre.contains('frito');
          
          return !nombreContieneX10 && !unidadEsX10 && !nombreContieneFrito;
        }).toList();

        // Ordenar productos por inventario actual descendente (mayor a menor)
        _productos = productosFiltrados..sort((a, b) {
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
    List<Producto> productosFiltrados;

    // Filtrar por categoría
    if (_selectedCategoriaFilter == -1) {
      // Mostrar todos
      productosFiltrados = _productos;
    } else if (_selectedCategoriaFilter == 0) {
      // Mostrar solo sin categoría
      productosFiltrados = _productos.where((p) => p.categoria == null).toList();
    } else {
      // Mostrar solo la categoría seleccionada
      productosFiltrados = _productos
          .where((p) => p.categoria?.id == _selectedCategoriaFilter)
          .toList();
    }

    // Filtrar por búsqueda si hay texto
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      productosFiltrados = productosFiltrados.where((producto) {
        final nombre = producto.nombre.toLowerCase();
        // Buscar por palabras clave (cada palabra del query debe estar en el nombre)
        final palabrasQuery = query.split(' ').where((p) => p.isNotEmpty).toList();
        return palabrasQuery.every((palabra) => nombre.contains(palabra));
      }).toList();
    }

    return productosFiltrados;
  }

  /// Encuentra el producto crudo correspondiente a un producto frito
  /// Retorna null si no se encuentra o si el producto no es frito
  Producto? _findProductoCrudo(Producto productoFrito) {
    // Verificar si el producto es frito
    if (!productoFrito.nombre.toUpperCase().contains('FRITO')) {
      return null;
    }

    // Reemplazar "FRITO" por "CRUDO" en el nombre
    final nombreCrudo = productoFrito.nombre
        .toUpperCase()
        .replaceAll('FRITO', 'CRUDO');

    // Buscar el producto crudo correspondiente
    try {
      return _productos.firstWhere(
        (p) => p.nombre.toUpperCase() == nombreCrudo,
      );
    } catch (e) {
      // No se encontró el producto crudo
      print(
        'No se encontró producto crudo para: ${productoFrito.nombre} (buscando: $nombreCrudo)',
      );
      return null;
    }
  }

  /// Muestra un modal grande para recargar un producto individual
  Future<void> _mostrarModalRecargaIndividual(Producto producto) async {
    final cantidadController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final disponible = _getCantidadDisponible(producto.id);
    final productoCrudo = _findProductoCrudo(producto);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: Dialog(
            backgroundColor: isDark ? const Color(0xFF2C2018) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Container(
              width: screenWidth * 0.85,
              constraints: BoxConstraints(
                maxWidth: 450,
                maxHeight: screenHeight * 0.55,
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Recargar Producto',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => Navigator.pop(context),
                          color: isDark ? Colors.white70 : Colors.black54,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  
                    // Nombre del producto
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1917) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF44403C) : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Producto:',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            producto.nombre,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: disponible == 0
                                      ? Colors.red.shade50
                                      : primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: disponible == 0
                                        ? Colors.red.shade200
                                        : primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'Stock: $disponible ${producto.unidadMedida}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: disponible == 0
                                        ? Colors.red.shade700
                                        : primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  
                    // Campo de cantidad - GRANDE y fácil de usar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cantidad a recargar:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: cantidadController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 2,
                          ),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontSize: 42,
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1C1917) : Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF44403C) : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF44403C) : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 3,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Unidad: ${producto.unidadMedida}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: isDark ? Colors.white30 : Colors.grey.shade400,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () async {
                            final cantidadTexto = cantidadController.text.trim();
                            
                            if (cantidadTexto.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Por favor, ingresa una cantidad'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Validar que sea un número válido y positivo
                            final cantidad = int.tryParse(cantidadTexto);
                            if (cantidad == null || cantidad <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Por favor, ingresa un número válido mayor a 0'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // Validar stock crudo si es producto frito
                            if (productoCrudo != null) {
                              final stockCrudoDisponible = _getCantidadDisponible(productoCrudo.id);
                              if (cantidad > stockCrudoDisponible) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No hay suficiente stock CRUDO. Disponible: $stockCrudoDisponible ${productoCrudo.unidadMedida}',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                return;
                              }
                            }

                            // Cerrar el modal de entrada
                            Navigator.pop(context);

                            // Mostrar loading - guardar el contexto del builder
                            BuildContext? loadingContext;
                            if (context.mounted) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (dialogContext) {
                                  loadingContext = dialogContext;
                                  return Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2018) : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC6D13)),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Guardando recarga...',
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            try {
                              // Preparar datos de recarga
                              // IMPORTANTE: Guardar el valor exactamente como se ingresó, sin transformaciones
                              print('🔵 Guardando recarga: Producto ${producto.nombre}, Cantidad ingresada: $cantidadTexto, Valor parseado: $cantidad');
                              final productosRecarga = <int, int>{
                                producto.id: cantidad, // Guardar exactamente el valor ingresado
                              };
                              final productosCrudosADescontar = <int, int>{};

                              // Si el producto es frito, preparar descuento del producto crudo
                              if (productoCrudo != null) {
                                productosCrudosADescontar[productoCrudo.id] = cantidad;
                              }

                              // Guardar recarga de forma atómica con timeout
                              Map<String, dynamic> resultadoAtomico;
                              try {
                                resultadoAtomico = await SupabaseService
                                    .guardarRecargaInventarioConDescuentoCrudos(
                                      sucursalId: widget.sucursal.id,
                                      usuarioId: widget.currentUser.id,
                                      productosRecarga: productosRecarga,
                                      crudosADescontar: productosCrudosADescontar,
                                      observaciones: 'Recarga individual desde inventario',
                                    ).timeout(
                                      const Duration(seconds: 30),
                                      onTimeout: () {
                                        print('⏱️ Timeout al guardar recarga');
                                        return {
                                          'exito': false,
                                          'mensaje': 'Tiempo de espera agotado. La recarga puede haberse guardado. Verifica el inventario.',
                                        };
                                      },
                                    );
                              } catch (timeoutError) {
                                print('⏱️ Error de timeout: $timeoutError');
                                resultadoAtomico = {
                                  'exito': false,
                                  'mensaje': 'Tiempo de espera agotado. Verifica tu conexión e intenta de nuevo.',
                                };
                              }

                              final exito = (resultadoAtomico['exito'] as bool?) ?? false;
                              final mensajeAtomico = (resultadoAtomico['mensaje'] as String?) ?? 'Error desconocido';

                              // Cerrar loading SIEMPRE - usar el contexto guardado o el contexto actual
                              if (loadingContext != null && loadingContext!.mounted) {
                                try {
                                  Navigator.pop(loadingContext!);
                                } catch (e) {
                                  print('⚠️ Error cerrando loading dialog: $e');
                                  // Intentar con el contexto actual como fallback
                                  if (context.mounted) {
                                    try {
                                      Navigator.pop(context);
                                    } catch (e2) {
                                      print('⚠️ Error cerrando loading dialog (fallback): $e2');
                                    }
                                  }
                                }
                              } else if (context.mounted) {
                                try {
                                  Navigator.pop(context);
                                } catch (e) {
                                  print('⚠️ Error cerrando loading dialog: $e');
                                }
                              }

                              if (exito) {
                                // Recargar datos para actualizar inventario
                                try {
                                  await _loadData();
                                } catch (e) {
                                  print('⚠️ Error recargando datos: $e');
                                }

                                // Mostrar mensaje de éxito
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '✓ Recarga guardada: $cantidad ${producto.unidadMedida} de ${producto.nombre}',
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
                                    SnackBar(
                                      content: Text(
                                        '✗ Error al guardar la recarga: $mensajeAtomico',
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            } catch (e, stackTrace) {
                              // Cerrar loading si aún está abierto - Asegurarse de cerrarlo
                              if (loadingContext != null && loadingContext!.mounted) {
                                try {
                                  Navigator.pop(loadingContext!);
                                } catch (e2) {
                                  print('⚠️ Error cerrando loading dialog en catch: $e2');
                                  // Intentar con el contexto actual como fallback
                                  if (context.mounted) {
                                    try {
                                      Navigator.pop(context);
                                    } catch (e3) {
                                      print('⚠️ Error cerrando loading dialog (fallback en catch): $e3');
                                    }
                                  }
                                }
                              } else if (context.mounted) {
                                try {
                                  Navigator.pop(context);
                                } catch (e2) {
                                  print('⚠️ Error cerrando loading dialog en catch: $e2');
                                }
                              }

                              print('❌ Error guardando recarga: $e');
                              print('Stack trace: $stackTrace');

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
                          },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Confirmar Recarga',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
          ),
        );
      },
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
                                                fontSize: smallFontSize,
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
                                                fontSize: largeFontSize,
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
                                            fontSize: bodyFontSize,
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

                                // Search Bar
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2C2018)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF44403C)
                                          : const Color(0xFFE7E5E4),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Buscar producto...',
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF78716C)
                                            : const Color(0xFF78716C),
                                        fontSize: smallFontSize,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: isDark
                                            ? const Color(0xFF78716C)
                                            : const Color(0xFF78716C),
                                        size: (24 * textScaleFactor).clamp(20.0, 28.0),
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                color: isDark
                                                    ? const Color(0xFF78716C)
                                                    : const Color(0xFF78716C),
                                                size: (20 * textScaleFactor).clamp(
                                                  18.0,
                                                  24.0,
                                                ),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _searchQuery = '';
                                                  _searchController.clear();
                                                });
                                              },
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: spacingMedium,
                                        vertical: (12 * textScaleFactor).clamp(10.0, 16.0),
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: bodyFontSize,
                                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                                    ),
                                  ),
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
                                          style: TextStyle(
                                            fontSize: smallFontSize,
                                          ),
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
                                              style: TextStyle(
                                                fontSize: smallFontSize,
                                              ),
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
                                                                    fontSize:
                                                                        titleFontSize,
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
                                                                              smallFontSize,
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
                                                              fontSize:
                                                                  smallFontSize,
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
                                                            ).format(inicial),
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
                                                              ).format(vendido),
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
                                                                fontSize: 12,
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
                                                                fontSize: 24,
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
                                                    // Abrir modal de recarga individual
                                                    _mostrarModalRecargaIndividual(producto);
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
                                                            fontSize:
                                                                bodyFontSize,
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
                  child: OutlinedButton(
                    onPressed: () async {
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
                                                          fontSize:
                                                              dialogTitleSize,
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
                                                          fontSize:
                                                              dialogSmallSize,
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
                                                                            dialogSmallSize,
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
                                                                              dialogSmallSize *
                                                                              0.85,
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
                                                                          dialogSmallSize,
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
                                                                          dialogBodySize,
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
                                                                          dialogSmallSize,
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
                                                                          dialogSmallSize,
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
                                                              fontSize: 14,
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
                                                              fontSize: 18,
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
                                                          fontSize:
                                                              dialogBodySize,
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
                                                          fontSize:
                                                              dialogBodySize,
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
                            // Preparar datos de recarga (solo productos con valores positivos)
                            final productosRecarga = <int, int>{};
                            final productosCrudosADescontar = <int, int>{}; // productoId -> cantidad a descontar

                            // Validar que haya suficiente stock CRUDO para los productos fritos seleccionados
                            final erroresStock = <String>[];

                            for (final productoId in _productosParaRecargar) {
                              final producto = _productos.firstWhere(
                                (p) => p.id == productoId,
                              );
                              final cantidadSolicitada =
                                  _cantidadesRecarga[productoId] ?? 1;
                              final productoCrudo = _findProductoCrudo(producto);

                              if (productoCrudo != null) {
                                final stockCrudoDisponible =
                                    _getCantidadDisponible(productoCrudo.id);

                                if (cantidadSolicitada > stockCrudoDisponible) {
                                  erroresStock.add(
                                    '${producto.nombre}: solicita $cantidadSolicitada, stock crudo disponible de ${productoCrudo.nombre}: $stockCrudoDisponible',
                                  );
                                }
                              }
                            }

                            if (erroresStock.isNotEmpty) {
                              // Cerrar loading y mostrar mensaje de error
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No hay suficiente stock CRUDO para algunos productos fritos:\n${erroresStock.join('\n')}',
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                              return;
                            }

                            for (final productoId in _productosParaRecargar) {
                              final cantidad =
                                  _cantidadesRecarga[productoId] ?? 1;
                              productosRecarga[productoId] = cantidad;

                              // Si el producto es frito, preparar descuento del producto crudo correspondiente
                              final producto = _productos.firstWhere(
                                (p) => p.id == productoId,
                              );
                              final productoCrudo = _findProductoCrudo(producto);

                              if (productoCrudo != null) {
                                // Guardar el descuento para hacerlo después de la recarga
                                productosCrudosADescontar[productoCrudo.id] =
                                    (productosCrudosADescontar[productoCrudo.id] ?? 0) + cantidad;

                                print(
                                  'Preparando descuento de $cantidad unidades de ${productoCrudo.nombre} por recarga de ${producto.nombre}',
                                );
                              }
                            }

                            // Guardar recarga y descuentos de CRUDOS de forma ATÓMICA en el servidor
                            // (evita inconsistencias por mala conexión o concurrencia).
                            final resultadoAtomico =
                                await SupabaseService
                                    .guardarRecargaInventarioConDescuentoCrudos(
                                      sucursalId: widget.sucursal.id,
                                      usuarioId: widget.currentUser.id,
                                      productosRecarga: productosRecarga,
                                      crudosADescontar: productosCrudosADescontar,
                                      observaciones:
                                          'Recarga masiva desde inventario',
                                    );

                            final exito =
                                (resultadoAtomico['exito'] as bool?) ?? false;
                            final mensajeAtomico =
                                (resultadoAtomico['mensaje'] as String?) ??
                                'Error desconocido';

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
                                  SnackBar(
                                    content: Text(
                                      '✗ Error al guardar la recarga: $mensajeAtomico',
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
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.red,
                        width: (2 * textScaleFactor).clamp(1.5, 3.0),
                      ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      minimumSize: Size(
                        (190 * textScaleFactor).clamp(170.0, 260.0),
                        (52 * textScaleFactor).clamp(46.0, 60.0),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: (18 * textScaleFactor).clamp(14.0, 24.0),
                        vertical: (14 * textScaleFactor).clamp(10.0, 18.0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          size: (18 * textScaleFactor).clamp(16.0, 22.0),
                        ),
                        SizedBox(
                          width: (10 * textScaleFactor).clamp(8.0, 12.0),
                        ),
                        Text(
                          'Recargar',
                          style: TextStyle(
                            fontSize: (16 * textScaleFactor).clamp(14.0, 18.0),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(
                          width: (12 * textScaleFactor).clamp(10.0, 16.0),
                        ),
                        // Badge con cantidad seleccionada (sin sobreponerse al texto)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: (10 * textScaleFactor).clamp(8.0, 12.0),
                            vertical: (5 * textScaleFactor).clamp(4.0, 7.0),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _productosParaRecargar.length.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: (12 * textScaleFactor).clamp(10.0, 14.0),
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}
