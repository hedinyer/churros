import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/apertura_dia.dart';
import '../../models/categoria.dart';
import '../../models/producto.dart';
import '../../models/sucursal.dart';
import '../../services/supabase_service.dart';

class MasterOpeningInventoryPage extends StatefulWidget {
  final Sucursal sucursal;

  const MasterOpeningInventoryPage({
    super.key,
    required this.sucursal,
  });

  @override
  State<MasterOpeningInventoryPage> createState() =>
      _MasterOpeningInventoryPageState();
}

class _MasterOpeningInventoryPageState extends State<MasterOpeningInventoryPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  AperturaDia? _aperturaDia;

  List<Producto> _productos = [];
  Map<int, Categoria> _categoriasMap = {};
  Map<int, int> _inventarioApertura = {};
  Map<int, int> _inventarioEditado = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _selectedCategoriaFilter = -1;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _saveBarController;
  late Animation<double> _saveBarAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _saveBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _saveBarAnimation = CurvedAnimation(
      parent: _saveBarController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _saveBarController.dispose();
    super.dispose();
  }

  void _checkAndAnimateSaveBar() {
    if (_hasChanges() && !_saveBarController.isCompleted) {
      _saveBarController.forward();
    } else if (!_hasChanges() && _saveBarController.isCompleted) {
      _saveBarController.reverse();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final productos = await SupabaseService.getProductosActivos();
      final categorias = await SupabaseService.getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};

      // Obtener apertura del día para la sucursal
      final apertura =
          await SupabaseService.getAperturaDiaActual(widget.sucursal.id);

      Map<int, int> inventarioApertura = {};

      if (apertura != null) {
        inventarioApertura =
            await SupabaseService.getInventarioAperturaPorApertura(
          apertura.id,
        );
      }

      // Asegurar que todos los productos existan en el mapa (con 0 por defecto)
      for (final producto in productos) {
        inventarioApertura.putIfAbsent(producto.id, () => 0);
      }

      setState(() {
        _productos = productos;
        _categoriasMap = categoriasMap;
        _aperturaDia = apertura;
        _inventarioApertura = inventarioApertura;
        _inventarioEditado = Map.from(inventarioApertura);
        _isLoading = false;
      });

      _fadeController.forward(from: 0);
    } catch (e) {
      print('Error cargando inventario de apertura: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _hasChanges() {
    if (_inventarioEditado.length != _inventarioApertura.length) return true;
    for (var entry in _inventarioEditado.entries) {
      if (_inventarioApertura[entry.key] != entry.value) return true;
    }
    return false;
  }

  int _changedCount() {
    int count = 0;
    for (var entry in _inventarioEditado.entries) {
      if (_inventarioApertura[entry.key] != entry.value) count++;
    }
    return count;
  }

  List<Producto> _getFilteredProductos() {
    var filtered = _productos;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((p) => p.nombre.toLowerCase().contains(query))
          .toList();
    }

    if (_selectedCategoriaFilter != -1) {
      filtered = filtered.where((p) {
        if (_selectedCategoriaFilter == 0) return p.categoria == null;
        return p.categoria?.id == _selectedCategoriaFilter;
      }).toList();
    }

    filtered.sort((a, b) {
      final ia = _inventarioEditado[a.id] ?? 0;
      final ib = _inventarioEditado[b.id] ?? 0;
      return ib.compareTo(ia);
    });

    return filtered;
  }

  Future<void> _saveInventory() async {
    if (_aperturaDia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay apertura creada para hoy en este punto. La apertura solo se puede crear desde la app de tienda.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_hasChanges()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmDialog(
        title: 'Guardar apertura',
        message:
            '¿Guardar los cambios del inventario de apertura de hoy en ${widget.sucursal.nombre}? (${_changedCount()} productos modificados)',
        confirmText: 'Guardar',
        confirmColor: const Color(0xFFEC6D13),
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      // Asegurar que todos los productos estén presentes (incluyendo 0)
      final inventarioCompleto = <int, int>{};
      for (final producto in _productos) {
        inventarioCompleto[producto.id] =
            _inventarioEditado[producto.id] ?? 0;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _buildLoadingDialog(),
      );

      final saved = await SupabaseService.guardarInventarioInicial(
        aperturaId: _aperturaDia!.id,
        inventario: inventarioCompleto,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (saved) {
        setState(() {
          _inventarioApertura = Map.from(inventarioCompleto);
          _inventarioEditado = Map.from(inventarioCompleto);
        });
        _checkAndAnimateSaveBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Inventario de apertura actualizado'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        _showErrorSnackbar('No se pudo guardar el inventario de apertura');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Error al guardar: $e');
    }
  }

  void _editProductInventory(Producto producto) {
    final currentValue = _inventarioEditado[producto.id] ?? 0;
    final controller = TextEditingController(text: currentValue.toString());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);

    showDialog(
      context: context,
      builder: (ctx) {
        int tempValue = currentValue;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor:
                  isDark ? const Color(0xFF2C2018) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.inventory_2_rounded,
                          size: 28, color: primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      producto.nombre,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cantidad de apertura de hoy',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF9C9591)
                            : const Color(0xFF8A8380),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDialogQtyButton(
                          Icons.remove_rounded,
                          enabled: tempValue > 0,
                          onTap: () {
                            if (tempValue > 0) {
                              setDialogState(() {
                                tempValue--;
                                controller.text = tempValue.toString();
                              });
                            }
                          },
                          isDark: isDark,
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1B130D),
                            ),
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? const Color(0xFF44403C)
                                      : const Color(0xFFE7E5E4),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                tempValue = int.tryParse(val) ?? 0;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        _buildDialogQtyButton(
                          Icons.add_rounded,
                          enabled: true,
                          onTap: () {
                            setDialogState(() {
                              tempValue++;
                              controller.text = tempValue.toString();
                            });
                          },
                          isDark: isDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF9C9591)
                                    : const Color(0xFF8A8380),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final value =
                                  int.tryParse(controller.text) ?? 0;
                              setState(() {
                                _inventarioEditado[producto.id] = value;
                              });
                              _checkAndAnimateSaveBar();
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogQtyButton(
    IconData icon, {
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? (isDark
                    ? const Color(0xFF3D3530)
                    : const Color(0xFFF5F3F1))
                : (isDark
                    ? const Color(0xFF2C2018)
                    : const Color(0xFFFAF9F8)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF44403C)
                  : const Color(0xFFE7E5E4),
            ),
          ),
          child: Icon(
            icon,
            size: 24,
            color: enabled
                ? (isDark ? Colors.white : const Color(0xFF1B130D))
                : (isDark
                    ? const Color(0xFF44403C)
                    : const Color(0xFFD6D3D1)),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2018) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 48, color: confirmColor),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1B130D),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF9C9591)
                    : const Color(0xFF8A8380),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF9C9591)
                            : const Color(0xFF8A8380),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2C2018) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(Color(0xFFEC6D13)),
            ),
            SizedBox(height: 20),
            Text(
              'Guardando...',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final horizontalPad = isSmallScreen ? 16.0 : 24.0;

    final filteredProductos = _getFilteredProductos();
    final changed = _changedCount();
    final totalProducts = _productos.length;
    final inStock =
        _inventarioEditado.values.where((v) => v > 0).length;
    final outOfStock = totalProducts - inStock;

    // Deshabilitar escalado de texto del sistema
    final mediaQueryData = MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(1.0),
    );

    return MediaQuery(
      data: mediaQueryData,
      child: WillPopScope(
        onWillPop: () async {
          if (_hasChanges()) {
            final shouldPop = await showDialog<bool>(
              context: context,
              builder: (ctx) => _buildConfirmDialog(
                title: '¿Salir sin guardar?',
                message:
                    'Tienes $changed cambios sin guardar. Se perderán al salir.',
                confirmText: 'Salir',
                confirmColor: Colors.red,
                icon: Icons.exit_to_app_rounded,
              ),
            );
            return shouldPop ?? false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF221810) : const Color(0xFFF5F3F1),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(isDark, primaryColor, horizontalPad, changed),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    primaryColor),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Cargando inventario de apertura...',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? const Color(0xFFA8A29E)
                                      : const Color(0xFF78716C),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: Stack(
                            children: [
                              CustomScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: _buildStatsBar(
                                      isDark,
                                      primaryColor,
                                      horizontalPad,
                                      totalProducts,
                                      inStock,
                                      outOfStock,
                                      changed,
                                    ),
                                  ),
                                  if (_aperturaDia == null)
                                    SliverToBoxAdapter(
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          horizontalPad,
                                          0,
                                          horizontalPad,
                                          8,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red
                                                .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.red
                                                  .withOpacity(0.4),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.info_outline_rounded,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'No hay apertura creada para hoy en este punto.\n\n'
                                                  'La apertura del día se crea desde la app de tienda. '
                                                  'Aquí solo puedes ajustar el inventario de aperturas ya existentes.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFFECACA)
                                                        : const Color(
                                                            0xFF991B1B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  SliverToBoxAdapter(
                                    child: _buildSearchBar(
                                        isDark, horizontalPad),
                                  ),
                                  SliverToBoxAdapter(
                                    child: _buildCategoryFilters(
                                        isDark, primaryColor,
                                        horizontalPad),
                                  ),
                                  filteredProductos.isEmpty
                                      ? SliverFillRemaining(
                                          child: Center(
                                            child: Column(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Icon(
                                                    Icons
                                                        .search_off_rounded,
                                                    size: 56,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFF44403C)
                                                        : const Color(
                                                            0xFFD6D3D1)),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Sin resultados',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: isDark
                                                        ? const Color(
                                                            0xFFA8A29E)
                                                        : const Color(
                                                            0xFF78716C),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : SliverPadding(
                                          padding: EdgeInsets.fromLTRB(
                                              horizontalPad,
                                              8,
                                              horizontalPad,
                                              _hasChanges() ? 100 : 20),
                                          sliver: SliverList(
                                            delegate:
                                                SliverChildBuilderDelegate(
                                              (context, index) {
                                                final producto =
                                                    filteredProductos[
                                                        index];
                                                final cantidad =
                                                    _inventarioEditado[
                                                            producto.id] ??
                                                        0;
                                                final hasChanged =
                                                    _inventarioApertura[
                                                            producto.id] !=
                                                        _inventarioEditado[
                                                            producto.id];

                                                return _buildProductCard(
                                                  producto,
                                                  cantidad,
                                                  hasChanged,
                                                  isDark,
                                                  primaryColor,
                                                );
                                              },
                                              childCount:
                                                  filteredProductos.length,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                              if (_hasChanges())
                                Positioned(
                                  left: horizontalPad,
                                  right: horizontalPad,
                                  bottom: 16,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 2),
                                      end: Offset.zero,
                                    ).animate(_saveBarAnimation),
                                    child: _buildFloatingSaveBar(
                                        isDark, primaryColor, changed),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
      bool isDark, Color primaryColor, double horizontalPad, int changed) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          horizontalPad - 8, 12, horizontalPad, 12),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2018)
                      : const Color(0xFFEDE9E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 22,
                  color: isDark
                      ? const Color(0xFFD6D3D1)
                      : const Color(0xFF57534E),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.sucursal.nombre,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1B130D),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Inventario apertura',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? const Color(0xFF9C9591)
                        : const Color(0xFF8A8380),
                  ),
                ),
              ],
            ),
          ),
          if (changed > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$changed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(
    bool isDark,
    Color primaryColor,
    double horizontalPad,
    int total,
    int inStock,
    int outOfStock,
    int changed,
  ) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 16),
      child: Row(
        children: [
          _buildStatChip(
            '$total',
            'Total',
            isDark
                ? const Color(0xFF3D3530)
                : const Color(0xFFEDE9E6),
            isDark ? Colors.white : const Color(0xFF1B130D),
            isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            '$inStock',
            'Con stock',
            const Color(0xFF10B981).withOpacity(isDark ? 0.15 : 0.1),
            const Color(0xFF10B981),
            isDark,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            '$outOfStock',
            'Sin stock',
            const Color(0xFFEF4444).withOpacity(isDark ? 0.15 : 0.1),
            const Color(0xFFEF4444),
            isDark,
          ),
          if (changed > 0) ...[
            const SizedBox(width: 8),
            _buildStatChip(
              '$changed',
              'Editados',
              primaryColor.withOpacity(isDark ? 0.15 : 0.1),
              primaryColor,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String value, String label, Color bg, Color fg, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFF9C9591)
                    : const Color(0xFF8A8380),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, double horizontalPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPad, 0, horizontalPad, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF1B130D),
        ),
        decoration: InputDecoration(
          hintText: 'Buscar producto...',
          hintStyle: TextStyle(
            color:
                isDark ? const Color(0xFF78716C) : const Color(0xFFA8A29E),
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.search_rounded,
              color: isDark
                  ? const Color(0xFF78716C)
                  : const Color(0xFFA8A29E)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 20,
                      color: isDark
                          ? const Color(0xFF78716C)
                          : const Color(0xFFA8A29E)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark ? const Color(0xFF2C2018) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF3D3530)
                  : const Color(0xFFE7E5E4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide:
                const BorderSide(color: Color(0xFFEC6D13), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(
      bool isDark, Color primaryColor, double horizontalPad) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPad),
        children: [
          _buildCatChip('Todos', -1, isDark, primaryColor),
          const SizedBox(width: 8),
          _buildCatChip('Sin categoría', 0, isDark, primaryColor),
          ..._categoriasMap.values.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _buildCatChip(
                  cat.nombre, cat.id, isDark, primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatChip(
      String label, int value, bool isDark, Color primaryColor) {
    final isSelected = _selectedCategoriaFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedCategoriaFilter = value),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? const Color(0xFF2C2018)
                    : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark
                      ? const Color(0xFF3D3530)
                      : const Color(0xFFE7E5E4)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark
                      ? const Color(0xFFD6D3D1)
                      : const Color(0xFF57534E)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(
    Producto producto,
    int cantidad,
    bool hasChanged,
    bool isDark,
    Color primaryColor,
  ) {
    final originalQty = _inventarioApertura[producto.id] ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _editProductInventory(producto),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: hasChanged
                ? primaryColor.withOpacity(isDark ? 0.12 : 0.06)
                : (isDark ? const Color(0xFF2C2018) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasChanged
                  ? primaryColor.withOpacity(0.5)
                  : (isDark
                      ? const Color(0xFF3D3530).withOpacity(0.6)
                      : const Color(0xFFE7E5E4).withOpacity(0.7)),
              width: hasChanged ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto.nombre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1B130D),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          producto.categoria?.nombre ?? 'Sin categoría',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF9C9591)
                                : const Color(0xFF8A8380),
                          ),
                        ),
                        const Spacer(),
                        if (hasChanged)
                          Text(
                            'Antes: $originalQty',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? const Color(0xFF9C9591)
                                  : const Color(0xFF8A8380),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$cantidad',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Apertura',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF9C9591)
                          : const Color(0xFF8A8380),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingSaveBar(
      bool isDark, Color primaryColor, int changed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isDark
              ? const Color(0xFF3D3530)
              : const Color(0xFFE7E5E4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                Icon(Icons.edit_rounded,
                    size: 16, color: primaryColor),
                const SizedBox(width: 6),
                Text(
                  '$changed cambios',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1B130D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Guarda para actualizar la apertura de hoy',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF9C9591)
                    : const Color(0xFF8A8380),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _saveInventory,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Guardar',
              style:
                  TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

