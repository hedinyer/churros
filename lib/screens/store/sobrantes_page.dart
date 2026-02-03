import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';

class SobrantesPage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const SobrantesPage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<SobrantesPage> createState() => _SobrantesPageState();
}

class _SobrantesPageState extends State<SobrantesPage> {
  Map<Producto, int> _inventarioSucursal5 = {};
  Map<int, int> _cantidadesSeleccionadas = {}; // productoId -> cantidad seleccionada
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventario();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventario() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar inventario de la sucursal 5 (solo productos fritos)
      final inventarioCompleto = await SupabaseService.getInventarioActualConProductos(5);
      
      // Filtrar solo productos fritos
      final inventarioFritos = <Producto, int>{};
      for (final entry in inventarioCompleto.entries) {
        final producto = entry.key;
        final cantidad = entry.value;
        
        // Solo incluir productos que tengan "frito" en el nombre y cantidad > 0
        if (producto.nombre.toLowerCase().contains('frito') && cantidad > 0) {
          inventarioFritos[producto] = cantidad;
        }
      }

      setState(() {
        _inventarioSucursal5 = inventarioFritos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando inventario de sucursal 5: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Producto> _getProductosFiltrados() {
    if (_searchQuery.trim().isEmpty) {
      return _inventarioSucursal5.keys.toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    return _inventarioSucursal5.keys.where((producto) {
      return producto.nombre.toLowerCase().contains(query);
    }).toList();
  }

  void _incrementCantidad(Producto producto) {
    final cantidadActual = _inventarioSucursal5[producto] ?? 0;
    final cantidadSeleccionada = _cantidadesSeleccionadas[producto.id] ?? 0;
    
    if (cantidadSeleccionada < cantidadActual) {
      setState(() {
        _cantidadesSeleccionadas[producto.id] = cantidadSeleccionada + 1;
      });
    }
  }

  void _decrementCantidad(Producto producto) {
    final cantidadSeleccionada = _cantidadesSeleccionadas[producto.id] ?? 0;
    
    if (cantidadSeleccionada > 0) {
      setState(() {
        _cantidadesSeleccionadas[producto.id] = cantidadSeleccionada - 1;
      });
    }
  }

  Future<void> _transferirInventario() async {
    // Verificar que haya productos seleccionados
    final productosATransferir = _cantidadesSeleccionadas.entries
        .where((entry) => entry.value > 0)
        .toList();

    if (productosATransferir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un producto para transferir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Transferencia'),
        content: Text(
          '¿Deseas transferir ${productosATransferir.length} producto(s) a la sucursal 6?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEC6D13),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      int transferidosExitosos = 0;
      int transferidosFallidos = 0;

      // Transferir cada producto a la sucursal 6
      for (final entry in productosATransferir) {
        final productoId = entry.key;
        final cantidad = entry.value;

        print('🔄 Transfiriendo producto $productoId, cantidad: $cantidad a sucursal 6');

        try {
          // Primero aumentar en sucursal 6
          final exitoAumentar = await SupabaseService.aumentarInventarioActual(
            sucursalId: 6,
            productoId: productoId,
            cantidad: cantidad,
          );

          if (exitoAumentar) {
            print('✅ Producto $productoId aumentado exitosamente en sucursal 6');
            
            // Luego descontar de la sucursal 5
            final resultadoDescontar = await SupabaseService.descontarInventarioActual(
              sucursalId: 5,
              productoId: productoId,
              cantidad: cantidad,
            );

            if (resultadoDescontar['exito'] == true) {
              print('✅ Producto $productoId descontado exitosamente de sucursal 5');
              transferidosExitosos++;
            } else {
              print('⚠️ Error descontando producto $productoId de sucursal 5: ${resultadoDescontar['mensaje']}');
              transferidosFallidos++;
            }
          } else {
            print('❌ Error aumentando producto $productoId en sucursal 6');
            transferidosFallidos++;
          }
        } catch (e) {
          print('❌ Excepción al transferir producto $productoId: $e');
          transferidosFallidos++;
        }
      }

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Mostrar resultado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transferidosFallidos == 0
                  ? '✅ ${transferidosExitosos} producto(s) transferido(s) exitosamente'
                  : '⚠️ ${transferidosExitosos} transferido(s), ${transferidosFallidos} fallido(s)',
            ),
            backgroundColor: transferidosFallidos == 0 ? Colors.green : Colors.orange,
          ),
        );
      }

      // Recargar inventario y limpiar selecciones
      await _loadInventario();
      setState(() {
        _cantidadesSeleccionadas.clear();
      });
    } catch (e) {
      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al transferir inventario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getTotalSeleccionado() {
    return _cantidadesSeleccionadas.values.fold(0, (sum, cantidad) => sum + cantidad);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 600;

    // Deshabilitar escalado de texto del sistema
    final mediaQueryWithoutTextScale = mediaQuery.copyWith(
      textScaler: TextScaler.linear(1.0),
    );

    return MediaQuery(
      data: mediaQueryWithoutTextScale,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
        appBar: AppBar(
          title: const Text('SOBRANTES'),
          backgroundColor: isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
          foregroundColor: isDark ? Colors.white : const Color(0xFF1B130D),
          elevation: 0,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Barra de búsqueda
                  Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF2C2018)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF44403C)
                                : const Color(0xFFE7E5E4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lista de productos
                  Expanded(
                    child: _inventarioSucursal5.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.3)
                                      : const Color(0xFF78716C).withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay productos fritos disponibles\nen la sucursal 5',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.6)
                                        : const Color(0xFF78716C),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20,
                            ),
                            itemCount: _getProductosFiltrados().length,
                            itemBuilder: (context, index) {
                              final producto = _getProductosFiltrados()[index];
                              final cantidadDisponible = _inventarioSucursal5[producto] ?? 0;
                              final cantidadSeleccionada = _cantidadesSeleccionadas[producto.id] ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2C2018)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: cantidadSeleccionada > 0
                                        ? const Color(0xFFEC6D13)
                                        : (isDark
                                            ? const Color(0xFF44403C).withOpacity(0.4)
                                            : const Color(0xFFE7E5E4).withOpacity(0.5)),
                                    width: cantidadSeleccionada > 0 ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withOpacity(0.3)
                                          : Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Información del producto
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              producto.nombre,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Disponible: $cantidadDisponible',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? Colors.white.withOpacity(0.7)
                                                    : const Color(0xFF78716C),
                                              ),
                                            ),
                                            if (cantidadSeleccionada > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  'Seleccionado: $cantidadSeleccionada',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFEC6D13),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),

                                      // Controles de cantidad
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: cantidadSeleccionada > 0
                                                ? () => _decrementCantidad(producto)
                                                : null,
                                            icon: const Icon(Icons.remove_circle_outline),
                                            color: cantidadSeleccionada > 0
                                                ? const Color(0xFFEC6D13)
                                                : (isDark
                                                    ? Colors.white.withOpacity(0.3)
                                                    : const Color(0xFF78716C).withOpacity(0.5)),
                                          ),
                                          Container(
                                            width: 40,
                                            alignment: Alignment.center,
                                            child: Text(
                                              cantidadSeleccionada.toString(),
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1B130D),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: cantidadSeleccionada < cantidadDisponible
                                                ? () => _incrementCantidad(producto)
                                                : null,
                                            icon: const Icon(Icons.add_circle_outline),
                                            color: cantidadSeleccionada < cantidadDisponible
                                                ? const Color(0xFFEC6D13)
                                                : (isDark
                                                    ? Colors.white.withOpacity(0.3)
                                                    : const Color(0xFF78716C).withOpacity(0.5)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Botón de transferir
                  if (_getTotalSeleccionado() > 0)
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2C2018)
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _transferirInventario,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC6D13),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'TRANSFERIR ${_getTotalSeleccionado()} PRODUCTO(S) A SUCURSAL 6',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
