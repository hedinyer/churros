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
      final sucursalId = _currentUserSucursalId;
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
    final dialogMediaQuery = MediaQuery.of(context);
    // Deshabilitar escalado de texto del sistema - usar siempre 1.0
    final dialogTextScale = 1.0;
    final dialogScreenWidth = dialogMediaQuery.size.width;
    final dialogIsSmallScreen = dialogScreenWidth < 600;
    final dialogPadding =
        (dialogIsSmallScreen ? 16.0 : 24.0) * dialogTextScale.clamp(0.9, 1.1);
    final dialogTitleSize = (20.0 * dialogTextScale).clamp(18.0, 24.0);
    final dialogBodySize = (16.0 * dialogTextScale).clamp(14.0, 20.0);
    final dialogSpacing = (16.0 * dialogTextScale).clamp(12.0, 20.0);
    final dialogPrimaryColor = const Color(0xFFEC6D13);

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor:
              isDarkDialog ? const Color(0xFF2C2018) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.all(dialogPadding),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all((8 * dialogTextScale).clamp(6.0, 10.0)),
                decoration: BoxDecoration(
                  color: dialogPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: dialogPrimaryColor,
                  size: (28 * dialogTextScale).clamp(24.0, 32.0),
                ),
              ),
              SizedBox(width: dialogSpacing),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¿Confirmar apertura?',
                    style: TextStyle(
                      fontSize: dialogTitleSize,
                      fontWeight: FontWeight.bold,
                      color:
                          isDarkDialog ? Colors.white : const Color(0xFF1C1917),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          content: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Estás a punto de iniciar el día con $_totalItems artículos en total. Esta acción no se puede deshacer.',
              style: TextStyle(
                fontSize: dialogBodySize,
                color:
                    isDarkDialog
                        ? const Color(0xFFA8A29E)
                        : const Color(0xFF78716C),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkDialog ? Colors.white : const Color(0xFF1C1917),
                padding: EdgeInsets.symmetric(
                  horizontal: (16 * dialogTextScale).clamp(12.0, 20.0),
                  vertical: (12 * dialogTextScale).clamp(8.0, 16.0),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Cancelar',
                  style: TextStyle(fontSize: dialogBodySize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogPrimaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: (16 * dialogTextScale).clamp(12.0, 20.0),
                  vertical: (12 * dialogTextScale).clamp(8.0, 16.0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Confirmar',
                  style: TextStyle(
                    fontSize: dialogBodySize,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
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
    final extraLargeFontSize = (baseFontSize * 2.0 * textScaleFactor).clamp(
      24.0,
      40.0,
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
        body: Stack(
          children: [
            // Main Content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: paddingHorizontal,
                      vertical: paddingVertical,
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
                            size: (24 * textScaleFactor).clamp(20.0, 28.0),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                            minimumSize: Size(
                              (48 * textScaleFactor).clamp(40.0, 56.0),
                              (48 * textScaleFactor).clamp(40.0, 56.0),
                            ),
                            padding: EdgeInsets.all(
                              (8 * textScaleFactor).clamp(4.0, 12.0),
                            ),
                          ),
                        ),
                        SizedBox(width: spacingMedium),
                        // POS Name
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _sucursal?.nombre ?? 'Sucursal',
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF1C1917),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        SizedBox(width: spacingMedium),
                        // Sync Status
                        Container(
                          width: (48 * textScaleFactor).clamp(40.0, 56.0),
                          height: (48 * textScaleFactor).clamp(40.0, 56.0),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.cloud_sync,
                            color: primaryColor,
                            size: (24 * textScaleFactor).clamp(20.0, 28.0),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Main Content Area
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _isLoading ? 0.3 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: paddingHorizontal,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Headline Section
                            Container(
                              margin: EdgeInsets.only(
                                bottom: spacingMedium * 1.5,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Apertura del Día',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontSize: smallFontSize,
                                        fontWeight: FontWeight.bold,
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
                                        fontSize: extraLargeFontSize,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : const Color(0xFF1C1917),
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
                                      'Ingresa el inventario inicial para comenzar.',
                                      style: TextStyle(
                                        fontSize: bodyFontSize,
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

                            // Error State
                            if (_errorMessage != null)
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
                              ..._productos.map<Widget>((producto) {
                                final quantity = _inventario[producto.id] ?? 0;
                                final categoria = producto.categoria;
                                final stockDisponible =
                                    quantity; // Stock actual en inventario
                                final buttonSize =
                                    (isVerySmallScreen ? 48.0 : 56.0) *
                                    textScaleFactor.clamp(0.9, 1.1);

                                return Container(
                                  margin: EdgeInsets.only(
                                    bottom: spacingMedium,
                                  ),
                                  padding: EdgeInsets.all(
                                    (20 * textScaleFactor).clamp(16.0, 24.0),
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
                                    children: [
                                      // Item Header
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Text(
                                                    producto.nombre,
                                                    style: TextStyle(
                                                      fontSize: titleFontSize,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          isDark
                                                              ? Colors.white
                                                              : const Color(
                                                                0xFF1C1917,
                                                              ),
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                SizedBox(
                                                  height: spacingSmall / 2,
                                                ),
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        alignment:
                                                            Alignment
                                                                .centerLeft,
                                                        child: Text(
                                                          categoria?.nombre ??
                                                              'Sin categoría',
                                                          style: TextStyle(
                                                            fontSize:
                                                                smallFontSize,
                                                            color:
                                                                isDark
                                                                    ? const Color(
                                                                      0xFFA8A29E,
                                                                    )
                                                                    : const Color(
                                                                      0xFF78716C,
                                                                    ),
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: spacingSmall,
                                                    ),
                                                    Container(
                                                      padding: EdgeInsets.symmetric(
                                                        horizontal: (6 *
                                                                textScaleFactor)
                                                            .clamp(4.0, 8.0),
                                                        vertical: (2 *
                                                                textScaleFactor)
                                                            .clamp(2.0, 4.0),
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            stockDisponible > 0
                                                                ? const Color(
                                                                  0xFF10B981,
                                                                ).withOpacity(
                                                                  0.1,
                                                                )
                                                                : Colors.orange
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: FittedBox(
                                                        fit: BoxFit.scaleDown,
                                                        child: Text(
                                                          'Stock: $stockDisponible',
                                                          style: TextStyle(
                                                            fontSize:
                                                                smallFontSize *
                                                                0.9,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                stockDisponible >
                                                                        0
                                                                    ? const Color(
                                                                      0xFF10B981,
                                                                    )
                                                                    : Colors
                                                                        .orange,
                                                          ),
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: spacingMedium),

                                      // Stepper Input
                                      Container(
                                        padding: EdgeInsets.all(
                                          (8 * textScaleFactor).clamp(
                                            6.0,
                                            12.0,
                                          ),
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isDark
                                                  ? const Color(0xFF221810)
                                                  : const Color(0xFFF8F7F6),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Decrement Button
                                            SizedBox(
                                              width: buttonSize,
                                              height: buttonSize,
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
                                                          ? const Color(
                                                            0xFF2C2018,
                                                          )
                                                          : Colors.white,
                                                  foregroundColor:
                                                      isDark
                                                          ? Colors.white
                                                          : const Color(
                                                            0xFF1C1917,
                                                          ),
                                                  elevation: 2,
                                                  shadowColor: Colors.black
                                                      .withOpacity(0.1),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
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
                                                  size: (28 * textScaleFactor)
                                                      .clamp(24.0, 32.0),
                                                ),
                                              ),
                                            ),

                                            // Quantity Input
                                            Expanded(
                                              child: TextFormField(
                                                key: ValueKey(
                                                  'quantity_${producto.id}_$quantity',
                                                ),
                                                initialValue:
                                                    quantity.toString(),
                                                textAlign: TextAlign.center,
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                style: TextStyle(
                                                  fontSize:
                                                      extraLargeFontSize * 0.8,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isDark
                                                          ? Colors.white
                                                          : const Color(
                                                            0xFF1C1917,
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
                                                        _updateItemQuantity(
                                                          producto.id,
                                                          value,
                                                        ),
                                              ),
                                            ),

                                            // Increment Button
                                            SizedBox(
                                              width: buttonSize,
                                              height: buttonSize,
                                              child: ElevatedButton(
                                                onPressed:
                                                    () => _incrementItem(
                                                      producto.id,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryColor,
                                                  foregroundColor: Colors.white,
                                                  elevation: 4,
                                                  shadowColor: primaryColor
                                                      .withOpacity(0.3),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size(
                                                    buttonSize,
                                                    buttonSize,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.add,
                                                  size: (28 * textScaleFactor)
                                                      .clamp(24.0, 32.0),
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
                  ),

                  // Bottom spacing for fixed button
                  SizedBox(height: (100 * textScaleFactor).clamp(80.0, 120.0)),
                ],
              ),
            ),

            // Fixed Bottom Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: paddingHorizontal,
                  right: paddingHorizontal,
                  top: paddingVertical * 2,
                  bottom: mediaQuery.padding.bottom + paddingVertical * 2,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF221810).withOpacity(0.95)
                          : const Color(0xFFF8F7F6).withOpacity(0.95),
                  border: Border(
                    top: BorderSide(
                      color:
                          isDark
                              ? const Color(0xFF44403C)
                              : const Color(0xFFE7E5E4),
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
                child: SizedBox(
                  width: double.infinity,
                  height: (56 * textScaleFactor).clamp(48.0, 64.0),
                  child: ElevatedButton(
                    onPressed: _isLoading || _isSaving ? null : _openStore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: (16 * textScaleFactor).clamp(12.0, 20.0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: primaryColor.withOpacity(0.3),
                      disabledBackgroundColor: primaryColor.withOpacity(0.6),
                    ),
                    child:
                        _isSaving
                            ? CircularProgressIndicator(
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            )
                            : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Abrir Punto de Venta',
                                    style: TextStyle(
                                      fontSize: bodyFontSize * 1.1,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(width: spacingSmall),
                                  Icon(
                                    Icons.arrow_forward,
                                    size: (24 * textScaleFactor).clamp(
                                      20.0,
                                      28.0,
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
      ),
    );
  }
}
