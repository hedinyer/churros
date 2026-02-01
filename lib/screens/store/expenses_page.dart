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
  List<PedidoCliente> _pedidosRecurrentes = [];
  List<PedidoCliente> _pedidosClientesPendientes = [];
  List<PedidoCliente> _pedidosRecurrentesPendientes = [];
  List<Map<String, dynamic>> _gastosVarios = [];
  bool _isLoading = true;
  int _selectedTab =
      0; // 0 = Pagos Entregados, 1 = Pagos Pendientes, 2 = Gastos Varios

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
      // Cargar pedidos de clientes entregados y pagados (para factory)
      final pedidos = await SupabaseService.getPedidosClientesPagados(
        limit: 1000,
      );

      // Cargar pedidos recurrentes entregados y pagados (para factory)
      final pedidosRecurrentes =
          await SupabaseService.getPedidosRecurrentesPagados(limit: 1000);

      // Cargar pedidos de clientes entregados pero con pago pendiente
      final pedidosClientesPendientes =
          await SupabaseService.getPedidosClientesPendientes(limit: 1000);

      // Cargar pedidos recurrentes entregados pero con pago pendiente
      final pedidosRecurrentesPendientes =
          await SupabaseService.getPedidosRecurrentesPendientes(limit: 1000);

      // Cargar gastos varios del día actual (ya filtrado por el servicio)
      final gastos = await SupabaseService.getGastosVarios();

      setState(() {
        _pedidosClientes = pedidos;
        _pedidosRecurrentes = pedidosRecurrentes;
        _pedidosClientesPendientes = pedidosClientesPendientes;
        _pedidosRecurrentesPendientes = pedidosRecurrentesPendientes;
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
                          items:
                              empleados.map((empleado) {
                                return DropdownMenuItem<Empleado>(
                                  value: empleado,
                                  child: Text(empleado.nombre),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              empleadoSeleccionado = value;
                              if (value != null) {
                                descripcionController.text =
                                    'Nómina - ${value.nombre}';
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
                        labelText:
                            tipoGasto == 'nomina'
                                ? 'Descripción (automática)'
                                : 'Descripción',
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
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
    // Soportar formatos comunes: 10.000 / 10,000 / $10000
    final montoDigits = montoController.text.trim().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final montoParsed = int.tryParse(montoDigits);
    final monto = montoParsed?.toDouble();
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
    // Sumar pedidos de clientes (excluyendo fiados, sin incluir domicilios)
    final totalClientes = _pedidosClientes.fold(0.0, (sum, pedido) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (esFiado) {
        return sum;
      }
      return sum + pedido.total;
    });

    // Sumar pedidos recurrentes (excluyendo fiados, sin incluir domicilios)
    final totalRecurrentes = _pedidosRecurrentes.fold(0.0, (sum, pedido) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (esFiado) {
        return sum;
      }
      return sum + pedido.total;
    });

    return totalClientes + totalRecurrentes;
  }

  double _getTotalPagosPendientes() {
    // Sumar TODOS los pedidos de clientes pendientes (incluyendo fiados) + domicilios
    final totalClientes = _pedidosClientesPendientes.fold(0.0, (sum, pedido) {
      final totalPedido = pedido.total;
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + totalPedido + domicilio;
    });

    // Sumar TODOS los pedidos recurrentes pendientes (incluyendo fiados) + domicilios
    final totalRecurrentes = _pedidosRecurrentesPendientes.fold(0.0, (
      sum,
      pedido,
    ) {
      final totalPedido = pedido.total;
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + totalPedido + domicilio;
    });

    return totalClientes + totalRecurrentes;
  }

  double _getTotalGastosVarios() {
    return _gastosVarios.fold(0.0, (sum, gasto) {
      final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
      return sum + monto;
    });
  }

  double _getTotalDomicilios() {
    // Sumar domicilios de pedidos de clientes NO fiados
    final totalClientes = _pedidosClientes.fold(0.0, (sum, pedido) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (esFiado) {
        return sum;
      }
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + domicilio;
    });

    // Sumar domicilios de pedidos recurrentes NO fiados
    final totalRecurrentes = _pedidosRecurrentes.fold(0.0, (sum, pedido) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (esFiado) {
        return sum;
      }
      final domicilio = pedido.domicilio ?? 0.0;
      return sum + domicilio;
    });

    return totalClientes + totalRecurrentes;
  }

  double _getTotalGeneral() {
    // Total del día = pagos (sin fiado) + domicilios - gastos varios
    return _getTotalPagos() + _getTotalDomicilios() - _getTotalGastosVarios();
  }

  double _getTotalEfectivo() {
    // Sumar pedidos pagados en efectivo (excluyendo fiados)
    double total = 0.0;

    // Pedidos de clientes pagados
    for (final pedido in _pedidosClientes) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (!esFiado && pedido.metodoPago?.toUpperCase() == 'EFECTIVO') {
        total += pedido.total;
      }
    }

    // Pedidos recurrentes pagados
    for (final pedido in _pedidosRecurrentes) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (!esFiado && pedido.metodoPago?.toUpperCase() == 'EFECTIVO') {
        total += pedido.total;
      }
    }

    return total;
  }

  double _getTotalTransferencia() {
    // Sumar pedidos pagados en transferencia (excluyendo fiados)
    double total = 0.0;

    // Pedidos de clientes pagados
    for (final pedido in _pedidosClientes) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (!esFiado && pedido.metodoPago?.toUpperCase() == 'TRANSFERENCIA') {
        total += pedido.total;
      }
    }

    // Pedidos recurrentes pagados
    for (final pedido in _pedidosRecurrentes) {
      final observaciones = pedido.observaciones ?? '';
      final esFiado = observaciones.toUpperCase().contains('FIADO');
      if (!esFiado && pedido.metodoPago?.toUpperCase() == 'TRANSFERENCIA') {
        total += pedido.total;
      }
    }

    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;

    final totalPagos = _getTotalPagos();
    final totalDomicilios = _getTotalDomicilios();
    final totalGastosVarios = _getTotalGastosVarios();
    final totalGeneral = _getTotalGeneral();
    final totalEfectivo = _getTotalEfectivo();
    final totalTransferencia = _getTotalTransferencia();

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
                      'Gastos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _agregarGastoVario,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.add_circle_outline,
                          size: 24,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
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
                    color:
                        isDark
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
                      label: 'Pagos\nEntregados',
                      isSelected: _selectedTab == 0,
                      total: _getTotalPagos(),
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Pagos\nPendientes',
                      isSelected: _selectedTab == 1,
                      total: _getTotalPagosPendientes(),
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      isDark: isDark,
                      label: 'Gastos\nVarios',
                      isSelected: _selectedTab == 2,
                      total: _getTotalGastosVarios(),
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: _loadData,
                        child:
                            _selectedTab == 0
                                ? _buildPagosPedidosList(
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                )
                                : _selectedTab == 1
                                ? _buildPagosPendientesList(
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                )
                                : _buildGastosVariosList(
                                  isDark: isDark,
                                  primaryColor: primaryColor,
                                ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarGastoVario,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: isSmallScreen ? 16 : 20,
          right: isSmallScreen ? 16 : 20,
          top: 12,
          bottom: 12 + mediaQuery.padding.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D211A) : Colors.white,
          border: Border(
            top: BorderSide(
              color:
                  isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pagos (sin fiado)',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFFA8A29E)
                                  : const Color(0xFF78716C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalPagos),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Efectivo',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFFA8A29E)
                                  : const Color(0xFF78716C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalEfectivo),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Domicilios',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFFA8A29E)
                                  : const Color(0xFF78716C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalDomicilios),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Transferencia',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFFA8A29E)
                                  : const Color(0xFF78716C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalTransferencia),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gastos Varios',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFFA8A29E)
                                  : const Color(0xFF78716C),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(totalGastosVarios),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL (Pago + domi - Gasto)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B130D),
                    ),
                  ),
                  Text(
                    _formatCurrency(totalGeneral),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          color:
              isSelected
                  ? (isDark ? const Color(0xFF221810) : const Color(0xFFF8F7F6))
                  : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFFEC6D13) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color:
                    isSelected
                        ? (isDark ? Colors.white : const Color(0xFF1B130D))
                        : (isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C)),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            Text(
              _formatCurrency(total),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color:
                    isSelected
                        ? const Color(0xFFEC6D13)
                        : (isDark
                            ? const Color(0xFF9A6C4C)
                            : const Color(0xFF9A6C4C)),
              ),
              textAlign: TextAlign.center,
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
    // Combinar ambos tipos de pedidos
    final todosLosPedidos = [..._pedidosClientes, ..._pedidosRecurrentes];

    // Ordenar por fecha de creación (más recientes primero)
    todosLosPedidos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (todosLosPedidos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment_outlined,
                size: 64,
                color:
                    isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay pagos entregados',
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
      itemCount: todosLosPedidos.length,
      itemBuilder: (context, index) {
        final pedido = todosLosPedidos[index];
        // Verificar si es un pedido recurrente (está en la lista de recurrentes)
        final esRecurrente = _pedidosRecurrentes.any((p) => p.id == pedido.id);
        return _buildPagoPedidoCard(
          isDark: isDark,
          pedido: pedido,
          primaryColor: primaryColor,
          esRecurrente: esRecurrente,
        );
      },
    );
  }

  Widget _buildPagosPendientesList({
    required bool isDark,
    required Color primaryColor,
  }) {
    // Combinar ambos tipos de pedidos pendientes
    final todosLosPedidos = [
      ..._pedidosClientesPendientes,
      ..._pedidosRecurrentesPendientes,
    ];

    // Ordenar por fecha de creación (más recientes primero)
    todosLosPedidos.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (todosLosPedidos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pending_outlined,
                size: 64,
                color:
                    isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay pagos pendientes',
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
      itemCount: todosLosPedidos.length,
      itemBuilder: (context, index) {
        final pedido = todosLosPedidos[index];
        // Verificar si es un pedido recurrente (está en la lista de recurrentes)
        final esRecurrente = _pedidosRecurrentesPendientes.any(
          (p) => p.id == pedido.id,
        );
        return _buildPagoPedidoCard(
          isDark: isDark,
          pedido: pedido,
          primaryColor: primaryColor,
          esRecurrente: esRecurrente,
          esPendiente: true,
        );
      },
    );
  }

  Future<void> _mostrarModalConfirmarPago({
    required PedidoCliente pedido,
    required bool esRecurrente,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resultado = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF2D211A) : Colors.white,
            title: Text(
              '¿Pedido pagado?',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
            ),
            content: Text(
              '¿Deseas marcar este pedido como pagado?',
              style: TextStyle(
                color: isDark ? Colors.white70 : const Color(0xFF78716C),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'No',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF78716C),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC6D13),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sí'),
              ),
            ],
          ),
    );

    if (resultado == true && mounted) {
      // Marcar como pagado
      final exito =
          esRecurrente
              ? await SupabaseService.marcarPedidoRecurrenteComoPagado(
                pedidoId: pedido.id,
              )
              : await SupabaseService.marcarPedidoClienteComoPagado(
                pedidoId: pedido.id,
              );

      if (mounted) {
        if (exito) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Pedido marcado como pagado'),
              backgroundColor: Colors.green,
            ),
          );
          // Recargar datos
          _loadData();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Error al marcar el pedido como pagado'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildPagoPedidoCard({
    required bool isDark,
    required PedidoCliente pedido,
    required Color primaryColor,
    bool esRecurrente = false,
    bool esPendiente = false,
  }) {
    final observaciones = pedido.observaciones ?? '';
    final esFiado = observaciones.toUpperCase().contains('FIADO');

    return GestureDetector(
      onTap:
          esPendiente
              ? () => _mostrarModalConfirmarPago(
                pedido: pedido,
                esRecurrente: esRecurrente,
              )
              : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D211A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                esPendiente
                    ? Colors.orange.withOpacity(0.3)
                    : (isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.08)),
            width: esPendiente ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  esPendiente
                      ? Colors.orange.withOpacity(0.2)
                      : Colors.black.withOpacity(isDark ? 0.25 : 0.05),
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
                          color:
                              isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              pedido.numeroPedido ?? 'Pedido #${pedido.id}',
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF9A6C4C),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (esRecurrente) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.teal.withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'RECURRENTE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Mostrar total + domicilio si existe
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(pedido.total),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        if (pedido.domicilio != null &&
                            pedido.domicilio! > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_shipping,
                                size: 12,
                                color:
                                    isDark
                                        ? const Color(0xFF9A6C4C)
                                        : const Color(0xFF9A6C4C),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatCurrency(pedido.domicilio!),
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
                        ],
                      ],
                    ),
                    if (esFiado)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'FIADO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (esPendiente)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'PENDIENTE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.payment,
                  size: 14,
                  color:
                      isDark
                          ? const Color(0xFF9A6C4C)
                          : const Color(0xFF9A6C4C),
                ),
                const SizedBox(width: 4),
                Text(
                  pedido.metodoPago ?? 'efectivo',
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
            if (observaciones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  observaciones,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isDark
                            ? const Color(0xFFA8A29E)
                            : const Color(0xFF78716C),
                  ),
                ),
              ),
            // Total en la esquina inferior
            if (pedido.domicilio != null && pedido.domicilio! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Total: ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    Text(
                      _formatCurrency(pedido.total + pedido.domicilio!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
                color:
                    isDark ? const Color(0xFFA8A29E) : const Color(0xFF78716C),
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
      padding: const EdgeInsets.all(18),
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
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
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
                      color:
                          isDark
                              ? const Color(0xFF9A6C4C)
                              : const Color(0xFF9A6C4C),
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
