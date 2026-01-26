import 'package:flutter/material.dart';
import '../../models/empleado.dart';
import '../../services/factory_section_tracker.dart';
import '../../services/supabase_service.dart';

class EmployeesManagementPage extends StatefulWidget {
  const EmployeesManagementPage({super.key});

  @override
  State<EmployeesManagementPage> createState() =>
      _EmployeesManagementPageState();
}

class _EmployeesManagementPageState extends State<EmployeesManagementPage> {
  List<Empleado> _empleados = [];
  bool _isLoading = true;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    FactorySectionTracker.enter();
    _loadData();
  }

  @override
  void dispose() {
    FactorySectionTracker.exit();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final empleados = await SupabaseService.getAllEmpleados();

      setState(() {
        _empleados = empleados;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando empleados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Empleado> _getEmpleadosFiltrados() {
    if (_busqueda.isEmpty) {
      return _empleados;
    }
    return _empleados
        .where(
          (e) =>
              e.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
              (e.email?.toLowerCase().contains(_busqueda.toLowerCase()) ??
                  false) ||
              (e.telefono?.contains(_busqueda) ?? false),
        )
        .toList();
  }

  Future<void> _eliminarEmpleado(Empleado empleado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: Text(
              '¿Estás seguro de que deseas eliminar "${empleado.nombre}"?',
            ),
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
      final exito = await SupabaseService.eliminarEmpleado(empleado.id);
      if (exito) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Empleado eliminado exitosamente')),
          );
          _loadData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al eliminar empleado')),
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
                      'Gestión de Empleados',
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
                      onTap: () => _mostrarDialogoEmpleado(),
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

            // Buscador
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar empleados...',
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

            // Lista de empleados
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: _loadData,
                        child:
                            _getEmpleadosFiltrados().isEmpty
                                ? Center(
                                  child: Text(
                                    'No hay empleados',
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
                                  itemCount: _getEmpleadosFiltrados().length,
                                  itemBuilder: (context, index) {
                                    final empleado =
                                        _getEmpleadosFiltrados()[index];
                                    return _buildEmpleadoCard(empleado, isDark);
                                  },
                                ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpleadoCard(Empleado empleado, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF2D211A) : Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEC6D13).withOpacity(0.2),
          child: Text(
            empleado.nombre.isNotEmpty ? empleado.nombre[0].toUpperCase() : 'E',
            style: const TextStyle(
              color: Color(0xFFEC6D13),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          empleado.nombre,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B130D),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (empleado.telefono != null && empleado.telefono!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 14, color: Color(0xFF9A6C4C)),
                    const SizedBox(width: 4),
                    Text(
                      empleado.telefono!,
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
              ),
            if (empleado.email != null && empleado.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.email, size: 14, color: Color(0xFF9A6C4C)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        empleado.email!,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFF9A6C4C)
                                  : const Color(0xFF9A6C4C),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    empleado.activo
                        ? Colors.green.withOpacity(isDark ? 0.2 : 0.1)
                        : Colors.red.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                empleado.activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  fontSize: 10,
                  color: empleado.activo ? Colors.green : Colors.red,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(
            Icons.more_vert,
            color: isDark ? Colors.white : const Color(0xFF1B130D),
          ),
          itemBuilder:
              (context) => [
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
                      _mostrarDialogoEmpleado(empleado: empleado);
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
                      _eliminarEmpleado(empleado);
                    });
                  },
                ),
              ],
        ),
      ),
    );
  }

  void _mostrarDialogoEmpleado({Empleado? empleado}) {
    final nombreController = TextEditingController(
      text: empleado?.nombre ?? '',
    );
    final telefonoController = TextEditingController(
      text: empleado?.telefono ?? '',
    );
    final emailController = TextEditingController(text: empleado?.email ?? '');
    bool activo = empleado?.activo ?? true;

    // Guardar referencia al ScaffoldMessenger antes de abrir el diálogo
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder:
              (context, setDialogState) => AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF2D211A) : Colors.white,
                title: Text(
                  empleado == null ? 'Nuevo Empleado' : 'Editar Empleado',
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
                          fillColor:
                              isDark
                                  ? const Color(0xFF221810)
                                  : Colors.grey[100],
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: telefonoController,
                        decoration: InputDecoration(
                          labelText: 'Teléfono',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          filled: true,
                          fillColor:
                              isDark
                                  ? const Color(0xFF221810)
                                  : Colors.grey[100],
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          filled: true,
                          fillColor:
                              isDark
                                  ? const Color(0xFF221810)
                                  : Colors.grey[100],
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        keyboardType: TextInputType.emailAddress,
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
                          const SnackBar(
                            content: Text('El nombre es requerido'),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);

                      if (empleado == null) {
                        // Crear nuevo empleado
                        final nuevoEmpleado =
                            await SupabaseService.crearEmpleado(
                              nombre: nombreController.text,
                              telefono:
                                  telefonoController.text.isEmpty
                                      ? null
                                      : telefonoController.text,
                              email:
                                  emailController.text.isEmpty
                                      ? null
                                      : emailController.text,
                              activo: activo,
                            );

                        if (nuevoEmpleado != null && mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Empleado creado exitosamente'),
                            ),
                          );
                          _loadData();
                        } else if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Error al crear empleado'),
                            ),
                          );
                        }
                      } else {
                        // Actualizar empleado existente
                        final empleadoActualizado =
                            await SupabaseService.actualizarEmpleado(
                              empleadoId: empleado.id,
                              nombre: nombreController.text,
                              telefono:
                                  telefonoController.text.isEmpty
                                      ? null
                                      : telefonoController.text,
                              email:
                                  emailController.text.isEmpty
                                      ? null
                                      : emailController.text,
                              activo: activo,
                            );

                        if (empleadoActualizado != null && mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Empleado actualizado exitosamente',
                              ),
                            ),
                          );
                          _loadData();
                        } else if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Error al actualizar empleado'),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEC6D13),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(empleado == null ? 'Crear' : 'Actualizar'),
                  ),
                ],
              ),
        );
      },
    );
  }
}
