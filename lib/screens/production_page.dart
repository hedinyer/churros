import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido_fabrica.dart';
import '../models/pedido_cliente.dart';
import '../models/producto.dart';
import '../models/empleado.dart';
import '../models/produccion_empleado.dart';
import '../services/supabase_service.dart';

class ProductionPage extends StatefulWidget {
  const ProductionPage({super.key});

  @override
  State<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends State<ProductionPage> {
  List<Map<String, dynamic>> _pedidosEnPreparacion = []; // {'tipo': 'fabrica'|'cliente', 'pedido': PedidoFabrica|PedidoCliente}
  List<Producto> _productos = [];
  List<Empleado> _empleados = [];
  Map<String, dynamic>? _pedidoSeleccionado; // {'tipo': 'fabrica'|'cliente', 'pedido': PedidoFabrica|PedidoCliente}
  Map<int, bool> _productosCompletados = {}; // detalleId -> completado
  Map<int, List<ProduccionEmpleado>> _produccionPorDetalle = {}; // detalleId -> List<ProduccionEmpleado>
  String _busqueda = '';
  bool _isLoading = true;
  bool _isConfirmando = false;

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
      // Cargar productos
      final productos = await SupabaseService.getProductosActivos();

      // Cargar empleados activos
      final empleados = await SupabaseService.getEmpleadosActivos();

      // Cargar pedidos de fábrica en preparación
      final todosPedidosFabrica = await SupabaseService.getPedidosFabricaRecientesTodasSucursales(limit: 100);
      final pedidosFabricaEnPreparacion = todosPedidosFabrica.where((p) => p.estado == 'en_preparacion').toList();

      // Cargar pedidos de clientes en preparación
      final todosPedidosClientes = await SupabaseService.getPedidosClientesRecientes(limit: 100);
      final pedidosClientesEnPreparacion = todosPedidosClientes.where((p) => p.estado == 'en_preparacion').toList();

      // Combinar ambos tipos de pedidos
      final pedidosCombinados = <Map<String, dynamic>>[];
      
      for (final pedido in pedidosFabricaEnPreparacion) {
        pedidosCombinados.add({'tipo': 'fabrica', 'pedido': pedido});
      }
      
      for (final pedido in pedidosClientesEnPreparacion) {
        pedidosCombinados.add({'tipo': 'cliente', 'pedido': pedido});
      }

      // Ordenar por fecha de creación (más recientes primero)
      pedidosCombinados.sort((a, b) {
        final fechaA = a['tipo'] == 'fabrica'
            ? (a['pedido'] as PedidoFabrica).createdAt
            : (a['pedido'] as PedidoCliente).createdAt;
        final fechaB = b['tipo'] == 'fabrica'
            ? (b['pedido'] as PedidoFabrica).createdAt
            : (b['pedido'] as PedidoCliente).createdAt;
        return fechaB.compareTo(fechaA);
      });

      // Inicializar productos completados
      final productosCompletados = <int, bool>{};
      
      for (final pedidoData in pedidosCombinados) {
        final pedido = pedidoData['pedido'];
        if (pedidoData['tipo'] == 'fabrica') {
          final pedidoFabrica = pedido as PedidoFabrica;
          if (pedidoFabrica.detalles != null) {
            for (final detalle in pedidoFabrica.detalles!) {
              productosCompletados[detalle.id] = false;
            }
          }
        } else {
          final pedidoCliente = pedido as PedidoCliente;
          if (pedidoCliente.detalles != null) {
            for (final detalle in pedidoCliente.detalles!) {
              productosCompletados[detalle.id] = false;
            }
          }
        }
      }

      // Cargar producción existente para cada detalle
      final produccionPorDetalle = <int, List<ProduccionEmpleado>>{};
      
      for (final pedidoData in pedidosCombinados) {
        final tipo = pedidoData['tipo'] as String;
        final pedido = pedidoData['pedido'];
        
        if (tipo == 'fabrica') {
          final pedidoFabrica = pedido as PedidoFabrica;
          if (pedidoFabrica.detalles != null) {
            for (final detalle in pedidoFabrica.detalles!) {
              final produccion = await SupabaseService.getProduccionPorDetalle(
                productoId: detalle.productoId,
                pedidoFabricaId: pedidoFabrica.id,
              );
              produccionPorDetalle[detalle.id] = produccion;
            }
          }
        } else {
          final pedidoCliente = pedido as PedidoCliente;
          if (pedidoCliente.detalles != null) {
            for (final detalle in pedidoCliente.detalles!) {
              final produccion = await SupabaseService.getProduccionPorDetalle(
                productoId: detalle.productoId,
                pedidoClienteId: pedidoCliente.id,
              );
              produccionPorDetalle[detalle.id] = produccion;
            }
          }
        }
      }

      // Verificar si el pedido seleccionado todavía está en la lista
      Map<String, dynamic>? nuevoPedidoSeleccionado;
      if (_pedidoSeleccionado != null) {
        final tipoSeleccionado = _pedidoSeleccionado!['tipo'] as String;
        final pedidoSeleccionado = _pedidoSeleccionado!['pedido'];
        
        // Buscar si el pedido seleccionado todavía está en la lista
        final pedidoExiste = pedidosCombinados.any((pedidoData) {
          final tipo = pedidoData['tipo'] as String;
          final pedido = pedidoData['pedido'];
          
          if (tipoSeleccionado != tipo) return false;
          
          if (tipoSeleccionado == 'fabrica') {
            return (pedidoSeleccionado as PedidoFabrica).id == (pedido as PedidoFabrica).id;
          } else {
            return (pedidoSeleccionado as PedidoCliente).id == (pedido as PedidoCliente).id;
          }
        });
        
        if (pedidoExiste) {
          // El pedido todavía está en la lista, mantenerlo seleccionado
          nuevoPedidoSeleccionado = _pedidoSeleccionado;
        } else {
          // El pedido ya no está en la lista, seleccionar el primero disponible o null
          nuevoPedidoSeleccionado = pedidosCombinados.isNotEmpty ? pedidosCombinados.first : null;
        }
      } else {
        // Si no había pedido seleccionado, seleccionar el primero si existe
        nuevoPedidoSeleccionado = pedidosCombinados.isNotEmpty ? pedidosCombinados.first : null;
      }

      setState(() {
        _productos = productos;
        _empleados = empleados;
        _pedidosEnPreparacion = pedidosCombinados;
        _productosCompletados = productosCompletados;
        _produccionPorDetalle = produccionPorDetalle;
        _pedidoSeleccionado = nuevoPedidoSeleccionado;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de producción: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getPedidosFiltrados() {
    if (_busqueda.isEmpty) {
      return _pedidosEnPreparacion;
    }
    final busquedaLower = _busqueda.toLowerCase();
    return _pedidosEnPreparacion.where((pedidoData) {
      final tipo = pedidoData['tipo'] as String;
      final pedido = pedidoData['pedido'];
      
      if (tipo == 'fabrica') {
        final pedidoFabrica = pedido as PedidoFabrica;
        final numero = (pedidoFabrica.numeroPedido ?? 'Pedido #${pedidoFabrica.id}').toLowerCase();
        final sucursal = (pedidoFabrica.sucursal?.nombre ?? '').toLowerCase();
        return numero.contains(busquedaLower) || sucursal.contains(busquedaLower);
      } else {
        final pedidoCliente = pedido as PedidoCliente;
        final numero = (pedidoCliente.numeroPedido ?? 'Pedido #${pedidoCliente.id}').toLowerCase();
        final cliente = pedidoCliente.clienteNombre.toLowerCase();
        return numero.contains(busquedaLower) || cliente.contains(busquedaLower);
      }
    }).toList();
  }

  Producto? _getProductoById(int productoId) {
    try {
      return _productos.firstWhere((p) => p.id == productoId);
    } catch (e) {
      return null;
    }
  }

  void _toggleProductoCompletado(int detalleId, int cantidadSolicitada) {
    setState(() {
      final completado = _productosCompletados[detalleId] ?? false;
      _productosCompletados[detalleId] = !completado;
    });
  }

  Future<void> _asignarEmpleadoAProducto({
    required int detalleId,
    required int productoId,
    required int cantidadSolicitada,
  }) async {
    if (_empleados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay empleados disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Empleado? empleadoSeleccionado;
    final cantidadController = TextEditingController(text: '1');
    final observacionesController = TextEditingController();

    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Asignar Empleado'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cantidad solicitada: $cantidadSolicitada',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Seleccionar empleado:'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Empleado>(
                        value: empleadoSeleccionado,
                        isExpanded: true,
                        hint: const Text('Selecciona un empleado'),
                        items: _empleados.map((empleado) {
                          return DropdownMenuItem<Empleado>(
                            value: empleado,
                            child: Text(empleado.nombre),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            empleadoSeleccionado = value;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad producida',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: observacionesController,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: empleadoSeleccionado == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );

    if (resultado != true || empleadoSeleccionado == null) return;

    final cantidadProducida = int.tryParse(cantidadController.text) ?? 1;
    if (cantidadProducida <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La cantidad debe ser mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Obtener IDs del pedido
    final tipo = _pedidoSeleccionado!['tipo'] as String;
    final pedido = _pedidoSeleccionado!['pedido'];
    int? pedidoFabricaId;
    int? pedidoClienteId;

    if (tipo == 'fabrica') {
      pedidoFabricaId = (pedido as PedidoFabrica).id;
    } else {
      pedidoClienteId = (pedido as PedidoCliente).id;
    }

    // Guardar producción
    final exito = await SupabaseService.guardarProduccionEmpleado(
      empleadoId: empleadoSeleccionado!.id,
      productoId: productoId,
      cantidadProducida: cantidadProducida,
      pedidoFabricaId: pedidoFabricaId,
      pedidoClienteId: pedidoClienteId,
      observaciones: observacionesController.text.isEmpty
          ? null
          : observacionesController.text,
    );

    if (exito) {
      // Recargar producción para este detalle
      final produccion = await SupabaseService.getProduccionPorDetalle(
        productoId: productoId,
        pedidoFabricaId: pedidoFabricaId,
        pedidoClienteId: pedidoClienteId,
      );

      setState(() {
        _produccionPorDetalle[detalleId] = produccion;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producción registrada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar la producción'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _getTotalProducidoPorDetalle(int detalleId) {
    final produccion = _produccionPorDetalle[detalleId] ?? [];
    return produccion.fold(0, (sum, p) => sum + p.cantidadProducida);
  }

  int _getTotalItemsCompletados() {
    if (_pedidoSeleccionado == null) return 0;
    final tipo = _pedidoSeleccionado!['tipo'] as String;
    final pedido = _pedidoSeleccionado!['pedido'];
    
    List<dynamic> detalles = [];
    if (tipo == 'fabrica') {
      final pedidoFabrica = pedido as PedidoFabrica;
      detalles = pedidoFabrica.detalles ?? [];
    } else {
      final pedidoCliente = pedido as PedidoCliente;
      detalles = pedidoCliente.detalles ?? [];
    }
    
    if (detalles.isEmpty) return 0;
    
    int completados = 0;
    for (final detalle in detalles) {
      final detalleId = detalle.id as int;
      if (_productosCompletados[detalleId] == true) {
        completados++;
      }
    }
    return completados;
  }

  bool _puedeDespachar() {
    if (_pedidoSeleccionado == null) return false;
    final tipo = _pedidoSeleccionado!['tipo'] as String;
    final pedido = _pedidoSeleccionado!['pedido'];
    
    List<dynamic> detalles = [];
    if (tipo == 'fabrica') {
      final pedidoFabrica = pedido as PedidoFabrica;
      detalles = pedidoFabrica.detalles ?? [];
    } else {
      final pedidoCliente = pedido as PedidoCliente;
      detalles = pedidoCliente.detalles ?? [];
    }
    
    if (detalles.isEmpty) return false;
    return _getTotalItemsCompletados() == detalles.length;
  }

  Future<void> _confirmarYDespachar() async {
    if (_pedidoSeleccionado == null) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar despacho'),
        content: const Text('¿Confirmar que el pedido está listo para despachar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() {
      _isConfirmando = true;
    });

    try {
      final tipo = _pedidoSeleccionado!['tipo'] as String;
      final pedido = _pedidoSeleccionado!['pedido'];
      
      bool exito = false;
      if (tipo == 'fabrica') {
        final pedidoFabrica = pedido as PedidoFabrica;
        exito = await SupabaseService.actualizarEstadoPedidoFabrica(
          pedidoId: pedidoFabrica.id,
          nuevoEstado: 'enviado',
        );
      } else {
        final pedidoCliente = pedido as PedidoCliente;
        exito = await SupabaseService.actualizarEstadoPedidoCliente(
          pedidoId: pedidoCliente.id,
          nuevoEstado: 'enviado',
        );
      }

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido confirmado y despachado'),
            backgroundColor: Colors.green,
          ),
        );
        // Recargar datos
        await _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al confirmar el pedido'),
            backgroundColor: Colors.red,
          ),
        );
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
          _isConfirmando = false;
        });
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Hace unos segundos';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else {
      return DateFormat('d MMM', 'es').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    final pedidosFiltrados = _getPedidosFiltrados();

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
                      'Producción',
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

            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2F2218) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                  ),
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _busqueda = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar por # pedido, sucursal o cliente...',
                    hintStyle: TextStyle(
                      color: isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
              ),
            ),

            // Main Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _pedidoSeleccionado == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_outlined,
                                  size: 64,
                                  color: isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay pedidos en preparación',
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
                                  'Los pedidos aparecerán aquí cuando estén en estado "En Preparación"',
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
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 16 : 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pedido activo (expandido)
                              _buildPedidoActivoCard(
                                isDark: isDark,
                                pedidoData: _pedidoSeleccionado!,
                                primaryColor: primaryColor,
                              ),

                              const SizedBox(height: 24),

                              // Lista de siguientes pedidos
                              if (pedidosFiltrados.length > 1) ...[
                                Text(
                                  'Siguientes en cola',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF9A6C4C),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...pedidosFiltrados
                                    .where((pedidoData) {
                                      final tipoSeleccionado = _pedidoSeleccionado!['tipo'] as String;
                                      final pedidoSeleccionado = _pedidoSeleccionado!['pedido'];
                                      final tipoActual = pedidoData['tipo'] as String;
                                      final pedidoActual = pedidoData['pedido'];
                                      
                                      if (tipoSeleccionado != tipoActual) return true;
                                      
                                      if (tipoSeleccionado == 'fabrica') {
                                        return (pedidoSeleccionado as PedidoFabrica).id != (pedidoActual as PedidoFabrica).id;
                                      } else {
                                        return (pedidoSeleccionado as PedidoCliente).id != (pedidoActual as PedidoCliente).id;
                                      }
                                    })
                                    .map((pedidoData) => _buildPedidoEnColaCard(
                                          isDark: isDark,
                                          pedidoData: pedidoData,
                                          onTap: () async {
                                            setState(() {
                                              _pedidoSeleccionado = pedidoData;
                                              // Inicializar productos completados para el nuevo pedido
                                              final tipo = pedidoData['tipo'] as String;
                                              final pedido = pedidoData['pedido'];
                                              
                                              List<dynamic> detalles = [];
                                              if (tipo == 'fabrica') {
                                                final pedidoFabrica = pedido as PedidoFabrica;
                                                detalles = pedidoFabrica.detalles ?? [];
                                              } else {
                                                final pedidoCliente = pedido as PedidoCliente;
                                                detalles = pedidoCliente.detalles ?? [];
                                              }
                                              
                                              for (final detalle in detalles) {
                                                final detalleId = detalle.id as int;
                                                if (!_productosCompletados.containsKey(detalleId)) {
                                                  _productosCompletados[detalleId] = false;
                                                }
                                              }
                                            });
                                            
                                            // Cargar producción para el nuevo pedido seleccionado
                                            final tipo = pedidoData['tipo'] as String;
                                            final pedido = pedidoData['pedido'];
                                            
                                            final produccionPorDetalle = <int, List<ProduccionEmpleado>>{};
                                            
                                            if (tipo == 'fabrica') {
                                              final pedidoFabrica = pedido as PedidoFabrica;
                                              if (pedidoFabrica.detalles != null) {
                                                for (final detalle in pedidoFabrica.detalles!) {
                                                  final produccion = await SupabaseService.getProduccionPorDetalle(
                                                    productoId: detalle.productoId,
                                                    pedidoFabricaId: pedidoFabrica.id,
                                                  );
                                                  produccionPorDetalle[detalle.id] = produccion;
                                                }
                                              }
                                            } else {
                                              final pedidoCliente = pedido as PedidoCliente;
                                              if (pedidoCliente.detalles != null) {
                                                for (final detalle in pedidoCliente.detalles!) {
                                                  final produccion = await SupabaseService.getProduccionPorDetalle(
                                                    productoId: detalle.productoId,
                                                    pedidoClienteId: pedidoCliente.id,
                                                  );
                                                  produccionPorDetalle[detalle.id] = produccion;
                                                }
                                              }
                                            }
                                            
                                            setState(() {
                                              _produccionPorDetalle = {
                                                ..._produccionPorDetalle,
                                                ...produccionPorDetalle,
                                              };
                                            });
                                          },
                                        )),
                              ],

                              const SizedBox(height: 24), // Space at bottom
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedidoActivoCard({
    required bool isDark,
    required Map<String, dynamic> pedidoData,
    required Color primaryColor,
  }) {
    final tipo = pedidoData['tipo'] as String;
    final pedido = pedidoData['pedido'];
    final isFabrica = tipo == 'fabrica';
    
    final pedidoFabrica = isFabrica ? pedido as PedidoFabrica : null;
    final pedidoCliente = !isFabrica ? pedido as PedidoCliente : null;
    
    final timeAgo = _formatTimeAgo(
      isFabrica 
        ? pedidoFabrica!.createdAt 
        : pedidoCliente!.createdAt
    );
    
    final detalles = isFabrica
        ? pedidoFabrica!.detalles ?? []
        : pedidoCliente!.detalles ?? [];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2F2218) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Borde izquierdo de color
          Container(
            width: double.infinity,
            height: 4,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del pedido
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'EN PROCESO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF9A6C4C)
                                      : const Color(0xFF9A6C4C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFabrica
                                ? (pedidoFabrica!.numeroPedido ?? 'Pedido #${pedidoFabrica.id}')
                                : (pedidoCliente!.numeroPedido ?? 'Pedido #${pedidoCliente.id}'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1B130D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                isFabrica ? Icons.storefront : Icons.chat,
                                size: 16,
                                color: isDark
                                    ? const Color(0xFF9A6C4C)
                                    : const Color(0xFF9A6C4C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isFabrica
                                    ? (pedidoFabrica!.sucursal?.nombre ?? 'Sucursal')
                                    : pedidoCliente!.clienteNombre,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? const Color(0xFF9A6C4C)
                                      : const Color(0xFF9A6C4C),
                                ),
                              ),
                            ],
                          ),
                          if (!isFabrica) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: isDark
                                      ? const Color(0xFF9A6C4C)
                                      : const Color(0xFF9A6C4C),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    pedidoCliente!.direccionEntrega,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? const Color(0xFF9A6C4C)
                                          : const Color(0xFF9A6C4C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Checklist de productos
                if (detalles.isNotEmpty) ...[
                  Text(
                    'Productos a producir:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...detalles.map((detalle) {
                    int productoId;
                    int cantidadSolicitada;
                    int detalleId;
                    
                    if (isFabrica) {
                      final detalleFabrica = detalle as PedidoFabricaDetalle;
                      productoId = detalleFabrica.productoId;
                      cantidadSolicitada = detalleFabrica.cantidad;
                      detalleId = detalleFabrica.id;
                    } else {
                      final detalleCliente = detalle as PedidoClienteDetalle;
                      productoId = detalleCliente.productoId;
                      cantidadSolicitada = detalleCliente.cantidad;
                      detalleId = detalleCliente.id;
                    }
                    
                    final producto = _getProductoById(productoId);
                    final completado = _productosCompletados[detalleId] ?? false;
                    final produccion = _produccionPorDetalle[detalleId] ?? [];
                    final totalProducido = _getTotalProducidoPorDetalle(detalleId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: completado
                            ? Colors.green.withOpacity(isDark ? 0.1 : 0.05)
                            : (isDark
                                ? Colors.black.withOpacity(0.2)
                                : const Color(0xFFF8F7F6)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: completado
                              ? Colors.green.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Checkbox
                              Checkbox(
                                value: completado,
                                onChanged: (value) =>
                                    _toggleProductoCompletado(detalleId, cantidadSolicitada),
                                activeColor: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              // Info del producto
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      producto?.nombre ?? 'Producto #$productoId',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Solicitado: ${cantidadSolicitada} ${producto?.unidadMedida ?? 'unidad'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? const Color(0xFF9A6C4C)
                                            : const Color(0xFF9A6C4C),
                                      ),
                                    ),
                                    if (totalProducido > 0) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Producido: $totalProducido ${producto?.unidadMedida ?? 'unidad'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: totalProducido >= cantidadSolicitada
                                              ? Colors.green
                                              : primaryColor,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Indicador de completado
                              if (completado)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                            ],
                          ),
                          // Lista de empleados asignados
                          if (produccion.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            ...produccion.map((p) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: isDark
                                          ? const Color(0xFF9A6C4C)
                                          : const Color(0xFF9A6C4C),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${p.empleado?.nombre ?? 'Empleado #${p.empleadoId}'}: ${p.cantidadProducida}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? const Color(0xFF9A6C4C)
                                            : const Color(0xFF9A6C4C),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                          // Botón para asignar empleado
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _asignarEmpleadoAProducto(
                                detalleId: detalleId,
                                productoId: productoId,
                                cantidadSolicitada: cantidadSolicitada,
                              ),
                              icon: const Icon(Icons.person_add, size: 16),
                              label: const Text('Asignar Empleado'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                const SizedBox(height: 16),

                // Footer con resumen
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
                        'Total ítems: ${detalles.length}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF9A6C4C)
                              : const Color(0xFF9A6C4C),
                        ),
                      ),
                      Text(
                        _puedeDespachar() ? 'Listo para despachar' : 'En producción',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _puedeDespachar() ? Colors.green : primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón de confirmar y despachar (solo cuando todas las checklists estén seleccionadas)
                if (_puedeDespachar()) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConfirmando ? null : _confirmarYDespachar,
                      icon: _isConfirmando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.local_shipping, size: 24),
                      label: Text(
                        _isConfirmando
                            ? 'Confirmando...'
                            : 'Confirmar y Despachar Pedido',
                        style: const TextStyle(
                          fontSize: 18,
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
                        elevation: 8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoEnColaCard({
    required bool isDark,
    required Map<String, dynamic> pedidoData,
    required VoidCallback onTap,
  }) {
    final tipo = pedidoData['tipo'] as String;
    final pedido = pedidoData['pedido'];
    final isFabrica = tipo == 'fabrica';
    
    final pedidoFabrica = isFabrica ? pedido as PedidoFabrica : null;
    final pedidoCliente = !isFabrica ? pedido as PedidoCliente : null;
    
    final numeroPedido = isFabrica
        ? (pedidoFabrica!.numeroPedido ?? 'Pedido #${pedidoFabrica.id}')
        : (pedidoCliente!.numeroPedido ?? 'Pedido #${pedidoCliente.id}');
    
    final info = isFabrica
        ? '${pedidoFabrica!.sucursal?.nombre ?? 'Sucursal'} • ${pedidoFabrica.totalItems} items'
        : '${pedidoCliente!.clienteNombre} • ${pedidoCliente.totalItems} items';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2F2218) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFabrica ? Icons.storefront : Icons.chat,
                color: isDark
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numeroPedido,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Seleccionar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
