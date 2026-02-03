import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/producto.dart';
import '../../models/categoria.dart';
import '../../services/supabase_service.dart';

class ManualOrderPage extends StatefulWidget {
  const ManualOrderPage({super.key});

  @override
  State<ManualOrderPage> createState() => _ManualOrderPageState();
}

class _ManualOrderPageState extends State<ManualOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _clienteNombreController = TextEditingController();
  final _clienteTelefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _domicilioController = TextEditingController();

  List<Producto> _productos = [];
  Map<int, Categoria> _categoriasMap = {};
  Map<int, int> _cantidades = {}; // productoId -> cantidad
  Map<int, TextEditingController> _cantidadControllers =
      {}; // productoId -> controller
  final Map<int, FocusNode> _cantidadFocusNodes = {}; // productoId -> focusNode
  Map<int, TextEditingController> _precioControllers =
      {}; // productoId -> controller precio especial
  final Map<int, FocusNode> _precioFocusNodes = {}; // productoId -> focusNode
  Map<int, double> _preciosEspeciales =
      {}; // productoId -> precio especial (si aplica)
  Map<int, int> _inventarioFabrica = {}; // productoId -> cantidad en inventario_fabrica
  Map<int, int> _inventarioSucursal5 = {}; // productoId -> cantidad en inventario_actual (sucursal_id = 5)
  String _metodoPago = 'efectivo';
  bool _esFiado = false;
  bool _isLoading = true;
  bool _isGuardando = false;
  bool _isOnline = true;
  // Filtro de categorías: -1 = Todas, 0 = Sin categoría, >0 = categoria_id
  int _selectedCategoriaFilter = -1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkConnection();
  }

  @override
  void dispose() {
    _clienteNombreController.dispose();
    _clienteTelefonoController.dispose();
    _direccionController.dispose();
    _observacionesController.dispose();
    _domicilioController.dispose();
    _searchController.dispose();
    // Dispose de todos los controllers de cantidad
    for (var controller in _cantidadControllers.values) {
      controller.dispose();
    }
    _cantidadControllers.clear();
    for (final node in _cantidadFocusNodes.values) {
      node.dispose();
    }
    _cantidadFocusNodes.clear();
    for (var controller in _precioControllers.values) {
      controller.dispose();
    }
    _precioControllers.clear();
    for (final node in _precioFocusNodes.values) {
      node.dispose();
    }
    _precioFocusNodes.clear();
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
      final productos = await SupabaseService.getProductosActivos();
      final categorias = await SupabaseService.getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};

      // Excluir productos cuyo nombre contenga "x10" o "x 10"
      final productosFiltrados = productos.where((producto) {
        final nombre = producto.nombre.toLowerCase();
        return !nombre.contains('x10') && !nombre.contains('x 10');
      }).toList();

      // Cargar inventarios
      final inventarioFabrica = await SupabaseService.getInventarioFabricaCompleto();
      
      // Cargar inventario de sucursal 5
      final inventarioSucursal5Response = await SupabaseService.client
          .from('inventario_actual')
          .select('producto_id, cantidad')
          .eq('sucursal_id', 5);
      final inventarioSucursal5 = <int, int>{};
      for (final item in inventarioSucursal5Response) {
        inventarioSucursal5[item['producto_id'] as int] = (item['cantidad'] as num?)?.toInt() ?? 0;
      }

      setState(() {
        _productos = productosFiltrados;
        _categoriasMap = categoriasMap;
        _inventarioFabrica = inventarioFabrica;
        _inventarioSucursal5 = inventarioSucursal5;
        // Inicializar controllers de precio con el precio base del producto
        _precioControllers = {
          for (final p in productosFiltrados)
            p.id: TextEditingController(text: p.precio.toStringAsFixed(0)),
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando productos: $e');
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
  }

  void _decrementProduct(int productoId) {
    setState(() {
      final current = _cantidades[productoId] ?? 0;
      if (current > 0) {
        _cantidades[productoId] = current - 1;
        if (_cantidades[productoId] == 0) {
          _cantidades.remove(productoId);
        }
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
        _cantidades.remove(productoId);
      });
      return;
    }

    final cantidad = int.tryParse(value) ?? 0;
    if (cantidad >= 0) {
      setState(() {
        if (cantidad > 0) {
          _cantidades[productoId] = cantidad;
        } else {
          _cantidades.remove(productoId);
        }
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

  FocusNode _getOrCreateCantidadFocusNode(int productoId) {
    return _cantidadFocusNodes.putIfAbsent(
      productoId,
      () => FocusNode(debugLabel: 'manual_qty_$productoId'),
    );
  }

  TextEditingController _getOrCreatePrecioController(int productoId) {
    if (!_precioControllers.containsKey(productoId)) {
      final producto = _productos.firstWhere(
        (p) => p.id == productoId,
        orElse:
            () => Producto(
              id: productoId,
              nombre: 'Producto',
              precio: 0.0,
              unidadMedida: 'unidad',
              activo: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      );
      _precioControllers[productoId] = TextEditingController(
        text: producto.precio.toStringAsFixed(0),
      );
    }
    return _precioControllers[productoId]!;
  }

  FocusNode _getOrCreatePrecioFocusNode(int productoId) {
    return _precioFocusNodes.putIfAbsent(
      productoId,
      () => FocusNode(debugLabel: 'manual_price_$productoId'),
    );
  }

  double _getPrecioProducto(int productoId) {
    final precioEspecial = _preciosEspeciales[productoId];
    if (precioEspecial != null && precioEspecial > 0) {
      return precioEspecial;
    }
    final producto = _productos.firstWhere(
      (p) => p.id == productoId,
      orElse:
          () => Producto(
            id: productoId,
            nombre: 'Producto',
            precio: 0.0,
            unidadMedida: 'unidad',
            activo: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
    );
    return producto.precio;
  }

  /// Obtiene el inventario disponible para un producto
  /// Si es crudo: inventario_fabrica
  /// Si es frito o bebida (categoria_id = 3): inventario_actual (sucursal_id = 5)
  int _getInventarioDisponible(int productoId) {
    final producto = _productos.firstWhere(
      (p) => p.id == productoId,
      orElse: () => Producto(
        id: productoId,
        nombre: 'Producto',
        precio: 0.0,
        unidadMedida: 'unidad',
        activo: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    
    final nombreProducto = producto.nombre.toLowerCase();
    final categoriaId = producto.categoria?.id;
    
    // Si contiene "frito" → inventario_actual (sucursal_id = 5)
    if (nombreProducto.contains('frito')) {
      return _inventarioSucursal5[productoId] ?? 0;
    }
    // Si contiene "crudo" → inventario_fabrica
    else if (nombreProducto.contains('crudo')) {
      return _inventarioFabrica[productoId] ?? 0;
    }
    // Si es bebida (categoria_id = 3) → inventario_actual (sucursal_id = 5)
    else if (categoriaId == 3) {
      return _inventarioSucursal5[productoId] ?? 0;
    }
    // Por defecto, inventario_fabrica
    else {
      return _inventarioFabrica[productoId] ?? 0;
    }
  }

  void _onPrecioChanged(int productoId, String value) {
    final v = value.trim();
    // Aceptar formatos comunes (1,300 / 1.300 / $1300) limpiando a solo dígitos
    final digitsOnly = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      setState(() {
        _preciosEspeciales.remove(productoId);
      });
      return;
    }

    final precioInt = int.tryParse(digitsOnly) ?? 0;
    if (precioInt >= 0) {
      setState(() {
        // Si el precio es 0 o negativo, lo tratamos como "sin precio especial"
        if (precioInt > 0) {
          _preciosEspeciales[productoId] = precioInt.toDouble();
        } else {
          _preciosEspeciales.remove(productoId);
        }
      });
    }
  }

  double _calcularTotal() {
    double total = 0.0;
    for (final entry in _cantidades.entries) {
      final precio = _getPrecioProducto(entry.key);
      total += precio * entry.value;
    }
    // Agregar domicilio si existe
    final domicilio = double.tryParse(_domicilioController.text.trim()) ?? 0.0;
    total += domicilio;
    return total;
  }

  int _calcularTotalItems() {
    return _cantidades.values.fold(0, (sum, cantidad) => sum + cantidad);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
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

  Future<void> _guardarPedido() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validar que haya al menos un producto
    final productosConCantidad =
        _cantidades.entries.where((entry) => entry.value > 0).toList();

    if (productosConCantidad.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un producto al pedido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validar inventario disponible antes de guardar
    final productosInsuficientes = <String>[];
    for (final entry in productosConCantidad) {
      final productoId = entry.key;
      final cantidadPedida = entry.value;
      final inventarioDisponible = _getInventarioDisponible(productoId);
      
      if (cantidadPedida > inventarioDisponible) {
        final producto = _productos.firstWhere(
          (p) => p.id == productoId,
          orElse: () => Producto(
            id: productoId,
            nombre: 'Producto #$productoId',
            precio: 0.0,
            unidadMedida: 'unidad',
            activo: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        productosInsuficientes.add(
          '${producto.nombre}: Disponible $inventarioDisponible, Solicitado $cantidadPedida',
        );
      }
    }

    if (productosInsuficientes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Inventario insuficiente:\n${productosInsuficientes.join('\n')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isGuardando = true;
    });

    try {
      final domicilio = double.tryParse(_domicilioController.text.trim());

      // Mapa de precios especiales (solo para productos seleccionados)
      final preciosEspeciales = <int, double>{};
      for (final entry in productosConCantidad) {
        final productoId = entry.key;
        final precio = _getPrecioProducto(productoId);
        preciosEspeciales[productoId] = precio;
      }

      // Descontar inventario antes de crear el pedido
      for (final entry in productosConCantidad) {
        final productoId = entry.key;
        final cantidad = entry.value;
        
        final producto = _productos.firstWhere(
          (p) => p.id == productoId,
          orElse: () => Producto(
            id: productoId,
            nombre: 'Producto',
            precio: 0.0,
            unidadMedida: 'unidad',
            activo: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        
        final nombreProducto = producto.nombre.toLowerCase();
        final categoriaId = producto.categoria?.id;
        Map<String, dynamic> resultado;

        // Si contiene "frito" → descontar de inventario_actual (sucursal_id = 5)
        if (nombreProducto.contains('frito')) {
          resultado = await SupabaseService.descontarInventarioActual(
            sucursalId: 5,
            productoId: productoId,
            cantidad: cantidad,
          );
        }
        // Si contiene "crudo" → descontar de inventario_fabrica
        else if (nombreProducto.contains('crudo')) {
          resultado = await SupabaseService.descontarInventarioFabrica(
            productoId: productoId,
            cantidad: cantidad,
          );
        }
        // Si es bebida (categoria_id = 3) → descontar de inventario_actual (sucursal_id = 5)
        else if (categoriaId == 3) {
          resultado = await SupabaseService.descontarInventarioActual(
            sucursalId: 5,
            productoId: productoId,
            cantidad: cantidad,
          );
        }
        // Por defecto, descontar de inventario_fabrica
        else {
          resultado = await SupabaseService.descontarInventarioFabrica(
            productoId: productoId,
            cantidad: cantidad,
          );
        }

        if (!resultado['exito']) {
          setState(() {
            _isGuardando = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al descontar inventario: ${resultado['mensaje']}'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Recargar inventarios después del descuento
      final inventarioFabrica = await SupabaseService.getInventarioFabricaCompleto();
      final inventarioSucursal5Response = await SupabaseService.client
          .from('inventario_actual')
          .select('producto_id, cantidad')
          .eq('sucursal_id', 5);
      final inventarioSucursal5 = <int, int>{};
      for (final item in inventarioSucursal5Response) {
        inventarioSucursal5[item['producto_id'] as int] = (item['cantidad'] as num?)?.toInt() ?? 0;
      }

      final pedido = await SupabaseService.crearPedidoCliente(
        clienteNombre: _clienteNombreController.text.trim(),
        clienteTelefono:
            _clienteTelefonoController.text.trim().isEmpty
                ? null
                : _clienteTelefonoController.text.trim(),
        direccionEntrega: _direccionController.text.trim(),
        productos: Map.fromEntries(productosConCantidad),
        preciosEspeciales: preciosEspeciales,
        observaciones:
            _observacionesController.text.trim().isEmpty
                ? null
                : _observacionesController.text.trim(),
        metodoPago: _metodoPago,
        domicilio: domicilio != null && domicilio > 0 ? domicilio : null,
        esFiado: _esFiado,
      );

      if (pedido != null && mounted) {
        // Actualizar inventarios en el estado
        setState(() {
          _inventarioFabrica = inventarioFabrica;
          _inventarioSucursal5 = inventarioSucursal5;
        });

        // Limpiar formulario
        _clienteNombreController.clear();
        _clienteTelefonoController.clear();
        _direccionController.clear();
        _observacionesController.clear();
        _domicilioController.clear();
        setState(() {
          _cantidades.clear();
          _preciosEspeciales.clear();
          _metodoPago = 'efectivo';
          _esFiado = false;
          _isGuardando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isOnline
                  ? 'Pedido registrado exitosamente'
                  : 'Pedido guardado localmente. Se enviará cuando haya conexión',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Regresar a la pantalla anterior después de un breve delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _isGuardando = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al crear el pedido'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isGuardando = false;
      });
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
                    .withOpacity(0.98),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border(
                  bottom: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.08),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Registrar Pedido Manual',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                  ),
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _isOnline
                              ? Colors.green.withOpacity(isDark ? 0.25 : 0.12)
                              : primaryColor.withOpacity(isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            _isOnline
                                ? Colors.green.withOpacity(isDark ? 0.4 : 0.25)
                                : primaryColor.withOpacity(isDark ? 0.4 : 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.green : primaryColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isOnline ? Colors.green : primaryColor)
                                    .withOpacity(0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isOnline ? Colors.green : primaryColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 20,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Información del Cliente
                              Text(
                                'Información del Cliente',
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

                              // Nombre del Cliente
                              TextFormField(
                                controller: _clienteNombreController,
                                decoration: InputDecoration(
                                  labelText: 'Nombre del Cliente *',
                                  hintText: 'Ingrese el nombre del cliente',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                ),
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'El nombre del cliente es requerido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Teléfono del Cliente
                              TextFormField(
                                controller: _clienteTelefonoController,
                                decoration: InputDecoration(
                                  labelText: 'Teléfono (Opcional)',
                                  hintText: 'Ingrese el teléfono del cliente',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                ),
                                keyboardType: TextInputType.phone,
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Dirección de Entrega
                              TextFormField(
                                controller: _direccionController,
                                decoration: InputDecoration(
                                  labelText: 'Dirección de Entrega *',
                                  hintText: 'Ingrese la dirección de entrega',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                ),
                                maxLines: 2,
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'La dirección de entrega es requerida';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Valor del Domicilio
                              TextFormField(
                                controller: _domicilioController,
                                decoration: InputDecoration(
                                  labelText: 'Valor del Domicilio (Opcional)',
                                  hintText: 'Ingrese el valor del domicilio',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                  prefixText: '\$ ',
                                ),
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                                onChanged:
                                    (_) => setState(
                                      () {},
                                    ), // Para actualizar el total
                              ),
                              const SizedBox(height: 16),

                              // Método de Pago
                              Text(
                                'Método de Pago',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  _buildPaymentMethodChip(
                                    isDark: isDark,
                                    label: 'Efectivo',
                                    value: 'efectivo',
                                    selectedValue: _metodoPago,
                                    onSelected: (value) {
                                      setState(() {
                                        _metodoPago = value;
                                      });
                                    },
                                  ),
                                  _buildPaymentMethodChip(
                                    isDark: isDark,
                                    label: 'Tarjeta',
                                    value: 'tarjeta',
                                    selectedValue: _metodoPago,
                                    onSelected: (value) {
                                      setState(() {
                                        _metodoPago = value;
                                      });
                                    },
                                  ),
                                  _buildPaymentMethodChip(
                                    isDark: isDark,
                                    label: 'Transferencia',
                                    value: 'transferencia',
                                    selectedValue: _metodoPago,
                                    onSelected: (value) {
                                      setState(() {
                                        _metodoPago = value;
                                      });
                                    },
                                  ),
                                  _buildPaymentMethodChip(
                                    isDark: isDark,
                                    label: 'Mixto',
                                    value: 'mixto',
                                    selectedValue: _metodoPago,
                                    onSelected: (value) {
                                      setState(() {
                                        _metodoPago = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Pedido Fiado
                              Text(
                                'Pedido Fiado?',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildPaymentMethodChip(
                                    isDark: isDark,
                                    label: 'Sí',
                                    value: 'si',
                                    selectedValue: _esFiado ? 'si' : 'no',
                                    onSelected: (value) {
                                      setState(() {
                                        _esFiado = value == 'si';
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildPaymentMethodChip(
                                    isDark: isDark,
                                    label: 'No',
                                    value: 'no',
                                    selectedValue: _esFiado ? 'si' : 'no',
                                    onSelected: (value) {
                                      setState(() {
                                        _esFiado = value == 'si';
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Observaciones
                              TextFormField(
                                controller: _observacionesController,
                                decoration: InputDecoration(
                                  labelText: 'Observaciones (Opcional)',
                                  hintText: 'Notas adicionales sobre el pedido',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                ),
                                maxLines: 3,
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Productos
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

                              // Barra de búsqueda
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
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: isDark
                                          ? const Color(0xFF78716C)
                                          : const Color(0xFF78716C),
                                    ),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.clear,
                                              color: isDark
                                                  ? const Color(0xFF78716C)
                                                  : const Color(0xFF78716C),
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Filtro de categorías
                              _buildCategoryFilter(
                                isDark: isDark,
                                primaryColor: primaryColor,
                                isSmallScreen: isSmallScreen,
                              ),
                              const SizedBox(height: 16),

                              // Lista de Productos
                              ..._getProductosFiltrados().map((producto) {
                                final cantidad = _cantidades[producto.id] ?? 0;
                                final precio = _getPrecioProducto(producto.id);
                                final subtotal = precio * cantidad;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? const Color(0xFF2D211A)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? Colors.white.withOpacity(0.08)
                                              : Colors.black.withOpacity(0.08),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          isDark ? 0.25 : 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Fila 1: Nombre del producto y controles de cantidad
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              producto.nombre,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1B130D,
                                                        ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Controles de cantidad
                                          Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  isDark
                                                      ? const Color(0xFF2F2218)
                                                      : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                            .withOpacity(0.1)
                                                        : Colors.black
                                                            .withOpacity(0.1),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  onPressed:
                                                      () => _decrementProduct(
                                                        producto.id,
                                                      ),
                                                  icon: Icon(
                                                    Icons.remove,
                                                    size: 18,
                                                    color:
                                                        isDark
                                                            ? Colors.white
                                                                .withOpacity(
                                                                  0.6,
                                                                )
                                                            : Colors.black
                                                                .withOpacity(
                                                                  0.6,
                                                                ),
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                SizedBox(
                                                  width: 50,
                                                  child: TextField(
                                                    key: ValueKey(
                                                      'manual_qty_${producto.id}',
                                                    ),
                                                    controller:
                                                        _getOrCreateController(
                                                          producto.id,
                                                        ),
                                                    focusNode:
                                                        _getOrCreateCantidadFocusNode(
                                                          producto.id,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF1B130D,
                                                              ),
                                                    ),
                                                    decoration: InputDecoration(
                                                      border: InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                      isDense: true,
                                                    ),
                                                    onChanged:
                                                        (value) =>
                                                            _onCantidadChanged(
                                                              producto.id,
                                                              value,
                                                            ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed:
                                                      () => _incrementProduct(
                                                        producto.id,
                                                      ),
                                                  icon: Icon(
                                                    Icons.add,
                                                    size: 18,
                                                    color: primaryColor,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Fila 2: Precio y Stock
                                      Row(
                                        children: [
                                          Text(
                                            _formatCurrency(precio),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
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
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getInventarioDisponible(producto.id) > 0
                                                  ? Colors.green.withOpacity(isDark ? 0.2 : 0.1)
                                                  : Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: _getInventarioDisponible(producto.id) > 0
                                                    ? Colors.green.withOpacity(0.3)
                                                    : Colors.red.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              'Stock: ${_getInventarioDisponible(producto.id)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _getInventarioDisponible(producto.id) > 0
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Fila 3: Campo de precio especial
                                      Row(
                                        children: [
                                          Text(
                                            'Precio especial:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  isDark
                                                      ? const Color(0xFFA8A29E)
                                                      : const Color(0xFF78716C),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: TextField(
                                              key: ValueKey(
                                                'manual_price_${producto.id}',
                                              ),
                                              controller:
                                                  _getOrCreatePrecioController(
                                                    producto.id,
                                                  ),
                                              focusNode:
                                                  _getOrCreatePrecioFocusNode(
                                                    producto.id,
                                                  ),
                                              textAlign: TextAlign.left,
                                              keyboardType:
                                                  TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1B130D,
                                                        ),
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'Precio base',
                                                prefixText: '\$ ',
                                                border:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                            8,
                                                          ),
                                                ),
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                      horizontal:
                                                          10,
                                                      vertical:
                                                          8,
                                                    ),
                                              ),
                                              onChanged:
                                                  (v) =>
                                                      _onPrecioChanged(
                                                        producto.id,
                                                        v,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (cantidad > 0) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Subtotal: ${_formatCurrency(subtotal)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
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
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),

                              const SizedBox(height: 24),

                              // Resumen
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.08)
                                            : Colors.black.withOpacity(0.08),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                        isDark ? 0.25 : 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total Items: ${_calcularTotalItems()}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                isDark
                                                    ? const Color(0xFF9A6C4C)
                                                    : const Color(0xFF9A6C4C),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (double.tryParse(
                                              _domicilioController.text.trim(),
                                            ) !=
                                            null &&
                                        (double.tryParse(
                                                  _domicilioController.text
                                                      .trim(),
                                                ) ??
                                                0) >
                                            0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Domicilio:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  isDark
                                                      ? const Color(0xFF9A6C4C)
                                                      : const Color(0xFF9A6C4C),
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(
                                              double.tryParse(
                                                    _domicilioController.text
                                                        .trim(),
                                                  ) ??
                                                  0,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                                  isDark
                                                      ? const Color(0xFF9A6C4C)
                                                      : const Color(0xFF9A6C4C),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total:',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(_calcularTotal()),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                height: 100,
                              ), // Space for bottom button
                            ],
                          ),
                        ),
                      ),
            ),

            // Bottom Button
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
                    .withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isGuardando ? null : _guardarPedido,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 8,
                    shadowColor: primaryColor.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isGuardando
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
                          : const Text(
                            'Guardar Pedido',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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

  Widget _buildPaymentMethodChip({
    required bool isDark,
    required String label,
    required String value,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    final isSelected = value == selectedValue;
    final primaryColor = const Color(0xFFEC6D13);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onSelected(value);
        }
      },
      selectedColor: primaryColor.withOpacity(isDark ? 0.3 : 0.2),
      backgroundColor:
          isDark ? const Color(0xFF2D211A) : Colors.grey.withOpacity(0.1),
      labelStyle: TextStyle(
        color:
            isSelected
                ? primaryColor
                : (isDark ? Colors.white : const Color(0xFF1B130D)),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildCategoryFilter({
    required bool isDark,
    required Color primaryColor,
    required bool isSmallScreen,
  }) {
    final categoriasDisponibles = _getCategoriasDisponiblesEnProductos();

    // Si solo hay una "categoría" (o ninguna), no mostramos filtro
    if (categoriasDisponibles.length <= 1) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filtrar por categoría',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade300 : const Color(0xFF9A6C4C),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Todos'),
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
              const SizedBox(width: 8),
              ..._getCategoriasDisponiblesEnProductos().map((categoriaId) {
                final isUncategorized = categoriaId == null;
                final chipId = isUncategorized ? 0 : categoriaId;

                // Obtener el nombre de la categoría
                String label;
                if (isUncategorized) {
                  label = 'Sin categoría';
                } else {
                  final categoria = _categoriasMap[categoriaId];
                  if (categoria != null) {
                    label = categoria.nombre;
                  } else {
                    label = 'Categoría';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
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
    );
  }
}
