import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/pedido_cliente.dart';
import '../../models/empleado.dart';
import '../../services/supabase_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<PedidoCliente> _pedidosClientes = [];
  List<Map<String, dynamic>> _gastosVarios = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0 = Pagos Pedidos, 1 = Gastos Varios

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
      // Cargar pedidos de clientes (pagos) del día actual
      final pedidos = await SupabaseService.getPedidosClientesRecientes(
        limit: 1000,
        soloHoy: true,
      );
      
      // Cargar gastos varios del día actual (ya filtrado por el servicio)
      final gastos = await SupabaseService.getGastosVarios();

      setState(() {
        _pedidosClientes = pedidos;
        _gastosVarios = gastos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos de gastos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _agregarGastoVario() async {
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    final categoriaController = TextEditingController();
    String tipoGasto = 'compra'; // 'compra', 'pago', 'otro', 'nomina'
    Empleado? empleadoSeleccionado;
    List<Empleado> empleados = [];

    // Cargar empleados
    try {
      empleados = await SupabaseService.getEmpleadosActivos();
    } catch (e) {
      print('Error cargando empleados: $e');
    }

    final resultado = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Agregar Gasto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipo de gasto
                    Text(
                      'Tipo de gasto',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Compra'),
                          selected: tipoGasto == 'compra',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tipoGasto = 'compra';
                                empleadoSeleccionado = null;
                                descripcionController.clear();
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Pago'),
                          selected: tipoGasto == 'pago',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tipoGasto = 'pago';
                                empleadoSeleccionado = null;
                                descripcionController.clear();
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Nómina'),
                          selected: tipoGasto == 'nomina',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tipoGasto = 'nomina';
                                empleadoSeleccionado = null;
                                descripcionController.clear();
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Otro'),
                          selected: tipoGasto == 'otro',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                tipoGasto = 'otro';
                                empleadoSeleccionado = null;
                                descripcionController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Selector de empleado (solo para nómina)
                    if (tipoGasto == 'nomina') ...[
                      Text(
                        'Empleado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButton<Empleado>(
                          value: empleadoSeleccionado,
                          hint: const Text('Selecciona un empleado'),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: empleados.map((empleado) {
                            return DropdownMenuItem<Empleado>(
                              value: empleado,
                              child: Text(empleado.nombre),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              empleadoSeleccionado = value;
                              if (value != null) {
                                descripcionController.text = 'Nómina - ${value.nombre}';
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextField(
                      controller: descripcionController,
                      decoration: InputDecoration(
                        labelText: tipoGasto == 'nomina' ? 'Descripción (automática)' : 'Descripción',
                        border: const OutlineInputBorder(),
                        enabled: tipoGasto != 'nomina',
                      ),
                      maxLines: 2,
                    ),
                    if (tipoGasto != 'nomina') ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: categoriaController,
                        decoration: const InputDecoration(
                          labelText: 'Categoría (opcional)',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: Insumos, Servicios, etc.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: montoController,
                      decoration: const InputDecoration(
                        labelText: 'Monto',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Validar que si es nómina, haya un empleado seleccionado
                    if (tipoGasto == 'nomina' && empleadoSeleccionado == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debes seleccionar un empleado'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'tipo': tipoGasto,
                      'empleado': empleadoSeleccionado,
                    });
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == null) return;

    final descripcion = descripcionController.text.trim();
    final categoria = categoriaController.text.trim();
    final monto = double.tryParse(montoController.text.trim());
    final empleado = resultado['empleado'] as Empleado?;

    if (descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La descripción es requerida'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto debe ser mayor a 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (resultado['tipo'] == 'nomina' && empleado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un empleado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final exito = await SupabaseService.crearGastoVario(
      descripcion: descripcion,
      monto: monto,
      tipo: resultado['tipo'] as String,
      categoria: categoria.isEmpty ? null : categoria,
      empleadoId: empleado?.id,
    );

    if (exito) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto agregado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al agregar el gasto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
  }


  double _getTotalPagos() {
    return _pedidosClientes.fold(0.0, (sum, pedido) => sum + pedido.total);
  }

  double _getTotalGastosVarios() {
    return _gastosVarios.fold(0.0, (sum, gasto) {
      final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
      return sum + monto;
    });
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
                      'Gastos de Hoy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle),
                    onPressed: _selectedTab == 1 ? _agregarGastoVario : null,
                    color: _selectedTab == 1
                        ? (isDark ? Colors.white : const Color(0xFF1B130D))
                        : Colors.grey,
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      shape: const CircleBorder(),
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D211A) : Colors.white,
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
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Pagos de Hoy',
                      isSelected: _selectedTab == 0,
                      total: _getTotalPagos(),
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Gastos Varios',
                      isSelected: _selectedTab == 1,
                      total: _getTotalGastosVarios(),
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: _selectedTab == 0
                          ? _buildPagosPedidosList(isDark: isDark, primaryColor: primaryColor)
                          : _buildGastosVariosList(isDark: isDark, primaryColor: primaryColor),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton(
              onPressed: _agregarGastoVario,
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabButton({
    required bool isDark,
    required String label,
    required bool isSelected,
    required double total,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? const Color(0xFFEC6D13)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1B130D))
                    : (isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatCurrency(total),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? const Color(0xFFEC6D13)
                    : (isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagosPedidosList({
    required bool isDark,
    required Color primaryColor,
  }) {
    if (_pedidosClientes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment_outlined,
                size: 64,
                color: isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay pagos de hoy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B130D),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pedidosClientes.length,
      itemBuilder: (context, index) {
        final pedido = _pedidosClientes[index];
        return _buildPagoPedidoCard(
          isDark: isDark,
          pedido: pedido,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildPagoPedidoCard({
    required bool isDark,
    required PedidoCliente pedido,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF44403C)
              : const Color(0xFFE7E5E4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.clienteNombre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pedido.numeroPedido ?? 'Pedido #${pedido.id}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(pedido.total),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.payment,
                size: 14,
                color: isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
              ),
              const SizedBox(width: 4),
              Text(
                pedido.metodoPago ?? 'efectivo',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGastosVariosList({
    required bool isDark,
    required Color primaryColor,
  }) {
    if (_gastosVarios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay gastos varios de hoy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B130D),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gastosVarios.length,
      itemBuilder: (context, index) {
        final gasto = _gastosVarios[index];
        return _buildGastoVarioCard(
          isDark: isDark,
          gasto: gasto,
          primaryColor: primaryColor,
        );
      },
    );
  }

  Widget _buildGastoVarioCard({
    required bool isDark,
    required Map<String, dynamic> gasto,
    required Color primaryColor,
  }) {
    final descripcion = gasto['descripcion'] as String? ?? '';
    final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
    final tipo = gasto['tipo'] as String? ?? 'otro';
    final categoria = gasto['categoria'] as String?;

    IconData tipoIcon;
    Color tipoColor;
    switch (tipo) {
      case 'compra':
        tipoIcon = Icons.shopping_cart;
        tipoColor = Colors.blue;
        break;
      case 'pago':
        tipoIcon = Icons.payment;
        tipoColor = Colors.orange;
        break;
      default:
        tipoIcon = Icons.receipt;
        tipoColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF44403C)
              : const Color(0xFFE7E5E4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tipoColor.withOpacity(isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(tipoIcon, color: tipoColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                  ),
                ),
                if (categoria != null && categoria.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    categoria,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9A6C4C) : const Color(0xFF9A6C4C),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatCurrency(monto),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}
