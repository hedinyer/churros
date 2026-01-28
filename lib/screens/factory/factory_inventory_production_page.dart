import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../services/factory_section_tracker.dart';
import '../../services/supabase_service.dart';

class FactoryInventoryProductionPage extends StatefulWidget {
  const FactoryInventoryProductionPage({super.key});

  @override
  State<FactoryInventoryProductionPage> createState() =>
      _FactoryInventoryProductionPageState();
}

class _FactoryInventoryProductionPageState
    extends State<FactoryInventoryProductionPage> {
  List<Producto> _productos = [];
  Map<int, int> _inventarioActual = {}; // productoId -> cantidad
  Map<int, TextEditingController> _cantidadControllers =
      {}; // productoId -> controller
  bool _isLoading = true;
  bool _isGuardando = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    FactorySectionTracker.enter();
    _loadData();
  }

  @override
  void dispose() {
    FactorySectionTracker.exit();
    // Dispose de todos los controllers
    for (final controller in _cantidadControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar todos los productos activos
      final productos = await SupabaseService.getProductosActivos();

      // Filtrar productos de fábrica:
      // - categoria_id = 1 o 4: nombre contiene "crudo"
      //   y NO contienen "x10" ni "x 10" en el nombre (pueden ser bandeja o cualquier otra unidad)
      //   (NO se excluyen IDs específicos: 8,10,12,14,16,18,20,21)
      // - categoria_id = 5: sin restricciones adicionales
      final productosFiltrados =
          productos.where((producto) {
            final categoriaId = producto.categoria?.id;

            // Si es categoría 5, se incluye sin restricciones
            if (categoriaId == 5) {
              return true;
            }

            // Para categorías 1 y 4, verificar condiciones adicionales
            if (categoriaId == 1 || categoriaId == 4) {
              final nombre = producto.nombre.toLowerCase();

              // Verificar que el nombre contenga "crudo"
              final contieneCrudo = nombre.contains('crudo');

              // Excluir churros x10 (en cualquier formato "x10" o "x 10")
              final nombreContieneX10 =
                  nombre.contains('x10') || nombre.contains('x 10');

              // Incluir cualquier unidad de medida (bandeja, unidad, etc.)
              return contieneCrudo && !nombreContieneX10;
            }

            // Otras categorías no se incluyen
            return false;
          }).toList();

      // Cargar inventario actual de fábrica
      final inventario = await SupabaseService.getInventarioFabricaCompleto();

      // Inicializar controllers vacíos (para ingresar cantidad producida)
      final cantidadControllers = <int, TextEditingController>{};
      for (final producto in productosFiltrados) {
        cantidadControllers[producto.id] = TextEditingController();
      }

      setState(() {
        _productos = productosFiltrados;
        _inventarioActual = inventario;
        _cantidadControllers = cantidadControllers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de producción de inventario: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarCantidad(int productoId) async {
    final controller = _cantidadControllers[productoId];
    if (controller == null) return;

    final cantidadTexto = controller.text.trim();
    if (cantidadTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa una cantidad producida'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cantidadProducida = int.tryParse(cantidadTexto);
    if (cantidadProducida == null || cantidadProducida <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cantidad producida debe ser un número mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGuardando = true;
    });

    try {
      // Obtener cantidad actual
      final cantidadActual = _inventarioActual[productoId] ?? 0;

      // Sumar la cantidad producida a la cantidad actual
      final nuevaCantidad = cantidadActual + cantidadProducida;

      final exito = await SupabaseService.actualizarInventarioFabrica(
        productoId: productoId,
        cantidad: nuevaCantidad,
      );

      if (exito) {
        setState(() {
          _inventarioActual[productoId] = nuevaCantidad;
          // Vaciar el campo de texto para permitir ingresar otra cantidad
          controller.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Se agregaron $cantidadProducida unidades. Total: $nuevaCantidad',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al actualizar la cantidad'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGuardando = false;
        });
      }
    }
  }

  List<Producto> _getProductosFiltrados() {
    if (_searchQuery.trim().isEmpty) {
      return _productos;
    }

    final query = _searchQuery.trim().toLowerCase();
    final palabras = query.split(' ').where((p) => p.isNotEmpty).toList();

    return _productos.where((producto) {
      final nombre = producto.nombre.toLowerCase();
      return palabras.every((p) => nombre.contains(p));
    }).toList();
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
                      'Producción de Inventario',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance para el botón de back
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  // Estado vacío real: no hay ningún producto cargado
                  : _productos.isEmpty
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color:
                                    isDark
                                        ? const Color(0xFFA8A29E)
                                        : const Color(0xFF78716C),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay productos disponibles',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF1B130D),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No se encontraron churros en tamaño bandeja',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDark
                                          ? const Color(0xFFA8A29E)
                                          : const Color(0xFF78716C),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                      // Siempre mostrar la lista + barra de búsqueda, incluso si
                      // la búsqueda actual no tiene resultados.
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20,
                              vertical: 16,
                            ),
                            itemCount: _getProductosFiltrados().length + 1,
                            itemBuilder: (context, index) {
                            // Primer elemento: barra de búsqueda
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2D211A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.08)
                                          : Colors.black.withOpacity(0.08),
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
                                            ? const Color(0xFF9A6C4C)
                                            : const Color(0xFF78716C),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: isDark
                                            ? const Color(0xFF9A6C4C)
                                            : const Color(0xFF78716C),
                                      ),
                                      suffixIcon: _searchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                color: isDark
                                                    ? const Color(0xFF9A6C4C)
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                              );
                            }

                            final productosFiltrados =
                                _getProductosFiltrados();

                            // Si no hay productos que coincidan con la búsqueda,
                            // solo mostramos la barra de búsqueda y un mensaje.
                            if (productosFiltrados.isEmpty) {
                              if (index == 0) {
                                // Ya se construyó la barra de búsqueda arriba.
                                // No renderizar más ítems.
                                return const SizedBox.shrink();
                              }
                            }

                            final producto = productosFiltrados[index - 1];
                            final cantidadActual =
                                _inventarioActual[producto.id] ?? 0;
                            final controller =
                                _cantidadControllers[producto.id];

                            return _buildProductoCard(
                              isDark: isDark,
                              producto: producto,
                              cantidadActual: cantidadActual,
                              controller: controller,
                              primaryColor: primaryColor,
                              onGuardar: () => _guardarCantidad(producto.id),
                              isGuardando: _isGuardando,
                            );
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoCard({
    required bool isDark,
    required Producto producto,
    required int cantidadActual,
    required TextEditingController? controller,
    required Color primaryColor,
    required VoidCallback onGuardar,
    required bool isGuardando,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
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
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del producto
          Column(
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
              if (producto.descripcion != null &&
                  producto.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  producto.descripcion!,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Cantidad actual
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  'Cantidad actual en inventario:',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                  ),
                ),
                Text(
                  '$cantidadActual ${producto.unidadMedida}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Input de cantidad producida
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Cantidad producida a agregar',
              hintText: 'Ingresa la cantidad producida',
              helperText: 'Esta cantidad se sumará al inventario actual',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixText: producto.unidadMedida,
              prefixIcon: const Icon(Icons.add_circle_outline),
            ),
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1B130D),
            ),
          ),

          const SizedBox(height: 16),

          // Botón de guardar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isGuardando ? null : onGuardar,
              icon:
                  isGuardando
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
                      : const Icon(Icons.save, size: 20),
              label: Text(
                isGuardando ? 'Guardando...' : 'Guardar Cantidad',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 6,
                shadowColor: primaryColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
