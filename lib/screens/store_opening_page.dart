import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../models/producto.dart';
import '../models/sucursal.dart';
import '../models/apertura_dia.dart';
import '../models/user.dart';
import 'dashboard_page.dart';

class StoreOpeningPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const StoreOpeningPage({super.key, required this.currentUser});

  @override
  State<StoreOpeningPage> createState() => _StoreOpeningPageState();
}

class _StoreOpeningPageState extends State<StoreOpeningPage> {
  // Estado de carga y datos
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Datos de la base de datos
  Sucursal? _sucursal;
  List<Producto> _productos = [];
  AperturaDia? _aperturaActual;

  // Inventario actual (productoId -> cantidad)
  final Map<int, int> _inventario = {};

  // Usuario actual
  late final int _currentUserId;
  late final int? _currentUserSucursalId;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUser['id'] as int;
    _currentUserSucursalId = widget.currentUser['sucursal'] as int?;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verificar que el usuario tenga una sucursal asignada
      if (_currentUserSucursalId == null) {
        throw Exception('El usuario no tiene una sucursal asignada');
      }

      // Cargar sucursal del usuario
      final sucursalId = _currentUserSucursalId!;
      _sucursal = await SupabaseService.getSucursalById(sucursalId);
      if (_sucursal == null) {
        throw Exception('No se pudo cargar la información de la sucursal');
      }

      // Cargar productos
      _productos = await SupabaseService.getProductosActivos();
      if (_productos.isEmpty) {
        throw Exception('No se pudieron cargar los productos');
      }

      // Cargar inventario actual de la sucursal
      final inventarioActual = await SupabaseService.getInventarioActual(
        _sucursal!.id,
      );

      // Inicializar inventario con valores actuales o por defecto
      for (final producto in _productos) {
        _inventario[producto.id] = inventarioActual[producto.id] ?? 0;
      }

      // Verificar si ya existe una apertura para hoy
      _aperturaActual = await SupabaseService.getAperturaDiaActual(
        _sucursal!.id,
      );

      if (_aperturaActual != null) {
        // Si ya existe una apertura, mostrar mensaje y navegar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya existe una apertura para hoy'),
              backgroundColor: Colors.orange,
            ),
          );
          // TODO: Navegar a la pantalla principal del POS
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      print('Error cargando datos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _incrementItem(int productoId) {
    setState(() {
      _inventario[productoId] = (_inventario[productoId] ?? 0) + 1;
    });
  }

  void _decrementItem(int productoId) {
    setState(() {
      final currentValue = _inventario[productoId] ?? 0;
      if (currentValue > 0) {
        _inventario[productoId] = currentValue - 1;
      }
    });
  }

  void _updateItemQuantity(int productoId, String value) {
    setState(() {
      final quantity = int.tryParse(value) ?? 0;
      // Asegurar que la cantidad no sea negativa
      _inventario[productoId] = quantity < 0 ? 0 : quantity;
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
    final day = now.day;
    final month = months[now.month - 1];

    return '$weekday, $day $month';
  }

  int get _totalItems =>
      _inventario.values.fold(0, (sum, quantity) => sum + quantity);

  Future<void> _openStore() async {
    if (_sucursal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Error: No se pudo obtener la información de la sucursal',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC6D13).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Color(0xFFEC6D13),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  '¿Confirmar apertura?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Estás a punto de iniciar el día con $_totalItems artículos en total. Esta acción no se puede deshacer.',
              style: TextStyle(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFA8A29E)
                        : const Color(0xFF78716C),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : const Color(0xFF1C1917),
                ),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC6D13),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
    );

    if (shouldOpen == true) {
      setState(() {
        _isSaving = true;
      });

      try {
        // Asegurarse de que todos los productos estén en el inventario (incluso con 0)
        final inventarioCompleto = <int, int>{};
        for (final producto in _productos) {
          inventarioCompleto[producto.id] = _inventario[producto.id] ?? 0;
        }

        print(
          'Guardando inventario con ${inventarioCompleto.length} productos',
        );

        // Crear la apertura del día
        AperturaDia? apertura;
        try {
          apertura = await SupabaseService.crearAperturaDia(
            sucursalId: _sucursal!.id,
            usuarioAperturaId: _currentUserId,
            totalArticulos: _totalItems,
          );
        } catch (e) {
          print('Error al crear apertura: $e');
          throw Exception('Error al crear la apertura del día: $e');
        }

        if (apertura == null) {
          throw Exception(
            'No se pudo crear la apertura del día. Verifica que no exista una apertura previa para hoy.',
          );
        }

        print('Apertura creada/obtenida con ID: ${apertura.id}');

        // Guardar el inventario inicial
        final inventarioGuardado =
            await SupabaseService.guardarInventarioInicial(
              aperturaId: apertura.id,
              inventario: inventarioCompleto,
            );

        if (!inventarioGuardado) {
          throw Exception('No se pudo guardar el inventario inicial');
        }

        print('Inventario inicial guardado correctamente');

        // Actualizar el inventario actual
        final inventarioActualizado =
            await SupabaseService.actualizarInventarioActual(
              sucursalId: _sucursal!.id,
              inventario: inventarioCompleto,
            );

        if (!inventarioActualizado) {
          print(
            'Advertencia: No se pudo actualizar el inventario actual, pero la apertura se creó correctamente',
          );
        } else {
          print('Inventario actual actualizado correctamente');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Tienda abierta exitosamente!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navegar al dashboard
          final appUser = AppUser.fromJson(widget.currentUser);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      DashboardPage(sucursal: _sucursal!, currentUser: appUser),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al abrir la tienda: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final screenWidth = screenSize.width;
    final isSmallScreen = screenWidth < 600;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color:
                              isDark ? Colors.white : const Color(0xFF1C1917),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // POS Name
                      Expanded(
                        child: Text(
                          _sucursal?.nombre ?? 'Sucursal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF1C1917),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sync Status
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.cloud_sync,
                          color: primaryColor,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline Section
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apertura del Día',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getFormattedDate(),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1C1917),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ingresa el inventario inicial para comenzar.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      isDark
                                          ? const Color(0xFFA8A29E)
                                          : const Color(0xFF78716C),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Loading State
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        // Error State
                        else if (_errorMessage != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error al cargar los datos',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF1C1917),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadData,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Reintentar'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        // Products
                        else
                          ..._productos.map((producto) {
                            final quantity = _inventario[producto.id] ?? 0;
                            final categoria = producto.categoria;

                            IconData iconData;
                            switch (categoria?.icono) {
                              case 'bakery_dining':
                                iconData = Icons.bakery_dining;
                                break;
                              case 'donut_small':
                                iconData = Icons.donut_small;
                                break;
                              case 'local_cafe':
                                iconData = Icons.local_cafe;
                                break;
                              default:
                                iconData = Icons.inventory;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(20),
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
                                children: [
                                  // Item Header
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: primaryColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          iconData,
                                          color: primaryColor,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
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
                                                        : const Color(
                                                          0xFF1C1917,
                                                        ),
                                              ),
                                            ),
                                            Text(
                                              categoria?.nombre ??
                                                  'Sin categoría',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFFA8A29E,
                                                        )
                                                        : const Color(
                                                          0xFF78716C,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Stepper Input
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(0xFF221810)
                                              : const Color(0xFFF8F7F6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        // Decrement Button
                                        SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed:
                                                quantity > 0
                                                    ? () => _decrementItem(
                                                      producto.id,
                                                    )
                                                    : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  isDark
                                                      ? const Color(0xFF2C2018)
                                                      : Colors.white,
                                              foregroundColor:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1C1917),
                                              elevation: 2,
                                              shadowColor: Colors.black
                                                  .withOpacity(0.1),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding: EdgeInsets.zero,
                                              disabledBackgroundColor:
                                                  isDark
                                                      ? const Color(0xFF1C1917)
                                                      : const Color(0xFFE7E5E4),
                                              disabledForegroundColor:
                                                  isDark
                                                      ? const Color(0xFF78716C)
                                                      : const Color(0xFFA8A29E),
                                            ),
                                            child: const Icon(
                                              Icons.remove,
                                              size: 28,
                                            ),
                                          ),
                                        ),

                                        // Quantity Input
                                        Expanded(
                                          child: TextFormField(
                                            key: ValueKey(
                                              'quantity_${producto.id}_$quantity',
                                            ),
                                            initialValue: quantity.toString(),
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  isDark
                                                      ? Colors.white
                                                      : const Color(0xFF1C1917),
                                            ),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged:
                                                (value) => _updateItemQuantity(
                                                  producto.id,
                                                  value,
                                                ),
                                          ),
                                        ),

                                        // Increment Button
                                        SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: ElevatedButton(
                                            onPressed:
                                                () =>
                                                    _incrementItem(producto.id),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              elevation: 4,
                                              shadowColor: primaryColor
                                                  .withOpacity(0.3),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding: EdgeInsets.zero,
                                            ),
                                            child: const Icon(
                                              Icons.add,
                                              size: 28,
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
                      ],
                    ),
                  ),
                ),

                // Bottom spacing for fixed button
                const SizedBox(height: 100),
              ],
            ),
          ),

          // Fixed Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
                vertical: 24,
              ),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? const Color(0xFF221810).withOpacity(0.8)
                        : const Color(0xFFF8F7F6).withOpacity(0.8),
                border: Border(
                  top: BorderSide(
                    color:
                        isDark
                            ? const Color(0xFF44403C)
                            : const Color(0xFFE7E5E4),
                  ),
                ),
              ),
              child: ElevatedButton(
                onPressed: _isLoading || _isSaving ? null : _openStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.3),
                  disabledBackgroundColor: primaryColor.withOpacity(0.6),
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Abrir Punto de Venta',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 24),
                          ],
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
