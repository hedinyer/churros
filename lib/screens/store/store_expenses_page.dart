import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sucursal.dart';
import '../../models/user.dart';
import '../../services/supabase_service.dart';

class StoreExpensesPage extends StatefulWidget {
  final Sucursal sucursal;
  final AppUser currentUser;

  const StoreExpensesPage({
    super.key,
    required this.sucursal,
    required this.currentUser,
  });

  @override
  State<StoreExpensesPage> createState() => _StoreExpensesPageState();
}

class _StoreExpensesPageState extends State<StoreExpensesPage> {
  List<Map<String, dynamic>> _gastos = [];
  bool _isLoading = true;
  String _filtroTipo = 'todos'; // 'todos', 'personal', 'pago_pedido', 'pago_ocasional', 'otro'

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
      final gastos = await SupabaseService.getGastosPuntoVenta(
        sucursalId: widget.sucursal.id,
      );

      setState(() {
        _gastos = gastos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando gastos: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _agregarGasto() async {
    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    final categoriaController = TextEditingController();
    String tipoGasto = 'personal'; // 'personal', 'pago_pedido', 'pago_ocasional', 'otro'

    final resultado = await showDialog<bool>(
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
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Personal'),
                          selected: tipoGasto == 'personal',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tipoGasto = 'personal');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Pago Pedido'),
                          selected: tipoGasto == 'pago_pedido',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tipoGasto = 'pago_pedido');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Pago Ocasional'),
                          selected: tipoGasto == 'pago_ocasional',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tipoGasto = 'pago_ocasional');
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Otro'),
                          selected: tipoGasto == 'otro',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tipoGasto = 'otro');
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción *',
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Pago a proveedor, Salario empleado, etc.',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: categoriaController,
                      decoration: const InputDecoration(
                        labelText: 'Categoría (opcional)',
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Nómina, Proveedores, Servicios, etc.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: montoController,
                      decoration: const InputDecoration(
                        labelText: 'Monto *',
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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != true) return;

    final descripcion = descripcionController.text.trim();
    final categoria = categoriaController.text.trim();
    final monto = double.tryParse(montoController.text.trim());

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

    final exito = await SupabaseService.crearGastoPuntoVenta(
      sucursalId: widget.sucursal.id,
      usuarioId: widget.currentUser.id,
      descripcion: descripcion,
      monto: monto,
      tipo: tipoGasto,
      categoria: categoria.isEmpty ? null : categoria,
    );

    if (exito) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar el gasto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(amount);
  }


  String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'personal':
        return 'Personal';
      case 'pago_pedido':
        return 'Pago Pedido';
      case 'pago_ocasional':
        return 'Pago Ocasional';
      case 'otro':
        return 'Otro';
      default:
        return tipo;
    }
  }

  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'personal':
        return Icons.people;
      case 'pago_pedido':
        return Icons.shopping_cart;
      case 'pago_ocasional':
        return Icons.payment;
      case 'otro':
        return Icons.receipt;
      default:
        return Icons.receipt;
    }
  }

  Color _getTipoColor(String tipo) {
    switch (tipo) {
      case 'personal':
        return Colors.blue;
      case 'pago_pedido':
        return Colors.orange;
      case 'pago_ocasional':
        return Colors.purple;
      case 'otro':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _getGastosFiltrados() {
    if (_filtroTipo == 'todos') {
      return _gastos;
    }
    return _gastos.where((gasto) => gasto['tipo'] == _filtroTipo).toList();
  }

  double _getTotalGastos() {
    return _getGastosFiltrados().fold(0.0, (sum, gasto) {
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

    final gastosFiltrados = _getGastosFiltrados();

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
                  const SizedBox(width: 48), // Balance para el botón de back
                ],
              ),
            ),

            // Total y Filtros
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  // Total
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Gastos de Hoy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B130D),
                          ),
                        ),
                        Text(
                          _formatCurrency(_getTotalGastos()),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filtros
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          isDark: isDark,
                          label: 'Todos',
                          isSelected: _filtroTipo == 'todos',
                          onTap: () => setState(() => _filtroTipo = 'todos'),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          isDark: isDark,
                          label: 'Personal',
                          isSelected: _filtroTipo == 'personal',
                          onTap: () => setState(() => _filtroTipo = 'personal'),
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          isDark: isDark,
                          label: 'Pago Pedido',
                          isSelected: _filtroTipo == 'pago_pedido',
                          onTap: () => setState(() => _filtroTipo = 'pago_pedido'),
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          isDark: isDark,
                          label: 'Pago Ocasional',
                          isSelected: _filtroTipo == 'pago_ocasional',
                          onTap: () => setState(() => _filtroTipo = 'pago_ocasional'),
                          color: Colors.purple,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          isDark: isDark,
                          label: 'Otro',
                          isSelected: _filtroTipo == 'otro',
                          onTap: () => setState(() => _filtroTipo = 'otro'),
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de gastos
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: gastosFiltrados.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 64,
                                      color: isDark
                                          ? const Color(0xFFA8A29E)
                                          : const Color(0xFF78716C),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay gastos de hoy',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1B130D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: gastosFiltrados.length,
                              itemBuilder: (context, index) {
                                final gasto = gastosFiltrados[index];
                                return _buildGastoCard(
                                  isDark: isDark,
                                  gasto: gasto,
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarGasto,
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip({
    required bool isDark,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? (isDark ? Colors.white : const Color(0xFF1B130D));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor.withOpacity(isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withOpacity(isDark ? 0.3 : 0.2)
                : (isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? chipColor
                : (isDark
                    ? const Color(0xFFA8A29E)
                    : const Color(0xFF78716C)),
          ),
        ),
      ),
    );
  }

  Widget _buildGastoCard({
    required bool isDark,
    required Map<String, dynamic> gasto,
  }) {
    final descripcion = gasto['descripcion'] as String? ?? '';
    final monto = (gasto['monto'] as num?)?.toDouble() ?? 0.0;
    final tipo = gasto['tipo'] as String? ?? 'otro';
    final categoria = gasto['categoria'] as String?;

    final tipoIcon = _getTipoIcon(tipo);
    final tipoColor = _getTipoColor(tipo);
    final tipoLabel = _getTipoLabel(tipo);

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        descripcion,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1B130D),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tipoColor.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tipoLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: tipoColor,
                        ),
                      ),
                    ),
                  ],
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
