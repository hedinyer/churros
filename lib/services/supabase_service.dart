import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database_service.dart';
import '../models/sucursal.dart';
import '../models/categoria.dart';
import '../models/producto.dart';
import '../models/apertura_dia.dart';
import '../models/user.dart' as app_user;
import '../models/venta.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://gxdhedevrvxidgtbzpdl.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_efn9NfHfDSvsJVs6i_i5sw_rI7HD2NA';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    // Inicializar la base de datos local
    await LocalDatabaseService.database;
  }

  static SupabaseClient get client => Supabase.instance.client;

  /// Verifica si hay conexión a internet intentando acceder a Supabase
  static Future<bool> _checkConnection() async {
    try {
      await client.from('users').select().limit(1).maybeSingle();
      return true;
    } catch (e) {
      print('Sin conexión a Supabase: $e');
      return false;
    }
  }

  /// Verifica las credenciales del usuario
  /// Primero intenta con Supabase, si falla usa la base de datos local
  /// Retorna el usuario si las credenciales son correctas, null si no
  static Future<Map<String, dynamic>?> verifyUserCredentials(
    String userIdentifier,
    String accessKey,
  ) async {
    // Intentar primero con Supabase si hay conexión
    final hasConnection = await _checkConnection();

    if (hasConnection) {
      try {
        // Buscar usuario por user_id (puede ser correo o nombre de usuario)
        final response =
            await client
                .from('users')
                .select()
                .eq('user_id', userIdentifier)
                .eq('access_key', accessKey)
                .maybeSingle();

        if (response != null) {
          // Guardar el usuario en la base de datos local para uso offline
          await LocalDatabaseService.upsertUser(
            id: response['id'],
            userId: response['user_id'] as String,
            accessKey: response['access_key'] as String?,
            sucursalId: response['sucursal'] as int?,
          );
          return response;
        }
      } catch (e) {
        print('Error verificando credenciales en Supabase: $e');
        // Si falla Supabase, intentar con la base de datos local
      }
    }

    // Si no hay conexión o Supabase falló, usar la base de datos local
    print('Usando base de datos local para autenticación');
    return await LocalDatabaseService.verifyUserCredentials(
      userIdentifier,
      accessKey,
    );
  }

  /// Sincroniza todos los usuarios desde Supabase a la base de datos local
  static Future<void> syncUsersToLocal() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión, no se puede sincronizar');
        return;
      }

      final response = await client.from('users').select();
      if (response.isNotEmpty) {
        await LocalDatabaseService.syncUsersFromSupabase(response);
        print('Usuarios sincronizados: ${response.length}');
      }
    } catch (e) {
      print('Error sincronizando usuarios desde Supabase: $e');
    }
  }

  /// Obtiene la sucursal principal (por ahora asumimos que hay una sola activa)
  static Future<Sucursal?> getSucursalPrincipal() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener sucursal');
        return null;
      }

      final response =
          await client
              .from('sucursales')
              .select()
              .eq('activa', true)
              .limit(1)
              .maybeSingle();

      if (response != null) {
        return Sucursal.fromJson(response);
      }
    } catch (e) {
      print('Error obteniendo sucursal: $e');
    }
    return null;
  }

  /// Obtiene todas las categorías activas
  static Future<List<Categoria>> getCategorias() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener categorías');
        return [];
      }

      final response = await client.from('categorias').select();

      return response.map((json) => Categoria.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo categorías: $e');
      return [];
    }
  }

  /// Obtiene todos los productos activos con sus categorías
  static Future<List<Producto>> getProductosActivos() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener productos');
        return [];
      }

      final categorias = await getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};

      final response = await client
          .from('productos')
          .select()
          .eq('activo', true);

      return response.map((json) {
        final categoria =
            json['categoria_id'] != null
                ? categoriasMap[json['categoria_id']]
                : null;
        return Producto.fromJson(json, categoria: categoria);
      }).toList();
    } catch (e) {
      print('Error obteniendo productos: $e');
      return [];
    }
  }

  /// Verifica si ya existe una apertura para la sucursal en la fecha actual
  static Future<AperturaDia?> getAperturaDiaActual(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para verificar apertura del día');
        return null;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response =
          await client
              .from('aperturas_dia')
              .select()
              .eq('sucursal_id', sucursalId)
              .eq('fecha_apertura', today)
              .maybeSingle();

      if (response != null) {
        final sucursal = await getSucursalById(sucursalId);
        if (sucursal != null) {
          return AperturaDia.fromJson(response, sucursal: sucursal);
        }
      }
    } catch (e) {
      print('Error verificando apertura del día: $e');
    }
    return null;
  }

  /// Crea una nueva apertura del día
  static Future<AperturaDia?> crearAperturaDia({
    required int sucursalId,
    required int usuarioAperturaId,
    required int totalArticulos,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para crear apertura del día');
        return null;
      }

      // Verificar si ya existe una apertura para hoy
      final aperturaExistente = await getAperturaDiaActual(sucursalId);
      if (aperturaExistente != null) {
        print('Ya existe una apertura para hoy: ${aperturaExistente.id}');
        return aperturaExistente;
      }

      final now = DateTime.now();
      final fechaApertura = now.toIso8601String().split('T')[0];
      final horaApertura =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final data = {
        'sucursal_id': sucursalId,
        'fecha_apertura': fechaApertura,
        'hora_apertura': horaApertura,
        'usuario_apertura': usuarioAperturaId,
        'estado': 'abierta',
        'total_articulos': totalArticulos,
      };

      print('Intentando crear apertura con datos: $data');

      final response =
          await client.from('aperturas_dia').insert(data).select().single();

      print('Apertura creada exitosamente: ${response['id']}');

      final sucursal = await getSucursalById(sucursalId);
      if (sucursal != null) {
        return AperturaDia.fromJson(response, sucursal: sucursal);
      } else {
        print(
          'Error: No se pudo obtener la sucursal después de crear la apertura',
        );
        return null;
      }
    } catch (e) {
      print('Error creando apertura del día: $e');
      print('Tipo de error: ${e.runtimeType}');
      if (e.toString().contains('duplicate') ||
          e.toString().contains('unique') ||
          e.toString().contains('violates unique constraint')) {
        print('Ya existe una apertura para esta sucursal y fecha');
        // Intentar obtener la apertura existente
        final aperturaExistente = await getAperturaDiaActual(sucursalId);
        if (aperturaExistente != null) {
          return aperturaExistente;
        }
      }
      rethrow; // Re-lanzar el error para que se maneje en el nivel superior
    }
  }

  /// Guarda el inventario inicial para una apertura
  static Future<bool> guardarInventarioInicial({
    required int aperturaId,
    required Map<int, int> inventario, // productoId -> cantidad
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para guardar inventario inicial');
        return false;
      }

      if (inventario.isEmpty) {
        print('No hay productos para guardar');
        return true; // No es un error si no hay productos
      }

      // Crear los datos del inventario
      final inventarioData =
          inventario.entries.map((entry) {
            return {
              'apertura_id': aperturaId,
              'producto_id': entry.key,
              'cantidad_inicial': entry.value,
            };
          }).toList();

      // Intentar usar upsert primero (más eficiente)
      try {
        // Intentar con el formato de onConflict como string
        await client
            .from('inventario_apertura')
            .upsert(inventarioData, onConflict: 'apertura_id,producto_id');
        print(
          'Inventario inicial guardado con upsert: ${inventarioData.length} productos para apertura $aperturaId',
        );
        return true;
      } catch (upsertError) {
        print(
          'Error con upsert, intentando inserción individual: $upsertError',
        );

        // Si falla upsert, intentar inserción individual
        int successCount = 0;
        int errorCount = 0;

        for (final entry in inventario.entries) {
          try {
            final data = {
              'apertura_id': aperturaId,
              'producto_id': entry.key,
              'cantidad_inicial': entry.value,
            };

            // Intentar insertar primero
            try {
              await client.from('inventario_apertura').insert(data);
              successCount++;
            } catch (insertError) {
              // Si falla por conflicto único, intentar actualizar
              final errorStr = insertError.toString().toLowerCase();
              if (errorStr.contains('duplicate') ||
                  errorStr.contains('unique') ||
                  errorStr.contains('violates unique constraint')) {
                await client
                    .from('inventario_apertura')
                    .update({'cantidad_inicial': entry.value})
                    .eq('apertura_id', aperturaId)
                    .eq('producto_id', entry.key);
                successCount++;
              } else {
                print('Error insertando producto ${entry.key}: $insertError');
                errorCount++;
              }
            }
          } catch (e) {
            print('Error procesando producto ${entry.key}: $e');
            errorCount++;
          }
        }

        print(
          'Inventario inicial guardado: $successCount exitosos, $errorCount errores para apertura $aperturaId',
        );

        // Considerar éxito si al menos algunos productos se guardaron
        return successCount > 0;
      }
    } catch (e) {
      print('Error guardando inventario inicial: $e');
      print(
        'Apertura ID: $aperturaId, Productos en inventario: ${inventario.length}',
      );
      return false;
    }
  }

  /// Actualiza el inventario actual para la sucursal
  /// Sobreescribe las cantidades existentes con las nuevas
  static Future<bool> actualizarInventarioActual({
    required int sucursalId,
    required Map<int, int> inventario, // productoId -> cantidad
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para actualizar inventario actual');
        return false;
      }

      if (inventario.isEmpty) {
        print('No hay inventario para actualizar');
        return true; // No es un error si no hay productos
      }

      final now = DateTime.now().toIso8601String();
      final inventarioData =
          inventario.entries.map((entry) {
            return {
              'sucursal_id': sucursalId,
              'producto_id': entry.key,
              'cantidad': entry.value,
              'ultima_actualizacion': now,
            };
          }).toList();

      // Intentar usar upsert primero (más eficiente)
      try {
        await client
            .from('inventario_actual')
            .upsert(inventarioData, onConflict: 'sucursal_id,producto_id');
        print(
          'Inventario actual actualizado con upsert: ${inventarioData.length} productos',
        );
        return true;
      } catch (upsertError) {
        print(
          'Error con upsert, intentando inserción individual: $upsertError',
        );

        // Si falla upsert, intentar inserción individual
        int successCount = 0;
        int errorCount = 0;

        for (final entry in inventario.entries) {
          try {
            final data = {
              'sucursal_id': sucursalId,
              'producto_id': entry.key,
              'cantidad': entry.value,
              'ultima_actualizacion': now,
            };

            // Intentar insertar primero
            try {
              await client.from('inventario_actual').insert(data);
              successCount++;
            } catch (insertError) {
              // Si falla por conflicto único, intentar actualizar
              final errorStr = insertError.toString().toLowerCase();
              if (errorStr.contains('duplicate') ||
                  errorStr.contains('unique') ||
                  errorStr.contains('violates unique constraint')) {
                await client
                    .from('inventario_actual')
                    .update({
                      'cantidad': entry.value,
                      'ultima_actualizacion': now,
                    })
                    .eq('sucursal_id', sucursalId)
                    .eq('producto_id', entry.key);
                successCount++;
              } else {
                print('Error insertando producto ${entry.key}: $insertError');
                errorCount++;
              }
            }
          } catch (e) {
            print('Error procesando producto ${entry.key}: $e');
            errorCount++;
          }
        }

        print(
          'Inventario actual actualizado: $successCount exitosos, $errorCount errores',
        );

        // Considerar éxito si al menos algunos productos se guardaron
        return successCount > 0;
      }
    } catch (e) {
      print('Error actualizando inventario actual: $e');
      return false;
    }
  }

  /// Obtiene el usuario actual por user_id
  static Future<app_user.AppUser?> getCurrentUser(String userId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener usuario actual');
        return null;
      }

      final response =
          await client
              .from('users')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      if (response != null) {
        return app_user.AppUser.fromJson(response);
      }
    } catch (e) {
      print('Error obteniendo usuario actual: $e');
    }
    return null;
  }

  /// Obtiene una sucursal por ID
  static Future<Sucursal?> getSucursalById(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener sucursal');
        return null;
      }

      final response =
          await client
              .from('sucursales')
              .select()
              .eq('id', sucursalId)
              .maybeSingle();

      if (response != null) {
        return Sucursal.fromJson(response);
      }
    } catch (e) {
      print('Error obteniendo sucursal: $e');
    }
    return null;
  }

  /// Obtiene el inventario actual de una sucursal
  static Future<Map<int, int>> getInventarioActual(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener inventario actual');
        return {};
      }

      final response = await client
          .from('inventario_actual')
          .select('producto_id, cantidad')
          .eq('sucursal_id', sucursalId);

      // Convertir la respuesta a un Map<productoId, cantidad>
      final inventario = <int, int>{};
      for (final item in response) {
        inventario[item['producto_id'] as int] = item['cantidad'] as int;
      }

      return inventario;
    } catch (e) {
      print('Error obteniendo inventario actual: $e');
      return {};
    }
  }

  /// Obtiene el inventario actual de una sucursal con información de productos
  static Future<Map<Producto, int>> getInventarioActualConProductos(
    int sucursalId,
  ) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener inventario actual');
        return {};
      }

      // Obtener productos para mapear IDs
      final productos = await getProductosActivos();
      final productosMap = {
        for (var producto in productos) producto.id: producto,
      };

      final response = await client
          .from('inventario_actual')
          .select('producto_id, cantidad')
          .eq('sucursal_id', sucursalId);

      // Convertir la respuesta a un Map<Producto, cantidad>
      final inventario = <Producto, int>{};
      for (final item in response) {
        final productoId = item['producto_id'] as int;
        final producto = productosMap[productoId];
        if (producto != null) {
          inventario[producto] = item['cantidad'] as int;
        }
      }

      return inventario;
    } catch (e) {
      print('Error obteniendo inventario actual con productos: $e');
      return {};
    }
  }

  /// Genera un número de ticket único
  static String _generateTicketNumber(int sucursalId) {
    final now = DateTime.now();
    final fecha =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'TKT-$sucursalId-$fecha-$hora';
  }

  /// Guarda una venta completa con sus detalles
  static Future<Venta?> guardarVenta({
    required int sucursalId,
    required int usuarioId,
    required Map<int, int> productos, // productoId -> cantidad
    required Map<int, Producto> productosMap, // productoId -> Producto
    String metodoPago = 'efectivo',
    double descuento = 0.0,
    double impuesto = 0.0,
    String? observaciones,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      final now = DateTime.now();

      // Calcular subtotal y total
      double subtotal = 0.0;
      final detallesData = <Map<String, dynamic>>[];

      for (final entry in productos.entries) {
        final producto = productosMap[entry.key];
        if (producto == null) continue;

        final cantidad = entry.value;
        final precioUnitario = producto.precio;
        final precioTotal = precioUnitario * cantidad;
        subtotal += precioTotal;

        detallesData.add({
          'producto_id': producto.id,
          'cantidad': cantidad,
          'precio_unitario': precioUnitario,
          'precio_total': precioTotal,
          'descuento': 0.0,
        });
      }

      final total = subtotal - descuento + impuesto;

      // Crear la venta
      final ventaData = {
        'sucursal_id': sucursalId,
        'usuario_id': usuarioId,
        'fecha_venta': now.toIso8601String().split('T')[0],
        'hora_venta':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'total': total,
        'subtotal': subtotal,
        'descuento': descuento,
        'impuesto': impuesto,
        'metodo_pago': metodoPago,
        'estado': 'completada',
        'numero_ticket': _generateTicketNumber(sucursalId),
        'observaciones': observaciones,
        'sincronizado': hasConnection,
      };

      // Insertar la venta
      final ventaResponse =
          await client.from('ventas').insert(ventaData).select().single();

      final ventaId = ventaResponse['id'] as int;

      // Insertar los detalles de la venta
      final detallesConVentaId =
          detallesData.map((detalle) {
            return {...detalle, 'venta_id': ventaId};
          }).toList();

      await client.from('venta_detalles').insert(detallesConVentaId);

      // Actualizar inventario (restar productos vendidos)
      final inventarioActual = await getInventarioActual(sucursalId);
      final nuevoInventario = <int, int>{};

      for (final entry in productos.entries) {
        final cantidadActual = inventarioActual[entry.key] ?? 0;
        final cantidadVendida = entry.value;
        final nuevaCantidad = cantidadActual - cantidadVendida;

        if (nuevaCantidad < 0) {
          print('Advertencia: Stock insuficiente para producto ${entry.key}');
          nuevoInventario[entry.key] = 0;
        } else {
          nuevoInventario[entry.key] = nuevaCantidad;
        }
      }

      // Actualizar inventario actual
      if (nuevoInventario.isNotEmpty) {
        final nowStr = DateTime.now().toIso8601String();
        final inventarioData =
            nuevoInventario.entries.map((entry) {
              return {
                'sucursal_id': sucursalId,
                'producto_id': entry.key,
                'cantidad': entry.value,
                'ultima_actualizacion': nowStr,
              };
            }).toList();

        try {
          await client
              .from('inventario_actual')
              .upsert(inventarioData, onConflict: 'sucursal_id,producto_id');
        } catch (e) {
          print('Error actualizando inventario después de venta: $e');
        }
      }

      // Obtener sucursal para el objeto Venta
      final sucursal = await getSucursalById(sucursalId);

      return Venta.fromJson(ventaResponse, sucursal: sucursal);
    } catch (e) {
      print('Error guardando venta: $e');
      return null;
    }
  }

  /// Obtiene las ventas del día actual para una sucursal
  static Future<List<Venta>> getVentasHoy(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener ventas de hoy');
        return [];
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await client
          .from('ventas')
          .select()
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', today)
          .eq('estado', 'completada')
          .order('hora_venta', ascending: false);

      final sucursal = await getSucursalById(sucursalId);
      return response
          .map((json) => Venta.fromJson(json, sucursal: sucursal))
          .toList();
    } catch (e) {
      print('Error obteniendo ventas de hoy: $e');
      return [];
    }
  }

  /// Obtiene el resumen de ventas del día actual
  static Future<Map<String, dynamic>> getResumenVentasHoy(
    int sucursalId,
  ) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener resumen de ventas');
        return {'total': 0.0, 'tickets': 0, 'porcentaje_vs_ayer': 0.0};
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final yesterday =
          DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')[0];

      // Obtener ventas de hoy
      final ventasHoy = await client
          .from('ventas')
          .select('total')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', today)
          .eq('estado', 'completada');

      // Obtener ventas de ayer
      final ventasAyer = await client
          .from('ventas')
          .select('total')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', yesterday)
          .eq('estado', 'completada');

      // Calcular totales
      final totalHoy = ventasHoy.fold<double>(
        0.0,
        (sum, venta) => sum + ((venta['total'] as num).toDouble()),
      );

      final totalAyer = ventasAyer.fold<double>(
        0.0,
        (sum, venta) => sum + ((venta['total'] as num).toDouble()),
      );

      // Calcular porcentaje de cambio
      double porcentajeCambio = 0.0;
      if (totalAyer > 0) {
        porcentajeCambio = ((totalHoy - totalAyer) / totalAyer) * 100;
      } else if (totalHoy > 0) {
        porcentajeCambio = 100.0; // Si ayer fue 0 y hoy hay ventas, es +100%
      }

      return {
        'total': totalHoy,
        'tickets': ventasHoy.length,
        'porcentaje_vs_ayer': porcentajeCambio,
      };
    } catch (e) {
      print('Error obteniendo resumen de ventas: $e');
      return {'total': 0.0, 'tickets': 0, 'porcentaje_vs_ayer': 0.0};
    }
  }

  /// Obtiene el inventario inicial de la apertura del día actual
  static Future<Map<int, int>> getInventarioInicialHoy(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener inventario inicial');
        return {};
      }

      final apertura = await getAperturaDiaActual(sucursalId);
      if (apertura == null) {
        return {};
      }

      final response = await client
          .from('inventario_apertura')
          .select('producto_id, cantidad_inicial')
          .eq('apertura_id', apertura.id);

      final inventario = <int, int>{};
      for (final item in response) {
        inventario[item['producto_id'] as int] =
            item['cantidad_inicial'] as int;
      }

      return inventario;
    } catch (e) {
      print('Error obteniendo inventario inicial: $e');
      return {};
    }
  }

  /// Obtiene las ventas del día agrupadas por producto
  static Future<Map<int, int>> getVentasHoyPorProducto(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener ventas por producto');
        return {};
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Obtener detalles de venta directamente usando join
      final detalles = await client
          .from('venta_detalles')
          .select(
            'producto_id, cantidad, ventas!inner(sucursal_id, fecha_venta, estado)',
          )
          .eq('ventas.sucursal_id', sucursalId)
          .eq('ventas.fecha_venta', today)
          .eq('ventas.estado', 'completada');

      final ventasPorProducto = <int, int>{};
      for (final detalle in detalles) {
        final productoId = detalle['producto_id'] as int;
        final cantidad = detalle['cantidad'] as int;
        ventasPorProducto[productoId] =
            (ventasPorProducto[productoId] ?? 0) + cantidad;
      }

      return ventasPorProducto;
    } catch (e) {
      print('Error obteniendo ventas por producto: $e');
      // Fallback: obtener ventas y luego detalles
      try {
        final today = DateTime.now().toIso8601String().split('T')[0];
        final ventas = await client
            .from('ventas')
            .select('id')
            .eq('sucursal_id', sucursalId)
            .eq('fecha_venta', today)
            .eq('estado', 'completada');

        if (ventas.isEmpty) {
          return {};
        }

        final ventasPorProducto = <int, int>{};
        for (final venta in ventas) {
          final ventaId = venta['id'] as int;
          final detalles = await client
              .from('venta_detalles')
              .select('producto_id, cantidad')
              .eq('venta_id', ventaId);

          for (final detalle in detalles) {
            final productoId = detalle['producto_id'] as int;
            final cantidad = detalle['cantidad'] as int;
            ventasPorProducto[productoId] =
                (ventasPorProducto[productoId] ?? 0) + cantidad;
          }
        }

        return ventasPorProducto;
      } catch (fallbackError) {
        print(
          'Error en fallback obteniendo ventas por producto: $fallbackError',
        );
        return {};
      }
    }
  }

  /// Guarda una recarga de inventario completa con sus detalles
  /// También actualiza el inventario actual de la sucursal
  static Future<bool> guardarRecargaInventario({
    required int sucursalId,
    required int usuarioId,
    required Map<int, int>
    productosRecarga, // productoId -> cantidad a recargar
    String? observaciones,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para guardar recarga de inventario');
        return false;
      }

      if (productosRecarga.isEmpty) {
        print('No hay productos para recargar');
        return false;
      }

      final now = DateTime.now();
      final fechaRecarga = now.toIso8601String().split('T')[0];
      final horaRecarga =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // Obtener inventario actual para calcular cantidades anteriores y finales
      final inventarioActual = await getInventarioActual(sucursalId);

      // Crear los datos de la recarga principal
      final recargaData = {
        'sucursal_id': sucursalId,
        'usuario_id': usuarioId,
        'fecha_recarga': fechaRecarga,
        'hora_recarga': horaRecarga,
        'total_productos': productosRecarga.length,
        'estado': 'completada',
        'observaciones': observaciones,
        'sincronizado': hasConnection,
      };

      // Insertar la recarga principal
      final recargaResponse =
          await client
              .from('recargas_inventario')
              .insert(recargaData)
              .select()
              .single();

      final recargaId = recargaResponse['id'] as int;

      // Crear los detalles de la recarga
      final detallesData = <Map<String, dynamic>>[];
      final nuevoInventario = <int, int>{};

      for (final entry in productosRecarga.entries) {
        final productoId = entry.key;
        final cantidadRecargada = entry.value;
        final cantidadAnterior = inventarioActual[productoId] ?? 0;
        final cantidadFinal = cantidadAnterior + cantidadRecargada;

        detallesData.add({
          'recarga_id': recargaId,
          'producto_id': productoId,
          'cantidad_anterior': cantidadAnterior,
          'cantidad_recargada': cantidadRecargada,
          'cantidad_final': cantidadFinal,
          'precio_unitario': null, // Se puede agregar después si se necesita
          'costo_total': null, // Se puede agregar después si se necesita
        });

        // Preparar actualización del inventario actual
        nuevoInventario[productoId] = cantidadFinal;
      }

      // Insertar los detalles de la recarga
      await client.from('recarga_detalles').insert(detallesData);

      // Actualizar el inventario actual de la sucursal
      if (nuevoInventario.isNotEmpty) {
        final nowStr = DateTime.now().toIso8601String();
        final inventarioData =
            nuevoInventario.entries.map((entry) {
              return {
                'sucursal_id': sucursalId,
                'producto_id': entry.key,
                'cantidad': entry.value,
                'ultima_actualizacion': nowStr,
              };
            }).toList();

        try {
          await client
              .from('inventario_actual')
              .upsert(inventarioData, onConflict: 'sucursal_id,producto_id');
          print(
            'Recarga guardada exitosamente: ID $recargaId, ${productosRecarga.length} productos',
          );
        } catch (e) {
          print('Error actualizando inventario después de recarga: $e');
          // Aún así consideramos éxito porque la recarga se guardó
        }
      }

      return true;
    } catch (e) {
      print('Error guardando recarga de inventario: $e');
      return false;
    }
  }

  /// Obtiene el cierre del día actual para una sucursal
  static Future<Map<String, dynamic>?> getCierreDiaActual(
    int sucursalId,
  ) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para verificar cierre del día');
        return null;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response =
          await client
              .from('cierres_dia')
              .select()
              .eq('sucursal_id', sucursalId)
              .eq('fecha_cierre', today)
              .maybeSingle();

      return response;
    } catch (e) {
      print('Error verificando cierre del día: $e');
      return null;
    }
  }

  /// Guarda un cierre del día completo con su inventario
  /// También actualiza el inventario_actual con las existencias finales
  static Future<bool> guardarCierreDia({
    required int sucursalId,
    required int aperturaId,
    required int usuarioCierreId,
    required Map<int, int> existenciaFinal, // productoId -> cantidad final
    required Map<int, int> sobrantes, // productoId -> sobrantes
    required Map<int, int> vencido, // productoId -> vencido/mal estado
    required double totalVentas,
    String? observaciones,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para guardar cierre del día');
        return false;
      }

      // Verificar si ya existe un cierre para hoy
      final cierreExistente = await getCierreDiaActual(sucursalId);
      if (cierreExistente != null) {
        print('Ya existe un cierre para hoy: ${cierreExistente['id']}');
        // Opcional: actualizar el cierre existente o retornar error
        return false;
      }

      final now = DateTime.now();
      final fechaCierre = now.toIso8601String().split('T')[0];
      final horaCierre =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // Calcular total de desperdicio
      final totalDesperdicio = vencido.values.fold(
        0,
        (sum, cantidad) => sum + cantidad,
      );

      // Crear el registro de cierre
      final cierreData = {
        'sucursal_id': sucursalId,
        'apertura_id': aperturaId,
        'usuario_cierre': usuarioCierreId,
        'fecha_cierre': fechaCierre,
        'hora_cierre': horaCierre,
        'total_productos': existenciaFinal.length,
        'total_desperdicio': totalDesperdicio,
        'total_ventas': totalVentas,
        'estado': 'completado',
        'observaciones': observaciones,
      };

      // Insertar el cierre
      final cierreResponse =
          await client.from('cierres_dia').insert(cierreData).select().single();

      final cierreId = cierreResponse['id'] as int;

      // Crear los detalles del inventario de cierre
      final inventarioCierreData = <Map<String, dynamic>>[];
      for (final entry in existenciaFinal.entries) {
        final productoId = entry.key;
        inventarioCierreData.add({
          'cierre_id': cierreId,
          'producto_id': productoId,
          'cantidad_final': entry.value,
          'cantidad_sobrantes': sobrantes[productoId] ?? 0,
          'cantidad_vencido': vencido[productoId] ?? 0,
        });
      }

      // Insertar el inventario de cierre
      if (inventarioCierreData.isNotEmpty) {
        await client.from('inventario_cierre').insert(inventarioCierreData);
      }

      // Actualizar el inventario_actual con las existencias finales
      final nowStr = DateTime.now().toIso8601String();
      final inventarioActualData =
          existenciaFinal.entries.map((entry) {
            return {
              'sucursal_id': sucursalId,
              'producto_id': entry.key,
              'cantidad': entry.value,
              'ultima_actualizacion': nowStr,
            };
          }).toList();

      if (inventarioActualData.isNotEmpty) {
        try {
          await client
              .from('inventario_actual')
              .upsert(
                inventarioActualData,
                onConflict: 'sucursal_id,producto_id',
              );
          print(
            'Cierre guardado exitosamente: ID $cierreId, ${existenciaFinal.length} productos',
          );
        } catch (e) {
          print('Error actualizando inventario actual después de cierre: $e');
          // Aún así consideramos éxito porque el cierre se guardó
        }
      }

      return true;
    } catch (e) {
      print('Error guardando cierre del día: $e');
      return false;
    }
  }
}
