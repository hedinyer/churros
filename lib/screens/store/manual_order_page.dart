import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/producto.dart';
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
  Map<int, int> _cantidades = {}; // productoId -> cantidad
  Map<int, TextEditingController> _cantidadControllers =
      {}; // productoId -> controller
  String _metodoPago = 'efectivo';
  bool _isLoading = true;
  bool _isGuardando = false;
  bool _isOnline = true;

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
    // Dispose de todos los controllers de cantidad
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
      final productos = await SupabaseService.getProductosActivos();
      setState(() {
        _productos = productos;
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

  double _calcularTotal() {
    double total = 0.0;
    for (final entry in _cantidades.entries) {
      final producto = _productos.firstWhere(
        (p) => p.id == entry.key,
        orElse:
            () => Producto(
              id: entry.key,
              nombre: 'Producto',
              precio: 0.0,
              unidadMedida: 'unidad',
              activo: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      );
      total += producto.precio * entry.value;
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

    setState(() {
      _isGuardando = true;
    });

    try {
      final domicilio = double.tryParse(_domicilioController.text.trim());

      final pedido = await SupabaseService.crearPedidoCliente(
        clienteNombre: _clienteNombreController.text.trim(),
        clienteTelefono:
            _clienteTelefonoController.text.trim().isEmpty
                ? null
                : _clienteTelefonoController.text.trim(),
        direccionEntrega: _direccionController.text.trim(),
        productos: Map.fromEntries(productosConCantidad),
        observaciones:
            _observacionesController.text.trim().isEmpty
                ? null
                : _observacionesController.text.trim(),
        metodoPago: _metodoPago,
        domicilio: domicilio != null && domicilio > 0 ? domicilio : null,
      );

      if (pedido != null && mounted) {
        // Limpiar formulario
        _clienteNombreController.clear();
        _clienteTelefonoController.clear();
        _direccionController.clear();
        _observacionesController.clear();
        _domicilioController.clear();
        setState(() {
          _cantidades.clear();
          _metodoPago = 'efectivo';
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
                        fontSize: 8,
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
                            fontSize: 8,
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
                                  fontSize: 8,
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
                                  fontSize: 8,
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
                                  fontSize: 8,
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
                                final precio = producto.precio;
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
                                                    fontSize: 8,
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
                                                  _formatCurrency(
                                                    producto.precio,
                                                  ),
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
                                                ),
                                              ],
                                            ),
                                          ),
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
                                                        _getOrCreateController(
                                                          producto.id,
                                                        ),
                                                    textAlign: TextAlign.center,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    style: TextStyle(
                                                      fontSize: 8,
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
                                      if (cantidad > 0) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Subtotal: ${_formatCurrency(subtotal)}',
                                              style: TextStyle(
                                                fontSize: 8,
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
                                            fontSize: 8,
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
                                              fontSize: 8,
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
                                              fontSize: 8,
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
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(_calcularTotal()),
                                          style: TextStyle(
                                            fontSize: 8,
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
                              fontSize: 8,
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
