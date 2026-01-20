import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/producto.dart';
import '../../services/supabase_service.dart';

class RecurrentOrdersPage extends StatefulWidget {
  const RecurrentOrdersPage({super.key});

  @override
  State<RecurrentOrdersPage> createState() => _RecurrentOrdersPageState();
}

class _RecurrentOrdersPageState extends State<RecurrentOrdersPage> {
  // Lista de clientes recurrentes basada en la imagen proporcionada
  final List<String> _clientesRecurrentes = [
    'PARQUE',
    'TIENDA NATUR',
    'ALCALDIA',
    'ZAPATOCA',
    'PIJAMAS',
    'TULA PEPO',
    'MARIELA',
    'BUÑUELOS',
    'JOSE CENTRO',
    'LA VIRGEN',
    'PROVINCIA',
    'CLIENTE 18#37',
    'QUE BURRADA',
    'FRITOS GIRON',
    'RUITOQUE',
    'CODISEL',
    'ESTIBEN',
    'ABASTOS',
    'CLIENTE CALLE',
    'CASET S.FRANCI',
    'Caseta UIS',
    'satelite',
    'La ñapa',
    'Reinaldo',
    'Lavadero',
  ];

  List<Producto> _productos = [];
  Map<int, int> _cantidades = {}; // productoId -> cantidad
  Map<int, TextEditingController> _cantidadControllers =
      {}; // productoId -> controller
  Map<int, TextEditingController> _precioControllers =
      {}; // productoId -> precio especial
  Map<int, double> _preciosEspeciales =
      {}; // productoId -> precio especial por cliente
  String? _clienteSeleccionado;
  String _metodoPago = 'efectivo';
  bool _isLoading = true;
  bool _isGuardando = false;
  final _direccionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _direccionController.dispose();
    for (var controller in _cantidadControllers.values) {
      controller.dispose();
    }
    for (var controller in _precioControllers.values) {
      controller.dispose();
    }
    _cantidadControllers.clear();
    _precioControllers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final productos = await SupabaseService.getProductosActivos();

      // Filtrar productos: churros congelados y fritos
      // - categoria_id = 1 o 4: nombre contiene "crudo" y unidad_medida = "bandeja" (congelados)
      // - categoria_id = 5: sin restricciones adicionales
      // - También incluir productos que contengan "frito" en el nombre
      final productosFiltrados =
          productos.where((producto) {
            final categoriaId = producto.categoria?.id;
            final nombre = producto.nombre.toLowerCase();
            final unidadMedida = producto.unidadMedida.toLowerCase();

            // Si es categoría 5, se incluye sin restricciones
            if (categoriaId == 5) {
              return true;
            }

            // Para categorías 1 y 4, verificar si es churro crudo (congelado)
            if (categoriaId == 1 || categoriaId == 4) {
              final contieneCrudo = nombre.contains('crudo');
              final esBandeja = unidadMedida == 'bandeja';
              if (contieneCrudo && esBandeja) {
                return true;
              }
            }

            // Incluir productos que contengan "frito" en el nombre
            if (nombre.contains('frito')) {
              return true;
            }

            return false;
          }).toList();

      // Inicializar controllers
      final cantidadControllers = <int, TextEditingController>{};
      final precioControllers = <int, TextEditingController>{};
      for (final producto in productosFiltrados) {
        cantidadControllers[producto.id] = TextEditingController(text: '0');
        precioControllers[producto.id] = TextEditingController(
          text: producto.precio.toStringAsFixed(0),
        );
      }

      setState(() {
        _productos = productosFiltrados;
        _cantidadControllers = cantidadControllers;
        _precioControllers = precioControllers;
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

  void _onPrecioChanged(int productoId, String value) {
    final precio = double.tryParse(value) ?? 0.0;
    if (precio >= 0) {
      setState(() {
        _preciosEspeciales[productoId] = precio;
      });
    }
  }

  TextEditingController _getOrCreateCantidadController(int productoId) {
    return _cantidadControllers[productoId]!;
  }

  TextEditingController _getOrCreatePrecioController(int productoId) {
    return _precioControllers[productoId]!;
  }

  double _getPrecioProducto(int productoId) {
    // Si hay un precio especial configurado, usarlo; si no, usar el precio del producto
    if (_preciosEspeciales.containsKey(productoId) &&
        _preciosEspeciales[productoId]! > 0) {
      return _preciosEspeciales[productoId]!;
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

  double _calcularTotal() {
    double total = 0.0;
    for (final entry in _cantidades.entries) {
      final precio = _getPrecioProducto(entry.key);
      total += precio * entry.value;
    }
    return total;
  }

  int _calcularTotalItems() {
    return _cantidades.values.fold(0, (sum, cantidad) => sum + cantidad);
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
  }

  Future<void> _guardarPedido() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
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

    setState(() {
      _isGuardando = true;
    });

    try {
      // Crear mapa de productos con precios especiales
      final productosConPrecios = <int, int>{};
      final preciosEspecialesMap = <int, double>{};

      for (final entry in productosConCantidad) {
        productosConPrecios[entry.key] = entry.value;
        final precioEspecial = _getPrecioProducto(entry.key);
        preciosEspecialesMap[entry.key] = precioEspecial;
      }

      // Crear pedido usando el servicio, pero con precios especiales
      final pedido = await _crearPedidoConPreciosEspeciales(
        clienteNombre: _clienteSeleccionado!,
        direccionEntrega:
            _direccionController.text.trim().isEmpty
                ? 'Dirección no especificada'
                : _direccionController.text.trim(),
        productos: productosConPrecios,
        preciosEspeciales: preciosEspecialesMap,
        metodoPago: _metodoPago,
      );

      if (pedido != null && mounted) {
        // Limpiar formulario
        _direccionController.clear();
        setState(() {
          _cantidades.clear();
          _preciosEspeciales.clear();
          _clienteSeleccionado = null;
          _metodoPago = 'efectivo';
          _isGuardando = false;
        });

        // Resetear precios a valores por defecto
        for (final producto in _productos) {
          _precioControllers[producto.id]?.text = producto.precio
              .toStringAsFixed(0);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido registrado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
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

  Future<dynamic> _crearPedidoConPreciosEspeciales({
    required String clienteNombre,
    required String direccionEntrega,
    required Map<int, int> productos,
    required Map<int, double> preciosEspeciales,
    required String metodoPago,
  }) async {
    try {
      final hasConnection = await SupabaseService.client
          .from('users')
          .select()
          .limit(1)
          .maybeSingle()
          .then((_) => true)
          .catchError((_) => false);

      final now = DateTime.now();

      // Obtener productos para validar
      final productosActivos = await SupabaseService.getProductosActivos();
      final productosMap = {for (var p in productosActivos) p.id: p};

      // Calcular total de items y total usando precios especiales
      int totalItems = 0;
      double total = 0.0;
      final detallesData = <Map<String, dynamic>>[];

      for (final entry in productos.entries) {
        final producto = productosMap[entry.key];
        if (producto == null || entry.value <= 0) continue;

        final cantidad = entry.value;
        final precioBase = producto.precio;
        // Usar precio especial si está disponible y es diferente del precio base
        final precioEspecial = preciosEspeciales[entry.key];
        final tienePrecioEspecial =
            precioEspecial != null &&
            precioEspecial > 0 &&
            precioEspecial != precioBase;
        final precioUnitario =
            tienePrecioEspecial ? precioEspecial : precioBase;
        final precioTotal = precioUnitario * cantidad;

        totalItems += cantidad;
        total += precioTotal;

        detallesData.add({
          'producto_id': producto.id,
          'cantidad': cantidad,
          'precio_unitario': precioUnitario,
          'precio_base': precioBase,
          'precio_especial': tienePrecioEspecial ? precioEspecial : null,
          'precio_total': precioTotal,
          'tiene_precio_especial': tienePrecioEspecial,
          'estado': 'pendiente',
        });
      }

      if (totalItems == 0) {
        print('No hay productos en el pedido');
        return null;
      }

      // Crear el pedido en la tabla de pedidos recurrentes
      final pedidoData = {
        'cliente_nombre': clienteNombre,
        'cliente_telefono': null,
        'direccion_entrega': direccionEntrega,
        'fecha_pedido': now.toIso8601String().split('T')[0],
        'hora_pedido':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'total_items': totalItems,
        'total': total,
        'estado': 'pendiente',
        'numero_pedido': _generatePedidoClienteNumber(hasConnection),
        'observaciones': 'Pedido recurrente - Precios especiales aplicados',
        'metodo_pago': metodoPago,
        'sincronizado': hasConnection,
      };

      // Insertar el pedido en la tabla de pedidos recurrentes
      final pedidoResponse =
          await SupabaseService.client
              .from('pedidos_recurrentes')
              .insert(pedidoData)
              .select()
              .single();

      final pedidoId = pedidoResponse['id'] as int;

      // Insertar los detalles del pedido con precios especiales
      final detallesConPedidoId =
          detallesData.map((detalle) {
            return {...detalle, 'pedido_id': pedidoId};
          }).toList();

      await SupabaseService.client
          .from('pedido_recurrente_detalles')
          .insert(detallesConPedidoId);

      return pedidoResponse;
    } catch (e) {
      print('Error creando pedido recurrente con precios especiales: $e');
      return null;
    }
  }

  String _generatePedidoClienteNumber(bool isOnline) {
    if (!isOnline) {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      return 'LOCAL-RECURRENTE-$timestamp';
    }

    final now = DateTime.now();
    final fecha =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'PED-RECURRENTE-$fecha-$hora';
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
                      'Pedidos Recurrentes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
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
                              // Selección de Cliente
                              Text(
                                'Cliente Recurrente',
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? Colors.white.withOpacity(0.1)
                                            : Colors.black.withOpacity(0.1),
                                  ),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: _clienteSeleccionado,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  hint: Text(
                                    'Selecciona un cliente',
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                    ),
                                  ),
                                  dropdownColor:
                                      isDark
                                          ? const Color(0xFF2D211A)
                                          : Colors.white,
                                  style: TextStyle(
                                    color:
                                        isDark
                                            ? Colors.white
                                            : const Color(0xFF1B130D),
                                  ),
                                  items:
                                      _clientesRecurrentes.map((cliente) {
                                        return DropdownMenuItem<String>(
                                          value: cliente,
                                          child: Text(cliente),
                                        );
                                      }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _clienteSeleccionado = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Selecciona un cliente';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Dirección de Entrega
                              Text(
                                'Dirección de Entrega',
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
                              TextFormField(
                                controller: _direccionController,
                                decoration: InputDecoration(
                                  labelText: 'Dirección (Opcional)',
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
                              ),
                              const SizedBox(height: 24),

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
                              const SizedBox(height: 32),

                              // Productos
                              Text(
                                'Productos (Churros Congelados y Fritos)',
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

                              // Lista de Productos
                              ..._productos.map((producto) {
                                final cantidad = _cantidades[producto.id] ?? 0;
                                final precio = _getPrecioProducto(producto.id);
                                final subtotal = precio * cantidad;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color:
                                        isDark
                                            ? const Color(0xFF2D211A)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          isDark
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.black.withOpacity(0.05),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
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
                                                            : const Color(
                                                              0xFF1B130D,
                                                            ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Precio base: ${_formatCurrency(producto.precio)}',
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
                                      const SizedBox(height: 12),
                                      // Precio Especial
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Precio Especial:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    isDark
                                                        ? Colors.white70
                                                        : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 100,
                                            child: TextField(
                                              controller:
                                                  _getOrCreatePrecioController(
                                                    producto.id,
                                                  ),
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    isDark
                                                        ? Colors.white
                                                        : const Color(
                                                          0xFF1B130D,
                                                        ),
                                              ),
                                              decoration: InputDecoration(
                                                prefixText: '\$ ',
                                                prefixStyle: TextStyle(
                                                  color:
                                                      isDark
                                                          ? Colors.white70
                                                          : Colors.black87,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                filled: true,
                                                fillColor:
                                                    isDark
                                                        ? const Color(
                                                          0xFF2F2218,
                                                        )
                                                        : Colors.grey[100],
                                              ),
                                              onChanged:
                                                  (value) => _onPrecioChanged(
                                                    producto.id,
                                                    value,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Controles de cantidad
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Cantidad:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1B130D),
                                            ),
                                          ),
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
                                                  width: 60,
                                                  child: TextField(
                                                    controller:
                                                        _getOrCreateCantidadController(
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
                                                    decoration:
                                                        const InputDecoration(
                                                          border:
                                                              InputBorder.none,
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
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF2D211A)
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total: ${_formatCurrency(_calcularTotal())}',
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
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
                            'Guardar Pedido Recurrente',
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
}
