import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../models/categoria.dart';
import '../../services/supabase_service.dart';

class ProductsManagementPage extends StatefulWidget {
  const ProductsManagementPage({super.key});

  @override
  State<ProductsManagementPage> createState() => _ProductsManagementPageState();
}

class _ProductsManagementPageState extends State<ProductsManagementPage> {
  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  bool _isLoading = true;
  String _busqueda = '';

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
      final productos = await SupabaseService.getAllProductos();
      final categorias = await SupabaseService.getCategorias();

      setState(() {
        _productos = productos;
        _categorias = categorias;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando productos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Producto> _getProductosFiltrados() {
    if (_busqueda.isEmpty) {
      return _productos;
    }
    return _productos
        .where((p) =>
            p.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
            (p.descripcion?.toLowerCase().contains(_busqueda.toLowerCase()) ?? false))
        .toList();
  }

  Future<void> _eliminarProducto(Producto producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar "${producto.nombre}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final exito = await SupabaseService.eliminarProducto(producto.id);
      if (exito) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado exitosamente')),
          );
          _loadData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al eliminar producto')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmallScreen = screenWidth < 600;

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
                    color: isDark
                        ? const Color(0xFF44403C)
                        : const Color(0xFFE7E5E4),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      shape: const CircleBorder(),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Gestión de Productos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _mostrarDialogoProducto(),
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      shape: const CircleBorder(),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),

            // Buscador
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar productos...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2D211A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                    ),
                  ),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1B130D),
                ),
                onChanged: (value) {
                  setState(() {
                    _busqueda = value;
                  });
                },
              ),
            ),

            // Lista de productos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: _getProductosFiltrados().isEmpty
                          ? Center(
                              child: Text(
                                'No hay productos',
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? const Color(0xFF9A6C4C)
                                          : const Color(0xFF9A6C4C),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 16 : 20,
                                vertical: 8,
                              ),
                              itemCount: _getProductosFiltrados().length,
                              itemBuilder: (context, index) {
                                final producto = _getProductosFiltrados()[index];
                                return _buildProductoCard(producto, isDark);
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoCard(Producto producto, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF2C2018) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? const Color(0xFF44403C)
              : const Color(0xFFE7E5E4),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          producto.nombre,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B130D),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (producto.descripcion != null && producto.descripcion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  producto.descripcion!,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (producto.categoria != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      producto.categoria!.nombre,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  '\$${producto.precio.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEC6D13),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${producto.unidadMedida}',
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
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: producto.activo
                        ? Colors.green.withOpacity(isDark ? 0.2 : 0.1)
                        : Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    producto.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 10,
                      color: producto.activo ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white : const Color(0xFF1B130D),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _mostrarDialogoProducto(producto: producto);
                });
              },
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar', style: TextStyle(color: Colors.red)),
                ],
              ),
              onTap: () {
                Future.delayed(const Duration(milliseconds: 100), () {
                  _eliminarProducto(producto);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoProducto({Producto? producto}) {
    final nombreController = TextEditingController(text: producto?.nombre ?? '');
    final descripcionController = TextEditingController(text: producto?.descripcion ?? '');
    final precioController = TextEditingController(text: producto?.precio.toStringAsFixed(0) ?? '0');
    final unidadMedidaController = TextEditingController(text: producto?.unidadMedida ?? 'unidad');
    
    Categoria? categoriaSeleccionada = producto?.categoria;
    bool activo = producto?.activo ?? true;

    // Guardar referencia al contexto del Scaffold antes de abrir el diálogo
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF2D211A) : Colors.white,
            title: Text(
              producto == null ? 'Nuevo Producto' : 'Editar Producto',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre *',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF221810) : Colors.grey[100],
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descripcionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF221810) : Colors.grey[100],
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Categoria?>(
                    value: categoriaSeleccionada,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF221810) : Colors.grey[100],
                    ),
                    items: [
                      const DropdownMenuItem<Categoria?>(
                        value: null,
                        child: Text('Sin categoría'),
                      ),
                      ..._categorias.map((cat) => DropdownMenuItem<Categoria?>(
                        value: cat,
                        child: Text(cat.nombre),
                      )),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        categoriaSeleccionada = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: precioController,
                    decoration: InputDecoration(
                      labelText: 'Precio *',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF221810) : Colors.grey[100],
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: unidadMedidaController,
                    decoration: InputDecoration(
                      labelText: 'Unidad de Medida',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF221810) : Colors.grey[100],
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: activo,
                        onChanged: (value) {
                          setDialogState(() {
                            activo = value ?? true;
                          });
                        },
                      ),
                      Text(
                        'Activo',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nombreController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El nombre es requerido')),
                    );
                    return;
                  }

                  final precio = double.tryParse(precioController.text);
                  if (precio == null || precio < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('El precio debe ser un número válido')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  if (producto == null) {
                    // Crear nuevo producto
                    final nuevoProducto = await SupabaseService.crearProducto(
                      nombre: nombreController.text,
                      descripcion: descripcionController.text.isEmpty
                          ? null
                          : descripcionController.text,
                      categoriaId: categoriaSeleccionada?.id,
                      precio: precio,
                      unidadMedida: unidadMedidaController.text.isEmpty
                          ? 'unidad'
                          : unidadMedidaController.text,
                      activo: activo,
                    );

                    if (nuevoProducto != null && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Producto creado exitosamente')),
                      );
                      _loadData();
                    } else if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Error al crear producto')),
                      );
                    }
                  } else {
                    // Actualizar producto existente
                    final productoActualizado = await SupabaseService.actualizarProducto(
                      productoId: producto.id,
                      nombre: nombreController.text,
                      descripcion: descripcionController.text.isEmpty
                          ? null
                          : descripcionController.text,
                      categoriaId: categoriaSeleccionada?.id,
                      precio: precio,
                      unidadMedida: unidadMedidaController.text.isEmpty
                          ? null
                          : unidadMedidaController.text,
                      activo: activo,
                    );

                    if (productoActualizado != null && mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Producto actualizado exitosamente')),
                      );
                      _loadData();
                    } else if (mounted) {
                      scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Error al actualizar producto')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC6D13),
                  foregroundColor: Colors.white,
                ),
                child: Text(producto == null ? 'Crear' : 'Actualizar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
