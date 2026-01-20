import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../services/supabase_service.dart';

class FactoryInventoryProductionPage extends StatefulWidget {
  const FactoryInventoryProductionPage({super.key});

  @override
  State<FactoryInventoryProductionPage> createState() => _FactoryInventoryProductionPageState();
}

class _FactoryInventoryProductionPageState extends State<FactoryInventoryProductionPage> {
  List<Producto> _productos = [];
  Map<int, int> _inventarioActual = {}; // productoId -> cantidad
  Map<int, TextEditingController> _cantidadControllers = {}; // productoId -> controller
  bool _isLoading = true;
  bool _isGuardando = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    // Dispose de todos los controllers
    for (final controller in _cantidadControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar todos los productos activos
      final productos = await SupabaseService.getProductosActivos();

      // Filtrar productos: churros en tamaño bandeja
      // - categoria_id = 1 o 4: nombre contiene "crudo" y unidad_medida = "bandeja"
      // - categoria_id = 5: sin restricciones adicionales
      final productosFiltrados = productos.where((producto) {
        final categoriaId = producto.categoria?.id;
        
        // Si es categoría 5, se incluye sin restricciones
        if (categoriaId == 5) {
          return true;
        }
        
        // Para categorías 1 y 4, verificar condiciones adicionales
        if (categoriaId == 1 || categoriaId == 4) {
          final nombre = producto.nombre.toLowerCase();
          final unidadMedida = producto.unidadMedida.toLowerCase();
          
          // Verificar que el nombre contenga "crudo"
          final contieneCrudo = nombre.contains('crudo');
          
          // Verificar que la unidad de medida sea "bandeja"
          final esBandeja = unidadMedida == 'bandeja';
          
          return contieneCrudo && esBandeja;
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
              content: Text('Se agregaron $cantidadProducida unidades. Total: $nuevaCantidad'),
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6),
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
                color: (isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6))
                    .withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
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
                      'Producción de Inventario',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                                  color: isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay productos disponibles',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF1B130D),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No se encontraron churros en tamaño bandeja',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? const Color(0xFFA8A29E)
                                        : const Color(0xFF78716C),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 16 : 20,
                              vertical: 16,
                            ),
                            itemCount: _productos.length,
                            itemBuilder: (context, index) {
                              final producto = _productos[index];
                              final cantidadActual = _inventarioActual[producto.id] ?? 0;
                              final controller = _cantidadControllers[producto.id];

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D211A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
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
              if (producto.descripcion != null && producto.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  producto.descripcion!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
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
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cantidad actual en inventario:',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
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
              icon: isGuardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, size: 20),
              label: Text(
                isGuardando ? 'Guardando...' : 'Guardar Cantidad',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
