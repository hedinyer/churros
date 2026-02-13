import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'local_database_service.dart';
import 'sync_queue_service.dart';
import '../models/sucursal.dart';
import '../models/categoria.dart';
import '../models/producto.dart';
import '../models/apertura_dia.dart';
import '../models/user.dart' as app_user;
import '../models/venta.dart';
import '../models/pedido_fabrica.dart';
import '../models/pedido_cliente.dart';
import '../models/empleado.dart';
import '../models/produccion_empleado.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://gxdhedevrvxidgtbzpdl.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_efn9NfHfDSvsJVs6i_i5sw_rI7HD2NA';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    // Inicializar la base de datos local
    await LocalDatabaseService.database;
    // Inicializar timezone data
    tz.initializeTimeZones();
  }

  /// Obtiene la fecha y hora actual en la zona horaria de Colombia (America/Bogota)
  static DateTime getColombiaDateTime() {
    try {
      final bogota = tz.getLocation('America/Bogota');
      return tz.TZDateTime.now(bogota);
    } catch (e) {
      print('Error obteniendo hora de Colombia, usando hora local: $e');
      // Si falla, usar hora local como fallback
      return DateTime.now();
    }
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

  /// Verifica si hay conexión a internet (método público)
  static Future<bool> checkConnection() async {
    return await _checkConnection();
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
            type: response['type'] as int?,
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
        print('No hay conexión, no se puede sincronizar usuarios');
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

  /// Sincroniza todas las sucursales desde Supabase a la base de datos local
  static Future<void> syncSucursalesToLocal() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('⚠️ No hay conexión, no se puede sincronizar sucursales');
        return;
      }

      print('🔄 Sincronizando sucursales desde Supabase...');
      final response = await client.from('sucursales').select();
      print('📊 Sucursales encontradas en Supabase: ${response.length}');
      
      if (response.isNotEmpty) {
        // Log de todas las sucursales encontradas
        for (final sucursal in response) {
          print('  - ID: ${sucursal['id']}, Nombre: ${sucursal['nombre']}, Activa: ${sucursal['activa']}');
        }
        
        await LocalDatabaseService.syncSucursalesFromSupabase(response);
        print('✅ Sucursales sincronizadas exitosamente: ${response.length}');
      } else {
        print('⚠️ No se encontraron sucursales en Supabase');
      }
    } catch (e, stackTrace) {
      print('❌ Error sincronizando sucursales desde Supabase: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Obtiene la sucursal principal (por ahora asumimos que hay una sola activa)
  /// Primero intenta con Supabase, si falla usa la base de datos local
  static Future<Sucursal?> getSucursalPrincipal() async {
    try {
      final hasConnection = await _checkConnection();
      
      if (hasConnection) {
        print('🔍 Buscando sucursal principal activa en Supabase...');
        try {
          final response =
              await client
                  .from('sucursales')
                  .select()
                  .eq('activa', true)
                  .limit(1)
                  .maybeSingle();

          if (response != null) {
            print('✅ Sucursal principal encontrada en Supabase: ${response['nombre']}');
            // Guardar en base de datos local para uso offline
            await LocalDatabaseService.upsertSucursal(response);
            return Sucursal.fromJson(response);
          } else {
            print('⚠️ No se encontró ninguna sucursal activa en Supabase');
          }
        } catch (e) {
          print('⚠️ Error obteniendo sucursal principal de Supabase: $e');
          // Continuar para intentar con base de datos local
        }
      } else {
        print('⚠️ No hay conexión, buscando sucursal principal en base de datos local...');
      }

      // Intentar con base de datos local
      print('🔍 Buscando sucursal principal en base de datos local...');
      final localSucursal = await LocalDatabaseService.getSucursalPrincipal();
      if (localSucursal != null) {
        print('✅ Sucursal principal encontrada en base de datos local: ${localSucursal['nombre']}');
        return Sucursal.fromJson(localSucursal);
      } else {
        print('⚠️ No se encontró sucursal principal en base de datos local');
      }
    } catch (e, stackTrace) {
      print('❌ Error obteniendo sucursal principal: $e');
      print('Stack trace: $stackTrace');
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

  /// Obtiene el inventario de apertura para una apertura específica
  /// Retorna un mapa de productoId -> cantidad_inicial
  static Future<Map<int, int>> getInventarioAperturaPorApertura(
    int aperturaId,
  ) async {
    final Map<int, int> inventario = {};

    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener inventario de apertura');
        return inventario;
      }

      final response = await client
          .from('inventario_apertura')
          .select('producto_id, cantidad_inicial')
          .eq('apertura_id', aperturaId);

      for (final row in response) {
        final productoId = row['producto_id'] as int?;
        final cantidad = row['cantidad_inicial'] as int? ?? 0;
        if (productoId != null) {
          inventario[productoId] = cantidad;
        }
      }

      print(
        'Inventario de apertura cargado: ${inventario.length} productos para apertura $aperturaId',
      );
    } catch (e) {
      print('Error obteniendo inventario de apertura: $e');
    }

    return inventario;
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
  /// Primero intenta con Supabase, si falla usa la base de datos local
  static Future<Sucursal?> getSucursalById(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      
      if (hasConnection) {
        print('🔍 Buscando sucursal con ID: $sucursalId en Supabase...');
        try {
          final response =
              await client
                  .from('sucursales')
                  .select()
                  .eq('id', sucursalId)
                  .maybeSingle();

          if (response != null) {
            print('✅ Sucursal encontrada en Supabase: ${response['nombre']} (activa: ${response['activa']})');
            // Guardar en base de datos local para uso offline
            await LocalDatabaseService.upsertSucursal(response);
            return Sucursal.fromJson(response);
          } else {
            print('⚠️ No se encontró sucursal con ID: $sucursalId en Supabase');
          }
        } catch (e) {
          print('⚠️ Error obteniendo sucursal de Supabase: $e');
          // Continuar para intentar con base de datos local
        }
      } else {
        print('⚠️ No hay conexión, buscando sucursal en base de datos local...');
      }

      // Intentar con base de datos local
      print('🔍 Buscando sucursal con ID: $sucursalId en base de datos local...');
      final localSucursal = await LocalDatabaseService.getSucursalById(sucursalId);
      if (localSucursal != null) {
        print('✅ Sucursal encontrada en base de datos local: ${localSucursal['nombre']}');
        return Sucursal.fromJson(localSucursal);
      } else {
        print('⚠️ No se encontró sucursal con ID: $sucursalId en base de datos local');
      }
    } catch (e, stackTrace) {
      print('❌ Error obteniendo sucursal con ID $sucursalId: $e');
      print('Stack trace: $stackTrace');
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

  /// Guarda una venta a fiado (deudor) en lugar de una venta normal
  static Future<Map<String, dynamic>?> guardarDeudor({
    required int sucursalId,
    required int usuarioId,
    required String nombreDeudor,
    required Map<int, int> productos, // productoId -> cantidad
    required Map<int, Producto> productosMap, // productoId -> Producto
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

      // Crear el deudor
      final deudorData = {
        'sucursal_id': sucursalId,
        'usuario_id': usuarioId,
        'nombre_deudor': nombreDeudor,
        'fecha_venta': now.toIso8601String().split('T')[0],
        'hora_venta':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'total': total,
        'subtotal': subtotal,
        'descuento': descuento,
        'impuesto': impuesto,
        'estado': 'pendiente',
        'numero_ticket': _generateTicketNumber(sucursalId),
        'observaciones': observaciones,
        'sincronizado': hasConnection,
      };

      // Insertar el deudor
      final deudorResponse =
          await client.from('deudores').insert(deudorData).select().single();

      final deudorId = deudorResponse['id'] as int;

      // Insertar los detalles del deudor
      final detallesConDeudorId =
          detallesData.map((detalle) {
            return {...detalle, 'deudor_id': deudorId};
          }).toList();

      await client.from('deudor_detalles').insert(detallesConDeudorId);

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
          print('Error actualizando inventario después de deudor: $e');
        }
      }

      print('Deudor guardado exitosamente: ID $deudorId, Nombre: $nombreDeudor');

      return {
        'id': deudorId,
        'nombre_deudor': nombreDeudor,
        'total': total,
        'numero_ticket': deudorData['numero_ticket'],
      };
    } catch (e) {
      print('Error guardando deudor: $e');
      return null;
    }
  }

  /// Obtiene el total de deudores (fiado) del día actual para una sucursal
  static Future<double> getTotalFiadoHoy(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener total de fiado');
        return 0.0;
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await client
          .from('deudores')
          .select('total')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', today)
          .eq('estado', 'pendiente'); // Solo contar los pendientes

      final totalFiado = response.fold<double>(
        0.0,
        (sum, deudor) => sum + ((deudor['total'] as num).toDouble()),
      );

      return totalFiado;
    } catch (e) {
      print('Error obteniendo total de fiado: $e');
      return 0.0;
    }
  }

  /// Obtiene todos los deudores pendientes de una sucursal con sus detalles
  static Future<List<Map<String, dynamic>>> getDeudoresPendientes(
    int sucursalId,
  ) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener deudores pendientes');
        return [];
      }

      // Obtener deudores pendientes
      final deudoresResponse = await client
          .from('deudores')
          .select()
          .eq('sucursal_id', sucursalId)
          .eq('estado', 'pendiente')
          .order('fecha_venta', ascending: false)
          .order('hora_venta', ascending: false);

      final deudores = <Map<String, dynamic>>[];

      for (final deudor in deudoresResponse) {
        final deudorId = deudor['id'] as int;

        // Obtener detalles del deudor
        final detallesResponse = await client
            .from('deudor_detalles')
            .select('*, productos(*)')
            .eq('deudor_id', deudorId);

        deudores.add({
          ...deudor,
          'detalles': detallesResponse,
        });
      }

      return deudores;
    } catch (e) {
      print('Error obteniendo deudores pendientes: $e');
      return [];
    }
  }

  /// Marca un deudor como pagado y transfiere la información a la tabla de ventas
  static Future<bool> marcarDeudorComoPagado({
    required int deudorId,
    required int sucursalId,
    required int usuarioId,
    String metodoPago = 'efectivo',
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para marcar deudor como pagado');
        return false;
      }

      // Obtener el deudor con sus detalles
      final deudorResponse = await client
          .from('deudores')
          .select()
          .eq('id', deudorId)
          .eq('estado', 'pendiente')
          .maybeSingle();

      if (deudorResponse == null) {
        print('Deudor no encontrado o ya no está pendiente');
        return false;
      }

      final detallesResponse = await client
          .from('deudor_detalles')
          .select('*, productos(*)')
          .eq('deudor_id', deudorId);

      final fechaVenta = deudorResponse['fecha_venta'] as String;
      final horaVenta = deudorResponse['hora_venta'] as String;
      final total = (deudorResponse['total'] as num).toDouble();
      final subtotal = (deudorResponse['subtotal'] as num).toDouble();
      final descuento = (deudorResponse['descuento'] as num).toDouble();
      final impuesto = (deudorResponse['impuesto'] as num).toDouble();
      final observaciones = deudorResponse['observaciones'] as String?;
      final numeroTicket = deudorResponse['numero_ticket'] as String?;

      // Crear la venta en la tabla ventas
      final ventaData = {
        'sucursal_id': sucursalId,
        'usuario_id': usuarioId,
        'fecha_venta': fechaVenta,
        'hora_venta': horaVenta,
        'total': total,
        'subtotal': subtotal,
        'descuento': descuento,
        'impuesto': impuesto,
        'metodo_pago': metodoPago,
        'estado': 'completada',
        'numero_ticket': numeroTicket ?? _generateTicketNumber(sucursalId),
        'observaciones': observaciones != null
            ? 'Pago de fiado - ${observaciones}'
            : 'Pago de fiado',
        'sincronizado': hasConnection,
      };

      final ventaResponse =
          await client.from('ventas').insert(ventaData).select().single();
      final ventaId = ventaResponse['id'] as int;

      // Crear los detalles de venta desde los detalles del deudor
      final ventaDetallesData = detallesResponse.map((detalle) {
        return {
          'venta_id': ventaId,
          'producto_id': detalle['producto_id'],
          'cantidad': detalle['cantidad'],
          'precio_unitario': detalle['precio_unitario'],
          'precio_total': detalle['precio_total'],
          'descuento': detalle['descuento'],
        };
      }).toList();

      await client.from('venta_detalles').insert(ventaDetallesData);

      // Actualizar el estado del deudor a 'pagado'
      await client
          .from('deudores')
          .update({'estado': 'pagado'})
          .eq('id', deudorId);

      print('Deudor marcado como pagado y transferido a ventas: ID $deudorId -> Venta ID $ventaId');

      return true;
    } catch (e) {
      print('Error marcando deudor como pagado: $e');
      return false;
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
        return {
          'total': 0.0,
          'total_efectivo': 0.0,
          'total_transferencia': 0.0,
          'tickets': 0,
          'porcentaje_vs_ayer': 0.0,
        };
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final yesterday =
          DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')[0];

      // Obtener ventas de hoy con método de pago
      final ventasHoy = await client
          .from('ventas')
          .select('total, metodo_pago')
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

      // Calcular totales separados por método de pago
      double totalEfectivo = 0.0;
      double totalTransferencia = 0.0;
      double totalHoy = 0.0;

      for (final venta in ventasHoy) {
        final total = (venta['total'] as num).toDouble();
        final metodoPago = (venta['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
        totalHoy += total;

        if (metodoPago == 'transferencia' || metodoPago == 'transfer' || metodoPago == 'nequi' || metodoPago == 'daviplata') {
          totalTransferencia += total;
        } else {
          // Por defecto, todo lo que no sea transferencia es efectivo
          totalEfectivo += total;
        }
      }

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
        'total_efectivo': totalEfectivo,
        'total_transferencia': totalTransferencia,
        'tickets': ventasHoy.length,
        'porcentaje_vs_ayer': porcentajeCambio,
      };
    } catch (e) {
      print('Error obteniendo resumen de ventas: $e');
      return {
        'total': 0.0,
        'total_efectivo': 0.0,
        'total_transferencia': 0.0,
        'tickets': 0,
        'porcentaje_vs_ayer': 0.0,
      };
    }
  }

  /// Obtiene el resumen de ventas para una fecha específica
  static Future<Map<String, dynamic>> getResumenVentasPorFecha(
    int sucursalId,
    String fecha, // formato YYYY-MM-DD
  ) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener resumen de ventas');
        return {
          'total': 0.0,
          'total_efectivo': 0.0,
          'total_transferencia': 0.0,
          'tickets': 0,
        };
      }

      // Obtener ventas de la fecha con método de pago
      final ventas = await client
          .from('ventas')
          .select('total, metodo_pago')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', fecha)
          .eq('estado', 'completada');

      // Calcular totales separados por método de pago
      double totalEfectivo = 0.0;
      double totalTransferencia = 0.0;
      double total = 0.0;

      for (final venta in ventas) {
        final totalVenta = (venta['total'] as num).toDouble();
        final metodoPago = (venta['metodo_pago'] as String? ?? 'efectivo').toLowerCase();
        total += totalVenta;

        if (metodoPago == 'transferencia' || metodoPago == 'transfer' || metodoPago == 'nequi' || metodoPago == 'daviplata') {
          totalTransferencia += totalVenta;
        } else {
          totalEfectivo += totalVenta;
        }
      }

      return {
        'total': total,
        'total_efectivo': totalEfectivo,
        'total_transferencia': totalTransferencia,
        'tickets': ventas.length,
      };
    } catch (e) {
      print('Error obteniendo resumen de ventas por fecha: $e');
      return {
        'total': 0.0,
        'total_efectivo': 0.0,
        'total_transferencia': 0.0,
        'tickets': 0,
      };
    }
  }

  /// Obtiene las ventas completas para una fecha específica
  static Future<List<Map<String, dynamic>>> getVentasPorFecha(
    int sucursalId,
    String fecha, // formato YYYY-MM-DD
  ) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener ventas');
        return [];
      }

      final response = await client
          .from('ventas')
          .select('*')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', fecha)
          .eq('estado', 'completada')
          .order('hora_venta', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo ventas por fecha: $e');
      return [];
    }
  }

  /// Obtiene los detalles de una venta específica
  static Future<List<Map<String, dynamic>>> getDetallesVenta(int ventaId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener detalles de venta');
        return [];
      }

      final response = await client
          .from('venta_detalles')
          .select('*, productos(*)')
          .eq('venta_id', ventaId)
          .order('id', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo detalles de venta: $e');
      return [];
    }
  }

  /// Obtiene gastos de punto de venta para una fecha específica
  static Future<List<Map<String, dynamic>>> getGastosPuntoVentaPorFecha({
    required int sucursalId,
    required String fecha, // formato YYYY-MM-DD
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener gastos de punto de venta');
        return [];
      }

      final response = await client
          .from('gastos_puntoventa')
          .select()
          .eq('sucursal_id', sucursalId)
          .eq('fecha', fecha)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo gastos por fecha: $e');
      return [];
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

  /// Guarda una recarga de inventario y descuenta productos CRUDOS en una sola operación atómica (servidor).
  ///
  /// Esto evita inconsistencias del tipo: "subió FRITO pero NO bajó CRUDO" por mala conexión o concurrencia.
  ///
  /// Requiere tener instalada la función SQL en Supabase:
  /// `public.guardar_recarga_inventario_y_descontar_crudos(...)`
  ///
  /// Retorna:
  /// - exito: bool
  /// - mensaje: String
  /// - recargaId: int? (si exito)
  static Future<Map<String, dynamic>>
  guardarRecargaInventarioConDescuentoCrudos({
    required int sucursalId,
    required int usuarioId,
    required Map<int, int> productosRecarga, // productoId -> cantidad a recargar
    required Map<int, int>
    crudosADescontar, // productoId (crudo) -> cantidad a descontar
    String? observaciones,
  }) async {
    try {
      if (productosRecarga.isEmpty) {
        return {'exito': false, 'mensaje': 'No hay productos para recargar'};
      }

      // Convertir mapas a arrays JSON para el RPC
      final productosRecargaJson =
          productosRecarga.entries.map((e) {
            return {'producto_id': e.key, 'cantidad': e.value};
          }).toList();

      final crudosDescontarJson = crudosADescontar.entries.map((e) {
        return {'producto_id': e.key, 'cantidad': e.value};
      }).toList();

      final rpcParams = {
          'p_sucursal_id': sucursalId,
          'p_usuario_id': usuarioId,
          'p_observaciones': observaciones,
          'p_productos_recarga': productosRecargaJson,
          'p_crudos_a_descontar': crudosDescontarJson,
      };

      // Usar executeOrQueue para asegurar que se guarde incluso con conexión lenta
      final result = await SyncQueueService.executeOrQueue(
        operationType: 'rpc',
        tableName: 'guardar_recarga_inventario_y_descontar_crudos',
        data: rpcParams,
        directOperation: () async {
          return await client.rpc(
            'guardar_recarga_inventario_y_descontar_crudos',
            params: rpcParams,
      );
        },
      );

      if (!result['success']) {
        return {
          'exito': false,
          'mensaje': result['error'] ?? 'Error desconocido',
        };
      }

      if (result['queued'] == true) {
        return {
          'exito': true,
          'mensaje': 'Recarga agregada a cola de sincronización. Se guardará cuando haya conexión.',
          'queued': true,
          'queueId': result['queueId'],
        };
      }

      final response = result['result'];
      final recargaId = (response as num?)?.toInt();
      if (recargaId == null) {
        return {
          'exito': false,
          'mensaje':
              'La recarga no devolvió ID. Verifica que el RPC esté instalado.',
        };
      }

      return {
        'exito': true,
        'mensaje': 'Recarga guardada correctamente (ID $recargaId)',
        'recargaId': recargaId,
      };
    } catch (e) {
      // Mensaje más accionable para el caso "RPC no existe"
      final msg = e.toString();
      if (msg.contains('PGRST202') ||
          msg.toLowerCase().contains('could not find the function') ||
          msg.toLowerCase().contains('function') &&
              msg.toLowerCase().contains('not found')) {
        return {
          'exito': false,
          'mensaje':
              'No está instalada la función RPC en Supabase: guardar_recarga_inventario_y_descontar_crudos. '
              'Ejecuta el SQL de `database_rpc_recarga_frito_crudo_atomic.sql` en Supabase.',
        };
      }
      return {'exito': false, 'mensaje': 'Error: $e'};
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
        } catch (e) {
          print('Error actualizando inventario actual después de cierre: $e');
          // Aún así consideramos éxito porque el cierre se guardó
        }
      }

      // Aumentar inventario de fábrica con las devoluciones de productos crudos específicos
      // IDs: 8, 10, 12, 14, 16, 18
      const productoIdsCrudo = {8, 10, 12, 14, 16, 18};
      for (final productoId in productoIdsCrudo) {
        final cantidadDevoluciones = sobrantes[productoId] ?? 0;
        if (cantidadDevoluciones > 0) {
          try {
            await aumentarInventarioFabrica(
              productoId: productoId,
              cantidad: cantidadDevoluciones,
            );
          } catch (e) {
            print(
              'Error aumentando inventario de fábrica para producto $productoId con devoluciones $cantidadDevoluciones: $e',
            );
          }
        }
      }

      print(
        'Cierre guardado exitosamente: ID $cierreId, ${existenciaFinal.length} productos',
      );

      return true;
    } catch (e) {
      print('Error guardando cierre del día: $e');
      return false;
    }
  }

  /// Obtiene todas las ventas del día actual de todas las sucursales (para dashboard de fábrica)
  static Future<List<Venta>> getVentasHoyTodasSucursales() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener ventas de todas las sucursales');
        return [];
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await client
          .from('ventas')
          .select('*, sucursales(*)')
          .eq('fecha_venta', today)
          .order('hora_venta', ascending: false)
          .limit(50); // Limitar a 50 más recientes

      final ventas = <Venta>[];
      for (final json in response) {
        final sucursalJson = json['sucursales'] as Map<String, dynamic>?;
        final sucursal = sucursalJson != null ? Sucursal.fromJson(sucursalJson) : null;
        ventas.add(Venta.fromJson(json, sucursal: sucursal));
      }

      return ventas;
    } catch (e) {
      print('Error obteniendo ventas de todas las sucursales: $e');
      return [];
    }
  }

  /// Obtiene el resumen de producción del día (para dashboard de fábrica)
  static Future<Map<String, dynamic>> getResumenProduccionHoy() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener resumen de producción');
        return {
          'total_pedidos': 0,
          'total_producido': 0,
          'total_pendiente': 0,
        };
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Obtener todas las ventas de hoy
      final ventasHoy = await client
          .from('ventas')
          .select('id, estado, venta_detalles(cantidad)')
          .eq('fecha_venta', today);

      int totalPedidos = ventasHoy.length;
      int totalProducido = 0;
      int totalPendiente = 0;

      for (final venta in ventasHoy) {
        final estado = venta['estado'] as String;
        final detalles = venta['venta_detalles'] as List<dynamic>? ?? [];
        
        int cantidadVenta = 0;
        for (final detalle in detalles) {
          cantidadVenta += (detalle['cantidad'] as num?)?.toInt() ?? 0;
        }

        if (estado == 'completada') {
          totalProducido += cantidadVenta;
        } else if (estado == 'pendiente') {
          totalPendiente += cantidadVenta;
        }
      }

      return {
        'total_pedidos': totalPedidos,
        'total_producido': totalProducido,
        'total_pendiente': totalPendiente,
      };
    } catch (e) {
      print('Error obteniendo resumen de producción: $e');
      return {
        'total_pedidos': 0,
        'total_producido': 0,
        'total_pendiente': 0,
      };
    }
  }

  /// Obtiene todas las sucursales activas
  static Future<List<Sucursal>> getAllSucursales() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener sucursales');
        return [];
      }

      final response = await client
          .from('sucursales')
          .select()
          .eq('activa', true)
          .order('nombre');

      return response.map((json) => Sucursal.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo sucursales: $e');
      return [];
    }
  }

  /// Obtiene el resumen de una sucursal para el dashboard de fábrica
  static Future<Map<String, dynamic>> getResumenSucursal(int sucursalId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {
          'ventas_hoy': 0.0,
          'tickets_hoy': 0,
          'pedidos_pendientes': 0,
          'tiene_apertura': false,
        };
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Obtener ventas del día
      final ventasResponse = await client
          .from('ventas')
          .select('id, total')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_venta', today)
          .eq('estado', 'completada');

      double ventasHoy = 0.0;
      int ticketsHoy = 0;
      for (final venta in ventasResponse) {
        ventasHoy += (venta['total'] as num?)?.toDouble() ?? 0.0;
        ticketsHoy++;
      }

      // Obtener pedidos a fábrica pendientes
      final pedidosResponse = await client
          .from('pedidos_fabrica')
          .select('id')
          .eq('sucursal_id', sucursalId)
          .eq('estado', 'pendiente');

      final pedidosPendientes = pedidosResponse.length;

      // Verificar si tiene apertura del día
      final aperturaResponse = await client
          .from('aperturas_dia')
          .select('id')
          .eq('sucursal_id', sucursalId)
          .eq('fecha_apertura', today)
          .eq('estado', 'abierta')
          .maybeSingle();

      final tieneApertura = aperturaResponse != null;

      return {
        'ventas_hoy': ventasHoy,
        'tickets_hoy': ticketsHoy,
        'pedidos_pendientes': pedidosPendientes,
        'tiene_apertura': tieneApertura,
      };
    } catch (e) {
      print('Error obteniendo resumen de sucursal: $e');
      return {
        'ventas_hoy': 0.0,
        'tickets_hoy': 0,
        'pedidos_pendientes': 0,
        'tiene_apertura': false,
      };
    }
  }

  /// Genera un número de pedido único
  static String _generatePedidoNumber(int sucursalId, bool isOnline) {
    if (!isOnline) {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      return 'LOCAL-$sucursalId-$timestamp';
    }
    
    final now = DateTime.now();
    final fecha =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'PED-$sucursalId-$fecha-$hora';
  }

  /// Crea un nuevo pedido a fábrica
  static Future<PedidoFabrica?> crearPedidoFabrica({
    required int sucursalId,
    required int usuarioId,
    required Map<int, int> productos, // productoId -> cantidad
  }) async {
    try {
      final hasConnection = await _checkConnection();
      final now = DateTime.now();

      // Calcular total de items
      final totalItems = productos.values.fold(0, (sum, cantidad) => sum + cantidad);

      // Crear el pedido
      final pedidoData = {
        'sucursal_id': sucursalId,
        'usuario_id': usuarioId,
        'fecha_pedido': now.toIso8601String().split('T')[0],
        'hora_pedido':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'total_items': totalItems,
        'estado': 'pendiente', // Siempre pendiente al crear
        'numero_pedido': _generatePedidoNumber(sucursalId, hasConnection),
        'sincronizado': hasConnection,
      };

      // Insertar el pedido
      final pedidoResponse =
          await client.from('pedidos_fabrica').insert(pedidoData).select().single();

      final pedidoId = pedidoResponse['id'] as int;

      // Insertar los detalles del pedido
      final detallesData = productos.entries.map((entry) {
        return {
          'pedido_id': pedidoId,
          'producto_id': entry.key,
          'cantidad': entry.value,
        };
      }).toList();

      await client.from('pedido_fabrica_detalles').insert(detallesData);

      // Obtener el pedido completo con detalles
      return await getPedidoFabricaById(pedidoId);
    } catch (e) {
      print('Error creando pedido a fábrica: $e');
      return null;
    }
  }

  /// Obtiene un pedido a fábrica por ID
  static Future<PedidoFabrica?> getPedidoFabricaById(int pedidoId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedido');
        return null;
      }

      // Obtener el pedido
      final pedidoResponse = await client
          .from('pedidos_fabrica')
          .select()
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedidoResponse == null) return null;

      // Obtener los detalles
      final detallesResponse = await client
          .from('pedido_fabrica_detalles')
          .select()
          .eq('pedido_id', pedidoId);

      final detalles = detallesResponse
          .map((json) => PedidoFabricaDetalle.fromJson(json))
          .toList();

      // Obtener sucursal y usuario si es necesario
      final sucursal = await getSucursalById(pedidoResponse['sucursal_id'] as int);

      return PedidoFabrica.fromJson(
        pedidoResponse,
        sucursal: sucursal,
        detalles: detalles,
      );
    } catch (e) {
      print('Error obteniendo pedido a fábrica: $e');
      return null;
    }
  }

  /// Obtiene los pedidos recientes a fábrica de una sucursal
  static Future<List<PedidoFabrica>> getPedidosFabricaRecientes(
    int sucursalId, {
    int limit = 10,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos a fábrica');
        return [];
      }

      // Obtener los pedidos
      final pedidosResponse = await client
          .from('pedidos_fabrica')
          .select()
          .eq('sucursal_id', sucursalId)
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener detalles para cada pedido
      final pedidos = <PedidoFabrica>[];
      final sucursal = await getSucursalById(sucursalId);

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_fabrica_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse
            .map((json) => PedidoFabricaDetalle.fromJson(json))
            .toList();

        pedidos.add(
          PedidoFabrica.fromJson(
            pedidoJson,
            sucursal: sucursal,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos a fábrica recientes: $e');
      return [];
    }
  }

  /// Obtiene todos los pedidos a fábrica recientes de todas las sucursales
  static Future<List<PedidoFabrica>> getPedidosFabricaRecientesTodasSucursales({
    int limit = 10,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos a fábrica');
        return [];
      }

      // Obtener los pedidos de todas las sucursales
      final pedidosResponse = await client
          .from('pedidos_fabrica')
          .select('*, sucursales(*)')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener detalles para cada pedido
      final pedidos = <PedidoFabrica>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;
        final sucursalJson = pedidoJson['sucursales'] as Map<String, dynamic>?;
        final sucursal = sucursalJson != null ? Sucursal.fromJson(sucursalJson) : null;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_fabrica_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse
            .map((json) => PedidoFabricaDetalle.fromJson(json))
            .toList();

        pedidos.add(
          PedidoFabrica.fromJson(
            pedidoJson,
            sucursal: sucursal,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos a fábrica recientes de todas las sucursales: $e');
      return [];
    }
  }

  /// Valida si hay suficiente inventario para despachar un pedido
  /// Retorna un Map con 'valido' (bool) y 'productosInsuficientes' (List<Map>)
  static Future<Map<String, dynamic>> validarInventarioParaDespacho({
    required int pedidoId,
    required String tipoPedido, // 'fabrica', 'cliente' o 'recurrente'
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'valido': false, 'productosInsuficientes': [], 'mensaje': 'Sin conexión'};
      }

      // Obtener los detalles del pedido
      final tablaDetalles = tipoPedido == 'fabrica' 
          ? 'pedido_fabrica_detalles' 
          : tipoPedido == 'recurrente'
          ? 'pedido_recurrente_detalles'
          : 'pedido_cliente_detalles';
      
      final detallesResponse = await client
          .from(tablaDetalles)
          .select('producto_id, cantidad')
          .eq('pedido_id', pedidoId);

      // Para pedidos recurrentes, necesitamos validar diferentes inventarios según el producto
      if (tipoPedido == 'recurrente') {
        // Obtener productos para verificar nombres
        final productos = await getProductosActivos();
        final productosMap = {for (var p in productos) p.id: p};

        // Obtener inventarios
        final inventarioFabrica = await getInventarioFabricaCompleto();
        
        // Obtener inventario actual de sucursal 5
        final inventarioActualResponse = await client
            .from('inventario_actual')
            .select('producto_id, cantidad')
            .eq('sucursal_id', 5);
        final inventarioActual = <int, int>{};
        for (final item in inventarioActualResponse) {
          inventarioActual[item['producto_id'] as int] = (item['cantidad'] as num?)?.toInt() ?? 0;
        }

        final productosInsuficientes = <Map<String, dynamic>>[];

        // Validar cada producto según su nombre
        for (final detalle in detallesResponse) {
          final productoId = detalle['producto_id'] as int;
          final cantidadPedida = (detalle['cantidad'] as num?)?.toInt() ?? 0;
          final producto = productosMap[productoId];
          
          if (producto == null) continue;

          final nombreProducto = producto.nombre.toLowerCase();
          int cantidadDisponible;

          // Si contiene "frito" → validar inventario_actual (sucursal_id = 5)
          if (nombreProducto.contains('frito')) {
            cantidadDisponible = inventarioActual[productoId] ?? 0;
          }
          // Si contiene "crudo" → validar inventario_fabrica
          else if (nombreProducto.contains('crudo')) {
            cantidadDisponible = inventarioFabrica[productoId] ?? 0;
          }
          // Por defecto, validar inventario_fabrica
          else {
            cantidadDisponible = inventarioFabrica[productoId] ?? 0;
          }

          if (cantidadPedida > cantidadDisponible) {
            productosInsuficientes.add({
              'producto_id': productoId,
              'producto_nombre': producto.nombre,
              'cantidad_pedida': cantidadPedida,
              'cantidad_disponible': cantidadDisponible,
              'faltante': cantidadPedida - cantidadDisponible,
            });
          }
        }

        return {
          'valido': productosInsuficientes.isEmpty,
          'productosInsuficientes': productosInsuficientes,
        };
      } else {
        // Para pedidos de fábrica, usar inventario_fabrica
        // Para pedidos de clientes, validar según el tipo de producto (frito vs crudo)
        final inventarioFabrica = await getInventarioFabricaCompleto();
        
        // Para pedidos de clientes, también necesitamos inventario_actual de sucursal 5
        Map<int, int> inventarioActual = <int, int>{};
        if (tipoPedido == 'cliente') {
          try {
            final inventarioActualResponse = await client
                .from('inventario_actual')
                .select('producto_id, cantidad')
                .eq('sucursal_id', 5);
            for (final item in inventarioActualResponse) {
              inventarioActual[item['producto_id'] as int] = (item['cantidad'] as num?)?.toInt() ?? 0;
            }
          } catch (e) {
            print('Error obteniendo inventario_actual para pedido cliente $pedidoId: $e');
          }
        }

        // Para pedidos de clientes, necesitamos saber la sucursal
        String? sucursalNombre;
        if (tipoPedido == 'cliente') {
          try {
            final pedidoRow = await client
                .from('pedidos_clientes')
                .select('sucursal_id')
                .eq('id', pedidoId)
                .maybeSingle();
            final sucursalId = pedidoRow != null ? pedidoRow['sucursal_id'] as int? : null;
            if (sucursalId != null) {
              final sucursal = await getSucursalById(sucursalId);
              sucursalNombre = sucursal?.nombre;
            }
          } catch (e) {
            print('Error obteniendo sucursal para pedido cliente $pedidoId: $e');
          }
        }

        // Obtener productos para evaluar nombres (solo para pedidos de cliente)
        final productos = tipoPedido == 'cliente' ? await getProductosActivos() : <Producto>[];
        final productosMap = tipoPedido == 'cliente' ? {for (var p in productos) p.id: p} : <int, Producto>{};

        final productosInsuficientes = <Map<String, dynamic>>[];

        // Validar cada producto
        for (final detalle in detallesResponse) {
          final productoId = detalle['producto_id'] as int;
          final cantidadPedida = (detalle['cantidad'] as num?)?.toInt() ?? 0;
          
          int cantidadDisponible;
          
          // Para pedidos de cliente, validar según el tipo de producto
          if (tipoPedido == 'cliente' && productosMap.containsKey(productoId)) {
            final producto = productosMap[productoId]!;
            final nombreProducto = producto.nombre.toLowerCase();
            
            // Regla especial: en pedidos de clientes de la sucursal "EL DANGOND",
            // los "churro mediano" son sobre pedido y no deben validar inventario.
            if (sucursalNombre != null) {
              final sucursalNombreUpper = sucursalNombre.toUpperCase().trim();
              final esSucursalDangond = sucursalNombreUpper == 'EL DANGOND';
              if (esSucursalDangond) {
                final nombreProductoUpper = nombreProducto.toUpperCase();
                if (nombreProductoUpper.contains('CHURRO MEDIANO')) {
                  // Ignorar este producto en la validación de inventario
                  continue;
                }
              }
            }
            
            // Si contiene "frito" → validar inventario_actual (sucursal_id = 5)
            if (nombreProducto.contains('frito')) {
              cantidadDisponible = inventarioActual[productoId] ?? 0;
            }
            // Si contiene "crudo" → validar inventario_fabrica
            else if (nombreProducto.contains('crudo')) {
              cantidadDisponible = inventarioFabrica[productoId] ?? 0;
            }
            // Por defecto, validar inventario_fabrica
            else {
              cantidadDisponible = inventarioFabrica[productoId] ?? 0;
            }
          } else {
            // Para pedidos de fábrica, usar inventario_fabrica
            cantidadDisponible = inventarioFabrica[productoId] ?? 0;
          }

          if (cantidadPedida > cantidadDisponible) {
            // Obtener nombre del producto
            final producto = tipoPedido == 'cliente' && productosMap.containsKey(productoId)
                ? productosMap[productoId]
                : await getProductoById(productoId);
            productosInsuficientes.add({
              'producto_id': productoId,
              'producto_nombre': producto?.nombre ?? 'Producto #$productoId',
              'cantidad_pedida': cantidadPedida,
              'cantidad_disponible': cantidadDisponible,
              'faltante': cantidadPedida - cantidadDisponible,
            });
          }
        }

        return {
          'valido': productosInsuficientes.isEmpty,
          'productosInsuficientes': productosInsuficientes,
        };
      }
    } catch (e) {
      print('Error validando inventario: $e');
      return {'valido': false, 'productosInsuficientes': [], 'mensaje': 'Error: $e'};
    }
  }

  /// Actualiza el estado de un pedido a fábrica
  static Future<Map<String, dynamic>> actualizarEstadoPedidoFabrica({
    required int pedidoId,
    required String nuevoEstado,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'exito': false, 'mensaje': 'No hay conexión para actualizar estado del pedido'};
      }

      print('🔄 Actualizando pedido #$pedidoId a estado: $nuevoEstado');

      // Si el nuevo estado es "enviado", validar y descontar del inventario
      // Si es "entregado", solo actualizar el estado sin validar inventario
      if (nuevoEstado == 'enviado') {
        // Validar inventario antes de despachar
        final validacion = await validarInventarioParaDespacho(
          pedidoId: pedidoId,
          tipoPedido: 'fabrica',
        );

        if (!validacion['valido']) {
          final productosInsuficientes = validacion['productosInsuficientes'] as List;
          String mensaje = 'No hay suficiente inventario para despachar:\n';
          for (final producto in productosInsuficientes) {
            mensaje += '• ${producto['producto_nombre']}: Faltan ${producto['faltante']} unidades\n';
          }
          return {'exito': false, 'mensaje': mensaje, 'productosInsuficientes': productosInsuficientes};
        }

        // Obtener los detalles del pedido
        final detallesResponse = await client
            .from('pedido_fabrica_detalles')
            .select('producto_id, cantidad')
            .eq('pedido_id', pedidoId);

        // Descontar cada producto del inventario
        for (final detalle in detallesResponse) {
          final productoId = detalle['producto_id'] as int;
          final cantidad = (detalle['cantidad'] as num?)?.toInt() ?? 0;
          
          if (cantidad > 0) {
            final resultado = await _descontarInventarioFabrica(
              productoId: productoId,
              cantidad: cantidad,
            );
            if (!resultado['exito']) {
              return {'exito': false, 'mensaje': 'Error al descontar inventario: ${resultado['mensaje']}'};
            }
          }
        }
      }

      // Actualizar el estado del pedido
      await client
          .from('pedidos_fabrica')
          .update({'estado': nuevoEstado})
          .eq('id', pedidoId);

      print('✅ Pedido #$pedidoId actualizado exitosamente a estado: $nuevoEstado');
      return {'exito': true, 'mensaje': 'Pedido actualizado exitosamente'};
    } catch (e, stackTrace) {
      print('❌ Error actualizando estado del pedido #$pedidoId: $e');
      print('Stack trace: $stackTrace');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtiene el siguiente estado en la secuencia
  static String getSiguienteEstado(String estadoActual) {
    switch (estadoActual.toLowerCase()) {
      case 'pendiente':
        return 'en_preparacion';
      case 'en_preparacion':
        return 'enviado';
      case 'enviado':
        return 'entregado';
      case 'entregado':
        return 'entregado'; // Ya está en el último estado
      default:
        return 'pendiente';
    }
  }

  /// Obtiene el inventario de productos J, Q, B de la fábrica desde inventario_fabrica
  /// Retorna un Map con las claves 'J', 'Q', 'B' y sus cantidades
  static Future<Map<String, int>> getInventarioProductosFabrica() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'J': 0, 'Q': 0, 'B': 0};
      }

      // Buscar productos J, Q, B por nombre (buscamos cada uno individualmente)
      final inventario = <String, int>{'J': 0, 'Q': 0, 'B': 0};
      
      final nombresProductos = ['J', 'Q', 'B'];
      
      for (final nombreProducto in nombresProductos) {
        // Buscar producto por nombre
        final productoResponse = await client
            .from('productos')
            .select()
            .eq('activo', true)
            .eq('nombre', nombreProducto)
            .maybeSingle();

        if (productoResponse != null) {
          final productoId = productoResponse['id'] as int;

          // Obtener inventario desde inventario_fabrica
          final inventarioResponse = await client
              .from('inventario_fabrica')
              .select('cantidad')
              .eq('producto_id', productoId)
              .maybeSingle();

          if (inventarioResponse != null) {
            inventario[nombreProducto] = (inventarioResponse['cantidad'] as num?)?.toInt() ?? 0;
          }
        }
      }

      return inventario;
    } catch (e) {
      print('Error obteniendo inventario de productos de fábrica: $e');
      return {'J': 0, 'Q': 0, 'B': 0};
    }
  }

  /// Aumenta el inventario de un producto en la fábrica
  /// Si el producto no existe en inventario_fabrica, lo crea
  static Future<bool> aumentarInventarioFabrica({
    required int productoId,
    required int cantidad,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para aumentar inventario de fábrica');
        return false;
      }

      if (cantidad <= 0) {
        print('La cantidad debe ser mayor a 0');
        return false;
      }

      // Verificar si existe el registro en inventario_fabrica
      final inventarioExistente = await client
          .from('inventario_fabrica')
          .select('id, cantidad')
          .eq('producto_id', productoId)
          .maybeSingle();

      if (inventarioExistente != null) {
        // Actualizar cantidad existente
        final cantidadActual = (inventarioExistente['cantidad'] as num?)?.toInt() ?? 0;
        final nuevaCantidad = cantidadActual + cantidad;

        await client
            .from('inventario_fabrica')
            .update({
              'cantidad': nuevaCantidad,
              'ultima_actualizacion': DateTime.now().toIso8601String(),
            })
            .eq('producto_id', productoId);
      } else {
        // Crear nuevo registro
        await client.from('inventario_fabrica').insert({
          'producto_id': productoId,
          'cantidad': cantidad,
          'ultima_actualizacion': DateTime.now().toIso8601String(),
        });
      }

      return true;
    } catch (e) {
      print('Error aumentando inventario de fábrica: $e');
      return false;
    }
  }

  /// Obtiene el inventario completo de la fábrica
  static Future<Map<int, int>> getInventarioFabricaCompleto() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {};
      }

      final response = await client
          .from('inventario_fabrica')
          .select('producto_id, cantidad');

      final inventario = <int, int>{};
      for (final item in response) {
        inventario[item['producto_id'] as int] = (item['cantidad'] as num?)?.toInt() ?? 0;
      }

      return inventario;
    } catch (e) {
      print('Error obteniendo inventario completo de fábrica: $e');
      return {};
    }
  }

  /// Actualiza directamente la cantidad de un producto en inventario_fabrica
  /// Si el producto no existe en inventario_fabrica, lo crea
  static Future<bool> actualizarInventarioFabrica({
    required int productoId,
    required int cantidad,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para actualizar inventario de fábrica');
        return false;
      }

      if (cantidad < 0) {
        print('La cantidad no puede ser negativa');
        return false;
      }

      // Verificar si existe el registro en inventario_fabrica
      final inventarioExistente = await client
          .from('inventario_fabrica')
          .select('id')
          .eq('producto_id', productoId)
          .maybeSingle();

      if (inventarioExistente != null) {
        // Actualizar cantidad existente
        await client
            .from('inventario_fabrica')
            .update({
              'cantidad': cantidad,
              'ultima_actualizacion': DateTime.now().toIso8601String(),
            })
            .eq('producto_id', productoId);
      } else {
        // Crear nuevo registro
        await client.from('inventario_fabrica').insert({
          'producto_id': productoId,
          'cantidad': cantidad,
          'ultima_actualizacion': DateTime.now().toIso8601String(),
        });
      }

      return true;
    } catch (e) {
      print('Error actualizando inventario de fábrica: $e');
      return false;
    }
  }

  /// Descuenta cantidad del inventario de fábrica
  /// Método interno usado cuando se despacha un pedido
  /// Retorna un Map con 'exito' (bool) y 'mensaje' (String)
  static Future<Map<String, dynamic>> _descontarInventarioFabrica({
required int productoId,
    required int cantidad,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'exito': false, 'mensaje': 'No hay conexión para descontar inventario de fábrica'};
      }

      if (cantidad <= 0) {
        return {'exito': true, 'mensaje': 'Cantidad inválida'};
      }

      // Verificar si existe el registro en inventario_fabrica
      final inventarioExistente = await client
          .from('inventario_fabrica')
          .select('id, cantidad')
          .eq('producto_id', productoId)
          .maybeSingle();

      if (inventarioExistente != null) {
        // Descontar cantidad existente
        final cantidadActual = (inventarioExistente['cantidad'] as num?)?.toInt() ?? 0;
        
        if (cantidadActual < cantidad) {
          return {
            'exito': false,
            'mensaje': 'Inventario insuficiente. Disponible: $cantidadActual, Solicitado: $cantidad'
          };
        }

        final nuevaCantidad = cantidadActual - cantidad;

        await client
            .from('inventario_fabrica')
            .update({
              'cantidad': nuevaCantidad,
              'ultima_actualizacion': DateTime.now().toIso8601String(),
            })
            .eq('producto_id', productoId);

        return {'exito': true, 'mensaje': 'Inventario descontado exitosamente'};
      } else {
        // Si no existe inventario, no hay nada que descontar
        return {
          'exito': false,
          'mensaje': 'No existe inventario para el producto $productoId'
        };
      }
    } catch (e) {
      print('Error descontando inventario de fábrica: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Descuenta cantidad del inventario actual de una sucursal
  /// Método interno usado cuando se despacha un pedido recurrente con productos fritos
  /// Retorna un Map con 'exito' (bool) y 'mensaje' (String)
  static Future<Map<String, dynamic>> _descontarInventarioActual({
    required int sucursalId,
    required int productoId,
    required int cantidad,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'exito': false, 'mensaje': 'No hay conexión para descontar inventario actual'};
      }

      if (cantidad <= 0) {
        return {'exito': true, 'mensaje': 'Cantidad inválida'};
      }

      // Verificar si existe el registro en inventario_actual
      final inventarioExistente = await client
          .from('inventario_actual')
          .select('id, cantidad')
          .eq('sucursal_id', sucursalId)
          .eq('producto_id', productoId)
          .maybeSingle();

      if (inventarioExistente != null) {
        // Descontar cantidad existente
        final cantidadActual = (inventarioExistente['cantidad'] as num?)?.toInt() ?? 0;
        
        if (cantidadActual < cantidad) {
          return {
            'exito': false,
            'mensaje': 'Inventario insuficiente. Disponible: $cantidadActual, Solicitado: $cantidad'
          };
        }

        final nuevaCantidad = cantidadActual - cantidad;

        await client
            .from('inventario_actual')
            .update({
              'cantidad': nuevaCantidad,
              'ultima_actualizacion': DateTime.now().toIso8601String(),
            })
            .eq('sucursal_id', sucursalId)
            .eq('producto_id', productoId);

        return {'exito': true, 'mensaje': 'Inventario descontado exitosamente'};
      } else {
        // Si no existe inventario, no hay nada que descontar
        return {
          'exito': false,
          'mensaje': 'No existe inventario para el producto $productoId en la sucursal $sucursalId'
        };
      }
    } catch (e) {
      print('Error descontando inventario actual: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Descuenta cantidad del inventario actual de una sucursal (método público)
  /// Usado cuando se recarga un producto frito y se debe descontar del producto crudo
  /// Retorna un Map con 'exito' (bool) y 'mensaje' (String)
  static Future<Map<String, dynamic>> descontarInventarioActual({
    required int sucursalId,
    required int productoId,
    required int cantidad,
  }) async {
    return await _descontarInventarioActual(
      sucursalId: sucursalId,
      productoId: productoId,
      cantidad: cantidad,
    );
  }

  /// Aumenta el inventario de un producto en una sucursal
  /// Si el producto no existe en inventario_actual, lo crea
  /// Si existe, suma la cantidad a la existente
  static Future<bool> aumentarInventarioActual({
    required int sucursalId,
    required int productoId,
    required int cantidad,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para aumentar inventario actual');
        return false;
      }

      if (cantidad <= 0) {
        print('La cantidad debe ser mayor a 0');
        return false;
      }

      // Obtener cantidad actual (si existe)
      final inventarioExistente = await client
          .from('inventario_actual')
          .select('cantidad')
          .eq('sucursal_id', sucursalId)
          .eq('producto_id', productoId)
          .maybeSingle();

      final cantidadActual = inventarioExistente != null
          ? ((inventarioExistente['cantidad'] as num?)?.toInt() ?? 0)
          : 0;
      final nuevaCantidad = cantidadActual + cantidad;

      // Usar upsert para insertar o actualizar
      final data = {
        'sucursal_id': sucursalId,
        'producto_id': productoId,
        'cantidad': nuevaCantidad,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      };

      await client
          .from('inventario_actual')
          .upsert(data, onConflict: 'sucursal_id,producto_id');

      print(
        '✅ Inventario actualizado: Sucursal $sucursalId, Producto $productoId, Cantidad anterior: $cantidadActual, Cantidad agregada: $cantidad, Nueva cantidad: $nuevaCantidad',
      );

      return true;
    } catch (e) {
      print('❌ Error aumentando inventario actual: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  /// Descuenta cantidad del inventario de fábrica (método público)
  /// Retorna un Map con 'exito' (bool) y 'mensaje' (String)
  static Future<Map<String, dynamic>> descontarInventarioFabrica({
    required int productoId,
    required int cantidad,
  }) async {
    return await _descontarInventarioFabrica(
      productoId: productoId,
      cantidad: cantidad,
    );
  }

  /// Obtiene el resumen general de la fábrica
  static Future<Map<String, dynamic>> getResumenFabrica() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {
          'total_pedidos': 0,
          'pedidos_pendientes': 0,
          'meta_diaria': 0.0,
        };
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      // 1. Obtener total de pedidos a fábrica del día
      final pedidosFabricaHoy = await client
          .from('pedidos_fabrica')
          .select('id')
          .eq('fecha_pedido', today);

      // 2. Obtener total de pedidos de clientes del día
      final pedidosClientesHoy = await client
          .from('pedidos_clientes')
          .select('id')
          .eq('fecha_pedido', today);

      final totalPedidos = pedidosFabricaHoy.length + pedidosClientesHoy.length;

      // 3. Obtener pedidos pendientes de producción (pendiente + en_preparacion)
      final pedidosPendientesFabrica = await client
          .from('pedidos_fabrica')
          .select('id')
          .or('estado.eq.pendiente,estado.eq.en_preparacion');

      final pedidosPendientesClientes = await client
          .from('pedidos_clientes')
          .select('id')
          .or('estado.eq.pendiente,estado.eq.en_preparacion');

      final totalPendientes = pedidosPendientesFabrica.length + pedidosPendientesClientes.length;

      // 4. Obtener producción del día (suma de cantidad_producida)
      final produccionHoy = await client
          .from('produccion_empleado')
          .select('cantidad_producida')
          .eq('fecha_produccion', today);

      int totalProducidoHoy = 0;
      for (final prod in produccionHoy) {
        totalProducidoHoy += (prod['cantidad_producida'] as num?)?.toInt() ?? 0;
      }

      // 5. Calcular meta diaria basada en producción
      // Meta: 500 unidades producidas por día (ajustable)
      final metaDiariaUnidades = 500;
      final porcentajeMeta = metaDiariaUnidades > 0
          ? ((totalProducidoHoy / metaDiariaUnidades) * 100).clamp(0, 100)
          : 0.0;

      return {
        'total_pedidos': totalPedidos,
        'pedidos_pendientes': totalPendientes,
        'meta_diaria': porcentajeMeta,
        'total_producido': totalProducidoHoy,
      };
    } catch (e) {
      print('Error obteniendo resumen de fábrica: $e');
      return {
        'total_pedidos': 0,
        'pedidos_pendientes': 0,
        'meta_diaria': 0.0,
        'total_producido': 0,
      };
    }
  }

  /// Obtiene pedidos de clientes recientes (desde WhatsApp)
  static Future<List<PedidoCliente>> getPedidosClientesRecientes({
    int limit = 100,
    bool soloHoy = false,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos de clientes');
        return [];
      }

      // Obtener los pedidos de clientes
      var query = client
          .from('pedidos_clientes')
          .select();
      
      if (soloHoy) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        query = query.eq('fecha_pedido', today);
      }
      
      final pedidosResponse = await query
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_cliente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          return PedidoClienteDetalle.fromJson(json, producto: producto);
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos de clientes recientes: $e');
      return [];
    }
  }

  /// Obtiene pedidos de clientes pagados del día actual según fecha_pago (para página de gastos de factory)
  static Future<List<PedidoCliente>> getPedidosClientesPagados({
    int limit = 1000,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos pagados');
        return [];
      }

      // Obtener los pedidos de clientes pagados del día actual según fecha_pago
      // Usar getColombiaDateTime() para obtener la fecha correcta según zona horaria de Colombia
      final now = getColombiaDateTime();
      // Formatear la fecha como YYYY-MM-DD para comparar con fecha_pago (tipo date)
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      print('🔍 Buscando pedidos pagados con fecha_pago = $today');
      print('🔍 Filtros: estado_pago = pagado, fecha_pago = $today');
      
      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('estado_pago', 'pagado')
          .eq('fecha_pago', today)
          .order('created_at', ascending: false)
          .limit(limit);
      
      print('🔍 Pedidos pagados encontrados: ${pedidosResponse.length}');
      if (pedidosResponse.isNotEmpty) {
        print('🔍 Primer pedido encontrado: ID=${pedidosResponse.first['id']}, estado_pago=${pedidosResponse.first['estado_pago']}, fecha_pago=${pedidosResponse.first['fecha_pago']}, estado=${pedidosResponse.first['estado']}');
      } else {
        // Debug: buscar todos los pedidos pagados para ver qué fechas tienen
        final allPagados = await client
            .from('pedidos_clientes')
            .select('id, estado_pago, fecha_pago, estado')
            .eq('estado_pago', 'pagado')
            .limit(10);
        print('🔍 DEBUG Todos los pedidos pagados (primeros 10):');
        for (final p in allPagados) {
          print('🔍   ID=${p['id']}, fecha_pago=${p['fecha_pago']}, estado=${p['estado']}');
        }
        print('🔍 DEBUG Fecha buscada: $today');
        
        // Debug: buscar el pedido específico que debería aparecer
        final debugResponse = await client
            .from('pedidos_clientes')
            .select()
            .eq('id', 16)
            .maybeSingle();
        if (debugResponse != null) {
          print('🔍 DEBUG Pedido ID 16: estado_pago=${debugResponse['estado_pago']}, fecha_pago=${debugResponse['fecha_pago']}, estado=${debugResponse['estado']}');
          print('🔍 DEBUG Fecha buscada: $today');
          print('🔍 DEBUG Tipo fecha_pago: ${debugResponse['fecha_pago'].runtimeType}');
          print('🔍 DEBUG Tipo today: ${today.runtimeType}');
          print('🔍 DEBUG ¿Coinciden las fechas? ${debugResponse['fecha_pago'].toString() == today}');
        } else {
          print('🔍 DEBUG Pedido ID 16 no encontrado');
        }
      }

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_cliente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          return PedidoClienteDetalle.fromJson(json, producto: producto);
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos pagados: $e');
      return [];
    }
  }

  /// Obtiene todos los pedidos de clientes con pago pendiente (sin importar la fecha)
  static Future<List<PedidoCliente>> getPedidosClientesPendientes({
    int limit = 1000,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos pendientes');
        return [];
      }

      // Obtener todos los pedidos de clientes con estado='entregado' y estado_pago='pendiente'
      // (sin filtrar por fecha, se muestran todos hasta que se paguen)
      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('estado', 'entregado')
          .eq('estado_pago', 'pendiente')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_cliente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          return PedidoClienteDetalle.fromJson(json, producto: producto);
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos pendientes: $e');
      return [];
    }
  }

  /// Obtiene todos los pedidos recurrentes con pago pendiente (sin importar la fecha)
  static Future<List<PedidoCliente>> getPedidosRecurrentesPendientes({
    int limit = 1000,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos recurrentes pendientes');
        return [];
      }

      // Obtener todos los pedidos recurrentes con estado='entregado' y estado_pago='pendiente'
      // (sin filtrar por fecha, se muestran todos hasta que se paguen)
      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .eq('estado', 'entregado')
          .eq('estado_pago', 'pendiente')
          .order('created_at', ascending: false)
          .limit(limit);

      print('🔍 Pedidos recurrentes pendientes encontrados: ${pedidosResponse.length}');
      if (pedidosResponse.isNotEmpty) {
        print('🔍 Primer pedido: ID=${pedidosResponse.first['id']}, estado=${pedidosResponse.first['estado']}, estado_pago=${pedidosResponse.first['estado_pago']}');
      }

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_recurrente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          // Usar precio_unitario del detalle (que puede ser precio especial)
          return PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          );
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
            esRecurrente: true,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos recurrentes pendientes: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes pagados del día actual según fecha_pago (para página de gastos de factory)
  static Future<List<PedidoCliente>> getPedidosRecurrentesPagados({
    int limit = 1000,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos recurrentes pagados');
        return [];
      }

      // Obtener los pedidos recurrentes pagados del día actual según fecha_pago
      // Usar getColombiaDateTime() para obtener la fecha correcta según zona horaria de Colombia
      final now = getColombiaDateTime();
      final today = now.toIso8601String().split('T')[0];
      
      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .eq('estado_pago', 'pagado')
          .eq('fecha_pago', today)
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_recurrente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          // Usar precio_unitario del detalle (que puede ser precio especial)
          return PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          );
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
            esRecurrente: true,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos recurrentes pagados: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes recientes
  static Future<List<PedidoCliente>> getPedidosRecurrentesRecientes({
    int limit = 100,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos recurrentes');
        return [];
      }

      // Obtener los pedidos recurrentes
      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_recurrente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          // Usar precio_unitario del detalle (que puede ser precio especial)
          return PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          );
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
            esRecurrente: true,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos recurrentes recientes: $e');
      return [];
    }
  }

  /// Actualiza el estado de un pedido de cliente
  static Future<Map<String, dynamic>> actualizarEstadoPedidoCliente({
    required int pedidoId,
    required String nuevoEstado,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'exito': false, 'mensaje': 'No hay conexión para actualizar estado del pedido'};
      }

      // Si el nuevo estado es "enviado", validar y descontar del inventario
      if (nuevoEstado == 'enviado') {
        // Validar inventario antes de despachar
        final validacion = await validarInventarioParaDespacho(
          pedidoId: pedidoId,
          tipoPedido: 'cliente',
        );

        if (!validacion['valido']) {
          final productosInsuficientes =
              validacion['productosInsuficientes'] as List;
          String mensaje = 'No hay suficiente inventario para despachar:\n';
          for (final producto in productosInsuficientes) {
            mensaje +=
                '• ${producto['producto_nombre']}: Faltan ${producto['faltante']} unidades\n';
          }
          return {
            'exito': false,
            'mensaje': mensaje,
            'productosInsuficientes': productosInsuficientes,
          };
        }

        // Obtener datos de la sucursal del pedido
        String? sucursalNombre;
        try {
          final pedidoRow = await client
              .from('pedidos_clientes')
              .select('sucursal_id')
              .eq('id', pedidoId)
              .maybeSingle();
          final sucursalId =
              pedidoRow != null ? pedidoRow['sucursal_id'] as int? : null;
          if (sucursalId != null) {
            final sucursal = await getSucursalById(sucursalId);
            sucursalNombre = sucursal?.nombre;
          }
        } catch (e) {
          print(
            'Error obteniendo sucursal para descuento de inventario en pedido cliente $pedidoId: $e',
          );
        }

        // Obtener lista de productos para evaluar nombres
        final productos = await getProductosActivos();
        final productosMap = {for (var p in productos) p.id: p};

        // Obtener los detalles del pedido
        final detallesResponse = await client
            .from('pedido_cliente_detalles')
            .select('producto_id, cantidad')
            .eq('pedido_id', pedidoId);

        // Descontar cada producto del inventario según su nombre
        for (final detalle in detallesResponse) {
          final productoId = detalle['producto_id'] as int;
          final cantidad = (detalle['cantidad'] as num?)?.toInt() ?? 0;

          if (cantidad > 0) {
            final producto = productosMap[productoId];
            if (producto == null) {
              return {'exito': false, 'mensaje': 'Producto $productoId no encontrado'};
            }

            // Regla especial: en pedidos de clientes de la sucursal "EL DANGOND",
            // los "churro mediano" son sobre pedido y NO deben descontarse del inventario.
            bool saltarDescuento = false;
            if (sucursalNombre != null) {
              final sucursalNombreUpper = sucursalNombre.toUpperCase().trim();
              final esSucursalDangond = sucursalNombreUpper == 'EL DANGOND';
              if (esSucursalDangond) {
                final nombreProducto = producto.nombre.toUpperCase().trim();
                if (nombreProducto.contains('CHURRO MEDIANO')) {
                  saltarDescuento = true;
                }
              }
            }

            if (saltarDescuento) {
              continue;
            }

            final nombreProducto = producto.nombre.toLowerCase();
            Map<String, dynamic> resultado;

            // Si contiene "frito" → descontar de inventario_actual (sucursal_id = 5)
            if (nombreProducto.contains('frito')) {
              resultado = await _descontarInventarioActual(
                sucursalId: 5,
                productoId: productoId,
                cantidad: cantidad,
              );
            }
            // Si contiene "crudo" → descontar de inventario_fabrica
            else if (nombreProducto.contains('crudo')) {
              resultado = await _descontarInventarioFabrica(
                productoId: productoId,
                cantidad: cantidad,
              );
            }
            // Por defecto, descontar de inventario_fabrica
            else {
              resultado = await _descontarInventarioFabrica(
                productoId: productoId,
                cantidad: cantidad,
              );
            }

            if (!resultado['exito']) {
              return {
                'exito': false,
                'mensaje': 'Error al descontar inventario: ${resultado['mensaje']}',
              };
            }
          }
        }
      }

      await client
          .from('pedidos_clientes')
          .update({'estado': nuevoEstado})
          .eq('id', pedidoId);

      return {'exito': true, 'mensaje': 'Pedido actualizado exitosamente'};
    } catch (e) {
      print('Error actualizando estado del pedido de cliente: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Marca un pedido de cliente como pagado
  static Future<bool> marcarPedidoClienteComoPagado({
    required int pedidoId,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para marcar pedido como pagado');
        return false;
      }

      // Usar getColombiaDateTime() para obtener la fecha correcta según zona horaria de Colombia
      final now = getColombiaDateTime();
      final today = now.toIso8601String().split('T')[0];

      await client
          .from('pedidos_clientes')
          .update({
            'estado_pago': 'pagado',
            'fecha_pago': today,
          })
          .eq('id', pedidoId);

      return true;
    } catch (e) {
      print('Error marcando pedido de cliente como pagado: $e');
      return false;
    }
  }

  /// Marca un pedido recurrente como pagado
  static Future<bool> marcarPedidoRecurrenteComoPagado({
    required int pedidoId,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para marcar pedido como pagado');
        return false;
      }

      // Usar getColombiaDateTime() para obtener la fecha correcta según zona horaria de Colombia
      final now = getColombiaDateTime();
      final today = now.toIso8601String().split('T')[0];

      await client
          .from('pedidos_recurrentes')
          .update({
            'estado_pago': 'pagado',
            'fecha_pago': today,
          })
          .eq('id', pedidoId);

      return true;
    } catch (e) {
      print('Error marcando pedido recurrente como pagado: $e');
      return false;
    }
  }

  /// Actualiza el total y domicilio de un pedido de cliente
  static Future<bool> actualizarTotalDomicilioPedidoCliente({
    required int pedidoId,
    required double total,
    double? domicilio,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para actualizar pedido');
        return false;
      }

      final updateData = <String, dynamic>{
        'total': total,
      };

      // Siempre actualizar el domicilio (incluso si es null para eliminarlo)
      if (domicilio != null && domicilio > 0) {
        updateData['domicilio'] = domicilio;
      } else {
        // Si es null o <= 0, establecer como null para eliminar el domicilio
        updateData['domicilio'] = null;
      }

      await client
          .from('pedidos_clientes')
          .update(updateData)
          .eq('id', pedidoId);

      return true;
    } catch (e) {
      print('Error actualizando total y domicilio del pedido de cliente: $e');
      return false;
    }
  }

  /// Actualiza el total y domicilio de un pedido recurrente
  static Future<bool> actualizarTotalDomicilioPedidoRecurrente({
    required int pedidoId,
    required double total,
    double? domicilio,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para actualizar pedido');
        return false;
      }

      final updateData = <String, dynamic>{
        'total': total,
      };

      // Siempre actualizar el domicilio (incluso si es null para eliminarlo)
      if (domicilio != null && domicilio > 0) {
        updateData['domicilio'] = domicilio;
      } else {
        // Si es null o <= 0, establecer como null para eliminar el domicilio
        updateData['domicilio'] = null;
      }

      await client
          .from('pedidos_recurrentes')
          .update(updateData)
          .eq('id', pedidoId);

      return true;
    } catch (e) {
      print('Error actualizando total y domicilio del pedido recurrente: $e');
      return false;
    }
  }

  /// Actualiza el estado de un pedido recurrente
  static Future<Map<String, dynamic>> actualizarEstadoPedidoRecurrente({
    required int pedidoId,
    required String nuevoEstado,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return {'exito': false, 'mensaje': 'No hay conexión para actualizar estado del pedido'};
      }

      // Si el nuevo estado es "enviado", validar y descontar del inventario
      if (nuevoEstado == 'enviado') {
        // Validar inventario antes de despachar
        final validacion = await validarInventarioParaDespacho(
          pedidoId: pedidoId,
          tipoPedido: 'recurrente',
        );

        if (!validacion['valido']) {
          final productosInsuficientes = validacion['productosInsuficientes'] as List;
          String mensaje = 'No hay suficiente inventario para despachar:\n';
          for (final producto in productosInsuficientes) {
            mensaje += '• ${producto['producto_nombre']}: Faltan ${producto['faltante']} unidades\n';
          }
          return {'exito': false, 'mensaje': mensaje, 'productosInsuficientes': productosInsuficientes};
        }

        // Obtener los detalles del pedido recurrente
        final detallesResponse = await client
            .from('pedido_recurrente_detalles')
            .select('producto_id, cantidad')
            .eq('pedido_id', pedidoId);

        // Obtener productos para verificar nombres
        final productos = await getProductosActivos();
        final productosMap = {for (var p in productos) p.id: p};

        // Descontar cada producto del inventario según su nombre
        for (final detalle in detallesResponse) {
          final productoId = detalle['producto_id'] as int;
          final cantidad = (detalle['cantidad'] as num?)?.toInt() ?? 0;
          
          if (cantidad > 0) {
            final producto = productosMap[productoId];
            if (producto == null) {
              return {'exito': false, 'mensaje': 'Producto $productoId no encontrado'};
            }

            final nombreProducto = producto.nombre.toLowerCase();
            Map<String, dynamic> resultado;

            // Si contiene "frito" → descontar de inventario_actual (sucursal_id = 5)
            if (nombreProducto.contains('frito')) {
              resultado = await _descontarInventarioActual(
                sucursalId: 5,
                productoId: productoId,
                cantidad: cantidad,
              );
            }
            // Si contiene "crudo" → descontar de inventario_fabrica
            else if (nombreProducto.contains('crudo')) {
              resultado = await _descontarInventarioFabrica(
                productoId: productoId,
                cantidad: cantidad,
              );
            }
            // Por defecto, descontar de inventario_fabrica
            else {
              resultado = await _descontarInventarioFabrica(
                productoId: productoId,
                cantidad: cantidad,
              );
            }

            if (!resultado['exito']) {
              return {'exito': false, 'mensaje': 'Error al descontar inventario: ${resultado['mensaje']}'};
            }
          }
        }
      }

      await client
          .from('pedidos_recurrentes')
          .update({'estado': nuevoEstado})
          .eq('id', pedidoId);

      return {'exito': true, 'mensaje': 'Pedido actualizado exitosamente'};
    } catch (e) {
      print('Error actualizando estado del pedido recurrente: $e');
      return {'exito': false, 'mensaje': 'Error: $e'};
    }
  }

  /// Obtiene pedidos de fábrica con estado "enviado" o "entregado" para entregar
  static Future<List<PedidoFabrica>> getPedidosFabricaParaDespacho({
    int limit = 100,
    String? estadoFiltro, // Opcional: si se especifica, filtra por ese estado
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos para despacho');
        return [];
      }

      // Si se especifica estadoFiltro, usar ese estado; si no, traer "enviado" y "entregado"
      final today = DateTime.now().toIso8601String().split('T')[0];
      PostgrestFilterBuilder query = client
          .from('pedidos_fabrica')
          .select('*, sucursales(*)')
          .eq('fecha_pedido', today);

      if (estadoFiltro != null) {
        query = query.eq('estado', estadoFiltro);
      } else {
        query = query.or('estado.eq.enviado,estado.eq.entregado');
      }

      // Obtener los pedidos con los estados especificados
      final pedidosResponse = await query
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener detalles para cada pedido
      final pedidos = <PedidoFabrica>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;
        final sucursalJson = pedidoJson['sucursales'] as Map<String, dynamic>?;
        final sucursal = sucursalJson != null ? Sucursal.fromJson(sucursalJson) : null;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_fabrica_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse
            .map((json) => PedidoFabricaDetalle.fromJson(json))
            .toList();

        pedidos.add(
          PedidoFabrica.fromJson(
            pedidoJson,
            sucursal: sucursal,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos de fábrica para despacho: $e');
      return [];
    }
  }

  /// Obtiene todos los gastos de punto de venta del día actual
  static Future<List<Map<String, dynamic>>> getGastosPuntoVenta({
    required int sucursalId,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener gastos de punto de venta');
        return [];
      }

      // Usar el mismo formato que se usa al crear gastos para mantener consistencia
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      print('Buscando gastos para sucursal $sucursalId en fecha: $today');
      
      // Primero verificar si hay gastos sin filtrar por fecha para debugging
      final allGastos = await client
          .from('gastos_puntoventa')
          .select()
          .eq('sucursal_id', sucursalId)
          .limit(10);
      
      print('Total gastos de la sucursal (últimos 10): ${allGastos.length}');
      if (allGastos.isNotEmpty) {
        print('Ejemplo de gasto sin filtrar: fecha=${allGastos.first['fecha']}, monto=${allGastos.first['monto']}');
      }
      
      final response = await client
          .from('gastos_puntoventa')
          .select()
          .eq('sucursal_id', sucursalId)
          .eq('fecha', today)
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);

      final gastos = List<Map<String, dynamic>>.from(response);
      print('Gastos encontrados para hoy: ${gastos.length}');
      
      // Log detallado para debugging
      if (gastos.isNotEmpty) {
        print('Primer gasto de hoy: ${gastos.first}');
        for (var gasto in gastos) {
          final monto = gasto['monto'];
          print('Gasto - id: ${gasto['id']}, monto: $monto, tipo: ${monto.runtimeType}, fecha: ${gasto['fecha']}');
        }
      } else {
        print('No se encontraron gastos para la fecha $today');
      }
      
      return gastos;
    } catch (e, stackTrace) {
      print('Error obteniendo gastos de punto de venta: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Crea un nuevo gasto de punto de venta
  static Future<bool> crearGastoPuntoVenta({
    required int sucursalId,
    required int usuarioId,
    required String descripcion,
    required double monto,
    required String tipo, // 'personal', 'pago_pedido', 'pago_ocasional', 'otro'
    String? categoria,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para crear gasto de punto de venta');
        return false;
      }

      final data = {
        'sucursal_id': sucursalId,
        'usuario_id': usuarioId,
        'descripcion': descripcion,
        'monto': monto,
        'tipo': tipo,
        'categoria': categoria,
        'fecha': DateTime.now().toIso8601String().split('T')[0],
        'hora': DateTime.now().toIso8601String().split('T')[1].split('.')[0],
      };

      await client.from('gastos_puntoventa').insert(data);

      return true;
    } catch (e) {
      print('Error creando gasto de punto de venta: $e');
      return false;
    }
  }

  /// Obtiene todos los gastos varios del día actual
  static Future<List<Map<String, dynamic>>> getGastosVarios() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener gastos varios');
        return [];
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await client
          .from('gastos_varios')
          .select()
          .eq('fecha', today)
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo gastos varios: $e');
      return [];
    }
  }

  /// Obtiene todos los gastos varios para una fecha específica
  static Future<List<Map<String, dynamic>>> getGastosVariosPorFecha(
      String fecha) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener gastos varios por fecha');
        return [];
      }

      final response = await client
          .from('gastos_varios')
          .select()
          .eq('fecha', fecha)
          .order('fecha', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo gastos varios por fecha: $e');
      return [];
    }
  }

  /// Crea un nuevo gasto varios
  static Future<bool> crearGastoVario({
    required String descripcion,
    required double monto,
    required String tipo, // 'compra', 'pago', 'otro', 'nomina'
    String? categoria,
    int? empleadoId,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para crear gasto varios');
        return false;
      }

      final data = <String, dynamic>{
        'descripcion': descripcion,
        'monto': monto,
        'tipo': tipo,
        'categoria': categoria,
        'fecha': DateTime.now().toIso8601String().split('T')[0],
      };

      // Si hay empleado_id, intentar insertarlo (algunas BD aún no tienen esa columna).
      // Si falla por "column does not exist", reintentar sin empleado_id para no bloquear nómina.
      if (empleadoId != null) {
        data['empleado_id'] = empleadoId;
      }

      try {
        await client.from('gastos_varios').insert(data);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        final isTipoConstraint =
            msg.contains('gastos_varios_tipo_check') ||
            (msg.contains('violates check constraint') &&
                msg.contains('tipo_check'));
        final isMissingEmpleadoIdColumn =
            msg.contains('empleado_id') &&
            (msg.contains('does not exist') ||
                msg.contains('column') && msg.contains('not found'));
        if (isTipoConstraint && (data['tipo'] == 'nomina')) {
          // La BD aún no permite 'nomina' como tipo. Reintentar con tipo 'pago'
          // manteniendo la descripción "Nómina - X" para que no se pierda el contexto.
          data['tipo'] = 'pago';
          await client.from('gastos_varios').insert(data);
        } else if (isMissingEmpleadoIdColumn) {
          // Reintentar sin el campo que no existe en la tabla
          data.remove('empleado_id');
          await client.from('gastos_varios').insert(data);
        } else {
          rethrow;
        }
      }

      return true;
    } catch (e) {
      print('Error creando gasto varios: $e');
      return false;
    }
  }

  /// Obtiene pedidos de clientes con estado "enviado" o "entregado"
  static Future<List<PedidoCliente>> getPedidosClientesParaDespacho({
    int limit = 100,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos para despacho');
        return [];
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Obtener los pedidos de hoy con estado enviado o entregado
      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('fecha_pedido', today)
          .or('estado.eq.enviado,estado.eq.entregado')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_cliente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          return PedidoClienteDetalle.fromJson(json, producto: producto);
        }).toList();

        pedidos.add(
          PedidoCliente.fromJson(
            pedidoJson,
            detalles: detalles,
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error obteniendo pedidos de clientes para despacho: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes con estado "enviado" o "entregado"
  static Future<List<PedidoCliente>> getPedidosRecurrentesParaDespacho({
    int limit = 100,
    String? estadoFiltro, // Opcional: si se especifica, filtra por ese estado
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener pedidos recurrentes para despacho');
        return [];
      }

      final today = DateTime.now().toIso8601String().split('T')[0];

      // Construir la consulta base
      PostgrestFilterBuilder query = client
          .from('pedidos_recurrentes')
          .select()
          .eq('fecha_pedido', today);

      // Si se especifica estadoFiltro, usar ese estado; si no, traer "enviado" y "entregado"
      if (estadoFiltro != null) {
        query = query.eq('estado', estadoFiltro);
      } else {
        query = query.or('estado.eq.enviado,estado.eq.entregado');
      }

      // Obtener los pedidos recurrentes con los estados especificados
      final pedidosResponse = await query
          .order('created_at', ascending: false)
          .limit(limit);

      print('🔍 Pedidos recurrentes encontrados en BD: ${pedidosResponse.length}');
      if (pedidosResponse.isNotEmpty) {
        print('🔍 Primer pedido estado: ${pedidosResponse[0]['estado']}, fecha: ${pedidosResponse[0]['fecha_pedido']}');
      }

      if (pedidosResponse.isEmpty) return [];

      // Obtener productos para los detalles
      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      // Obtener detalles para cada pedido
      final pedidos = <PedidoCliente>[];

      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;

        // Obtener detalles
        final detallesResponse = await client
            .from('pedido_recurrente_detalles')
            .select()
            .eq('pedido_id', pedidoId);

        final detalles = detallesResponse.map((json) {
          final productoId = json['producto_id'] as int;
          final producto = productosMap[productoId];
          // Usar precio_unitario del detalle (que puede ser precio especial)
          return PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          );
        }).toList();

        final pedido = PedidoCliente.fromJson(
          pedidoJson,
          detalles: detalles,
          esRecurrente: true,
        );
        
        // Debug: verificar estado después de parsear
        if (pedidos.isEmpty) {
          print('🔍 Primer pedido recurrente parseado - ID: ${pedido.id}, estado: ${pedido.estado}, fecha: ${pedido.fechaPedido}');
        }
        
        pedidos.add(pedido);
      }

      print('🔍 Total pedidos recurrentes parseados: ${pedidos.length}');
      return pedidos;
    } catch (e, stackTrace) {
      print('Error obteniendo pedidos recurrentes para despacho: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  /// Genera un número de pedido de cliente único
  static String _generatePedidoClienteNumber(bool isOnline) {
    if (!isOnline) {
      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      return 'LOCAL-CLIENTE-$timestamp';
    }
    
    final now = DateTime.now();
    final fecha =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'PED-CLIENTE-$fecha-$hora';
  }

  /// Crea un nuevo pedido de cliente
  static Future<PedidoCliente?> crearPedidoCliente({
    required String clienteNombre,
    String? clienteTelefono,
    required String direccionEntrega,
    required Map<int, int> productos, // productoId -> cantidad
    Map<int, double>? preciosEspeciales, // productoId -> precio unitario (opcional)
    String? observaciones,
    String? metodoPago,
    double? domicilio,
    bool esFiado = false,
    double? parteEfectivo,
    double? parteTransferencia,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      final now = getColombiaDateTime();

      // Obtener productos para calcular precios
      final productosActivos = await getProductosActivos();
      final productosMap = {for (var p in productosActivos) p.id: p};

      // Calcular total de items y total
      int totalItems = 0;
      double total = 0.0;
      final detallesData = <Map<String, dynamic>>[];

      for (final entry in productos.entries) {
        final producto = productosMap[entry.key];
        if (producto == null || entry.value <= 0) continue;

        final cantidad = entry.value;
        final precioEspecial = preciosEspeciales?[producto.id];
        final tienePrecioEspecial =
            precioEspecial != null &&
            precioEspecial > 0 &&
            precioEspecial != producto.precio;
        final precioUnitario =
            tienePrecioEspecial ? precioEspecial : producto.precio;
        final precioTotal = precioUnitario * cantidad;

        totalItems += cantidad;
        total += precioTotal;

        detallesData.add({
          'producto_id': producto.id,
          'cantidad': cantidad,
          'precio_unitario': precioUnitario,
          'precio_total': precioTotal,
        });
      }

      if (totalItems == 0) {
        print('No hay productos en el pedido');
        return null;
      }

      // Nota: El domicilio NO se suma al total, se guarda por separado en el campo 'domicilio'
      // El campo 'total' solo contiene el valor del pedido sin incluir el domicilio

      // Determinar estado_pago y fecha_pago según si es fiado
      final today = now.toIso8601String().split('T')[0];
      final estadoPago = esFiado ? 'pendiente' : 'pagado';
      final fechaPago = esFiado ? null : today;
      
      // Agregar "FIADO" a las observaciones si es fiado
      String? observacionesFinal = observaciones;
      if (esFiado) {
        observacionesFinal = observaciones == null || observaciones.isEmpty
            ? 'FIADO'
            : '$observaciones - FIADO';
      }

      // Crear el pedido
      final pedidoData = <String, dynamic>{
        'cliente_nombre': clienteNombre,
        'cliente_telefono': clienteTelefono,
        'direccion_entrega': direccionEntrega,
        'fecha_pedido': now.toIso8601String().split('T')[0],
        'hora_pedido':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'total_items': totalItems,
        'total': total,
        'estado': 'pendiente',
        'numero_pedido': _generatePedidoClienteNumber(hasConnection),
        'observaciones': observacionesFinal,
        'metodo_pago': metodoPago,
        'sincronizado': hasConnection,
        'estado_pago': estadoPago,
        'fecha_pago': fechaPago,
      };

      // Agregar domicilio si existe
      if (domicilio != null && domicilio > 0) {
        pedidoData['domicilio'] = domicilio;
      }

      // Agregar parte_efectivo y parte_transferencia si el método de pago es mixto
      if (metodoPago == 'mixto') {
        if (parteEfectivo != null && parteEfectivo > 0) {
          pedidoData['parte_efectivo'] = parteEfectivo;
        }
        if (parteTransferencia != null && parteTransferencia > 0) {
          pedidoData['parte_transferencia'] = parteTransferencia;
        }
      }

      // Insertar el pedido
      final pedidoResponse =
          await client.from('pedidos_clientes').insert(pedidoData).select().single();

      final pedidoId = pedidoResponse['id'] as int;

      // Insertar los detalles del pedido
      final detallesConPedidoId =
          detallesData.map((detalle) {
            return {...detalle, 'pedido_id': pedidoId};
          }).toList();

      await client.from('pedido_cliente_detalles').insert(detallesConPedidoId);

      // Obtener el pedido completo con detalles
      final pedidos = await getPedidosClientesRecientes(limit: 1);
      if (pedidos.isNotEmpty && pedidos.first.id == pedidoId) {
        return pedidos.first;
      }

      return null;
    } catch (e) {
      print('Error creando pedido de cliente: $e');
      return null;
    }
  }

  /// Obtiene todos los empleados activos
  static Future<List<Empleado>> getEmpleadosActivos() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener empleados');
        return [];
      }

      final response = await client
          .from('empleados')
          .select()
          .eq('activo', true)
          .order('nombre');

      return response.map((json) => Empleado.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo empleados activos: $e');
      return [];
    }
  }

  /// Guarda un registro de producción de empleado
  static Future<bool> guardarProduccionEmpleado({
    int? empleadoId,
    required int productoId,
    required int cantidadProducida,
    int? pedidoFabricaId,
    int? pedidoClienteId,
    String? observaciones,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para guardar producción de empleado');
        return false;
      }

      final now = DateTime.now();
      final fechaProduccion = now.toIso8601String().split('T')[0];
      final horaProduccion =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final data = {
        'empleado_id': empleadoId ?? 1, // Valor por defecto, ya no se asocia a empleados
        'producto_id': productoId,
        'cantidad_producida': cantidadProducida,
        'fecha_produccion': fechaProduccion,
        'hora_produccion': horaProduccion,
        'pedido_fabrica_id': pedidoFabricaId,
        'pedido_cliente_id': pedidoClienteId,
        'observaciones': observaciones,
      };

      await client.from('produccion_empleado').insert(data);
      return true;
    } catch (e) {
      print('Error guardando producción de empleado: $e');
      return false;
    }
  }

  /// Obtiene la producción de empleados para un detalle de pedido específico
  static Future<List<ProduccionEmpleado>> getProduccionPorDetalle({
    required int productoId,
    int? pedidoFabricaId,
    int? pedidoClienteId,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener producción por detalle');
        return [];
      }

      var query = client
          .from('produccion_empleado')
          .select('*, empleados(*), productos(*)')
          .eq('producto_id', productoId);

      if (pedidoFabricaId != null) {
        query = query.eq('pedido_fabrica_id', pedidoFabricaId);
      } else if (pedidoClienteId != null) {
        query = query.eq('pedido_cliente_id', pedidoClienteId);
      }

      final response = await query.order('created_at', ascending: false);

      final empleados = await getEmpleadosActivos();
      final empleadosMap = {for (var e in empleados) e.id: e};

      final productos = await getProductosActivos();
      final productosMap = {for (var p in productos) p.id: p};

      return response.map((json) {
        final empleadoJson = json['empleados'] as Map<String, dynamic>?;
        final empleado = empleadoJson != null
            ? Empleado.fromJson(empleadoJson)
            : empleadosMap[json['empleado_id'] as int];

        final productoJson = json['productos'] as Map<String, dynamic>?;
        final producto = productoJson != null
            ? Producto.fromJson(productoJson)
            : productosMap[json['producto_id'] as int];

        return ProduccionEmpleado.fromJson(
          json,
          empleado: empleado,
          producto: producto,
        );
      }).toList();
    } catch (e) {
      print('Error obteniendo producción por detalle: $e');
      return [];
    }
  }

  /// Obtiene estadísticas completas de fábrica
  static Future<Map<String, dynamic>> getEstadisticasFabrica() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        return _getEstadisticasVacias();
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String()
          .split('T')[0];

      // 1. Estadísticas de pedidos a fábrica
      final pedidosFabrica = await client
          .from('pedidos_fabrica')
          .select('id, estado, fecha_pedido, total_items');

      final pedidosPorEstado = <String, int>{
        'pendiente': 0,
        'en_preparacion': 0,
        'enviado': 0,
        'entregado': 0,
        'cancelado': 0,
      };

      int totalPedidosHoy = 0;
      int totalItemsHoy = 0;

      for (final pedido in pedidosFabrica) {
        final estado = pedido['estado'] as String;
        pedidosPorEstado[estado] = (pedidosPorEstado[estado] ?? 0) + 1;

        if (pedido['fecha_pedido'] == today) {
          totalPedidosHoy++;
          totalItemsHoy += (pedido['total_items'] as num?)?.toInt() ?? 0;
        }
      }

      // 2. Estadísticas de pedidos de clientes
      final pedidosClientes = await client
          .from('pedidos_clientes')
          .select('id, estado, fecha_pedido, total_items, total');

      final pedidosClientesPorEstado = <String, int>{
        'pendiente': 0,
        'en_preparacion': 0,
        'enviado': 0,
        'entregado': 0,
        'cancelado': 0,
      };

      int totalPedidosClientesHoy = 0;
      double totalIngresosClientesHoy = 0.0;

      for (final pedido in pedidosClientes) {
        final estado = pedido['estado'] as String;
        pedidosClientesPorEstado[estado] =
            (pedidosClientesPorEstado[estado] ?? 0) + 1;

        if (pedido['fecha_pedido'] == today) {
          totalPedidosClientesHoy++;
          totalIngresosClientesHoy +=
              (pedido['total'] as num?)?.toDouble() ?? 0.0;
        }
      }

      // 3. Estadísticas de producción del día
      final produccionHoy = await client
          .from('produccion_empleado')
          .select('id, cantidad_producida, empleado_id, producto_id')
          .eq('fecha_produccion', today);

      int totalProducidoHoy = 0;
      final produccionPorEmpleado = <int, int>{};
      final produccionPorProducto = <int, int>{};

      for (final prod in produccionHoy) {
        final cantidad = (prod['cantidad_producida'] as num?)?.toInt() ?? 0;
        totalProducidoHoy += cantidad;

        final empleadoId = prod['empleado_id'] as int;
        produccionPorEmpleado[empleadoId] =
            (produccionPorEmpleado[empleadoId] ?? 0) + cantidad;

        final productoId = prod['producto_id'] as int;
        produccionPorProducto[productoId] =
            (produccionPorProducto[productoId] ?? 0) + cantidad;
      }

      // 4. Empleados activos
      final empleadosActivos = await client
          .from('empleados')
          .select('id')
          .eq('activo', true);

      final totalEmpleadosActivos = empleadosActivos.length;

      // 5. Producción de los últimos 7 días
      final produccionUltimos7Dias = await client
          .from('produccion_empleado')
          .select('fecha_produccion, cantidad_producida')
          .gte('fecha_produccion', sevenDaysAgo)
          .lte('fecha_produccion', today);

      final produccionPorDia = <String, int>{};
      for (final prod in produccionUltimos7Dias) {
        final fecha = prod['fecha_produccion'] as String;
        final cantidad = (prod['cantidad_producida'] as num?)?.toInt() ?? 0;
        produccionPorDia[fecha] = (produccionPorDia[fecha] ?? 0) + cantidad;
      }

      // 6. Top productos más producidos (últimos 7 días)
      final topProductos = await client
          .from('produccion_empleado')
          .select('producto_id, cantidad_producida')
          .gte('fecha_produccion', sevenDaysAgo);

      final productosProduccion = <int, int>{};
      for (final prod in topProductos) {
        final productoId = prod['producto_id'] as int;
        final cantidad = (prod['cantidad_producida'] as num?)?.toInt() ?? 0;
        productosProduccion[productoId] =
            (productosProduccion[productoId] ?? 0) + cantidad;
      }

      // Convertir Map<int, int> a Map<String, int> para serialización
      final produccionPorEmpleadoStr = <String, int>{};
      produccionPorEmpleado.forEach((key, value) {
        produccionPorEmpleadoStr[key.toString()] = value;
      });

      final produccionPorProductoStr = <String, int>{};
      produccionPorProducto.forEach((key, value) {
        produccionPorProductoStr[key.toString()] = value;
      });

      final productosProduccionStr = <String, int>{};
      productosProduccion.forEach((key, value) {
        productosProduccionStr[key.toString()] = value;
      });

      return {
        'pedidos_fabrica': {
          'total_hoy': totalPedidosHoy,
          'total_items_hoy': totalItemsHoy,
          'por_estado': pedidosPorEstado,
        },
        'pedidos_clientes': {
          'total_hoy': totalPedidosClientesHoy,
          'ingresos_hoy': totalIngresosClientesHoy,
          'por_estado': pedidosClientesPorEstado,
        },
        'produccion': {
          'total_hoy': totalProducidoHoy,
          'por_empleado': produccionPorEmpleadoStr,
          'por_producto': produccionPorProductoStr,
          'ultimos_7_dias': produccionPorDia,
        },
        'empleados': {
          'total_activos': totalEmpleadosActivos,
        },
        'top_productos': productosProduccionStr,
      };
    } catch (e) {
      print('Error obteniendo estadísticas de fábrica: $e');
      return _getEstadisticasVacias();
    }
  }

  static Map<String, dynamic> _getEstadisticasVacias() {
    return {
      'pedidos_fabrica': {
        'total_hoy': 0,
        'total_items_hoy': 0,
        'por_estado': {
          'pendiente': 0,
          'en_preparacion': 0,
          'enviado': 0,
          'entregado': 0,
          'cancelado': 0,
        },
      },
      'pedidos_clientes': {
        'total_hoy': 0,
        'ingresos_hoy': 0.0,
        'por_estado': {
          'pendiente': 0,
          'en_preparacion': 0,
          'enviado': 0,
          'entregado': 0,
          'cancelado': 0,
        },
      },
      'produccion': {
        'total_hoy': 0,
        'por_empleado': <String, int>{},
        'por_producto': <String, int>{},
        'ultimos_7_dias': <String, int>{},
      },
      'empleados': {
        'total_activos': 0,
      },
      'top_productos': <String, int>{},
    };
  }

  // ========== MÉTODOS CRUD PARA PRODUCTOS ==========

  /// Obtiene todos los productos (activos e inactivos)
  static Future<List<Producto>> getAllProductos() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener productos');
        return [];
      }

      final categorias = await getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};

      final response = await client.from('productos').select().order('nombre');

      return response.map((json) {
        final categoria =
            json['categoria_id'] != null
                ? categoriasMap[json['categoria_id']]
                : null;
        return Producto.fromJson(json, categoria: categoria);
      }).toList();
    } catch (e) {
      print('Error obteniendo todos los productos: $e');
      return [];
    }
  }

  /// Crea un nuevo producto
  static Future<Producto?> crearProducto({
    required String nombre,
    String? descripcion,
    int? categoriaId,
    required double precio,
    String unidadMedida = 'unidad',
    bool activo = true,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para crear producto');
        return null;
      }

      final data = {
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria_id': categoriaId,
        'precio': precio,
        'unidad_medida': unidadMedida,
        'activo': activo,
      };

      final response = await client.from('productos').insert(data).select().single();

      final categorias = await getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};
      final categoria = categoriaId != null ? categoriasMap[categoriaId] : null;

      return Producto.fromJson(response, categoria: categoria);
    } catch (e) {
      print('Error creando producto: $e');
      return null;
    }
  }

  /// Actualiza un producto existente
  static Future<Producto?> actualizarProducto({
    required int productoId,
    String? nombre,
    String? descripcion,
    int? categoriaId,
    double? precio,
    String? unidadMedida,
    bool? activo,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para actualizar producto');
        return null;
      }

      final data = <String, dynamic>{};
      if (nombre != null) data['nombre'] = nombre;
      if (descripcion != null) data['descripcion'] = descripcion;
      if (categoriaId != null) data['categoria_id'] = categoriaId;
      if (precio != null) data['precio'] = precio;
      if (unidadMedida != null) data['unidad_medida'] = unidadMedida;
      if (activo != null) data['activo'] = activo;

      if (data.isEmpty) {
        // Si no hay cambios, obtener el producto actual
        return await getProductoById(productoId);
      }

      final response = await client
          .from('productos')
          .update(data)
          .eq('id', productoId)
          .select()
          .single();

      final categorias = await getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};
      final categoria = response['categoria_id'] != null
          ? categoriasMap[response['categoria_id']]
          : null;

      return Producto.fromJson(response, categoria: categoria);
    } catch (e) {
      print('Error actualizando producto: $e');
      return null;
    }
  }

  /// Obtiene un producto por ID
  static Future<Producto?> getProductoById(int productoId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener producto');
        return null;
      }

      final response = await client
          .from('productos')
          .select()
          .eq('id', productoId)
          .maybeSingle();

      if (response == null) return null;

      final categorias = await getCategorias();
      final categoriasMap = {for (var cat in categorias) cat.id: cat};
      final categoria = response['categoria_id'] != null
          ? categoriasMap[response['categoria_id']]
          : null;

      return Producto.fromJson(response, categoria: categoria);
    } catch (e) {
      print('Error obteniendo producto: $e');
      return null;
    }
  }

  /// Elimina un producto (soft delete - marca como inactivo)
  static Future<bool> eliminarProducto(int productoId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para eliminar producto');
        return false;
      }

      // Soft delete - marcar como inactivo
      await client
          .from('productos')
          .update({'activo': false})
          .eq('id', productoId);

      return true;
    } catch (e) {
      print('Error eliminando producto: $e');
      return false;
    }
  }

  // ========== MÉTODOS CRUD PARA EMPLEADOS ==========

  /// Obtiene todos los empleados (activos e inactivos)
  static Future<List<Empleado>> getAllEmpleados() async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener empleados');
        return [];
      }

      final response = await client
          .from('empleados')
          .select()
          .order('nombre');

      return response.map((json) => Empleado.fromJson(json)).toList();
    } catch (e) {
      print('Error obteniendo todos los empleados: $e');
      return [];
    }
  }

  /// Crea un nuevo empleado
  static Future<Empleado?> crearEmpleado({
    required String nombre,
    String? telefono,
    String? email,
    bool activo = true,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para crear empleado');
        return null;
      }

      final data = {
        'nombre': nombre,
        'telefono': telefono,
        'email': email,
        'activo': activo,
      };

      final response = await client.from('empleados').insert(data).select().single();

      return Empleado.fromJson(response);
    } catch (e) {
      print('Error creando empleado: $e');
      return null;
    }
  }

  /// Actualiza un empleado existente
  static Future<Empleado?> actualizarEmpleado({
    required int empleadoId,
    String? nombre,
    String? telefono,
    String? email,
    bool? activo,
  }) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para actualizar empleado');
        return null;
      }

      final data = <String, dynamic>{};
      if (nombre != null) data['nombre'] = nombre;
      if (telefono != null) data['telefono'] = telefono;
      if (email != null) data['email'] = email;
      if (activo != null) data['activo'] = activo;

      if (data.isEmpty) {
        // Si no hay cambios, obtener el empleado actual
        return await getEmpleadoById(empleadoId);
      }

      final response = await client
          .from('empleados')
          .update(data)
          .eq('id', empleadoId)
          .select()
          .single();

      return Empleado.fromJson(response);
    } catch (e) {
      print('Error actualizando empleado: $e');
      return null;
    }
  }

  /// Obtiene un empleado por ID
  static Future<Empleado?> getEmpleadoById(int empleadoId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para obtener empleado');
        return null;
      }

      final response = await client
          .from('empleados')
          .select()
          .eq('id', empleadoId)
          .maybeSingle();

      if (response == null) return null;

      return Empleado.fromJson(response);
    } catch (e) {
      print('Error obteniendo empleado: $e');
      return null;
    }
  }

  /// Elimina un empleado (soft delete - marca como inactivo)
  static Future<bool> eliminarEmpleado(int empleadoId) async {
    try {
      final hasConnection = await _checkConnection();
      if (!hasConnection) {
        print('No hay conexión para eliminar empleado');
        return false;
      }

      // Soft delete - marcar como inactivo
      await client
          .from('empleados')
          .update({'activo': false})
          .eq('id', empleadoId);

      return true;
    } catch (e) {
      print('Error eliminando empleado: $e');
      return false;
    }
  }

  // ===================================================================
  // MÉTODOS OPTIMIZADOS (Fast) - Carga en batch, sin N+1, sin redundancias
  // ===================================================================

  /// Obtiene pedidos de fábrica recientes de todas las sucursales (OPTIMIZADO).
  /// Usa batch loading para detalles (1 query en vez de N).
  /// Recibe [productosMap] opcional pre-cargado para evitar re-fetch.
  static Future<List<PedidoFabrica>> getPedidosFabricaRecientesTodasSucursalesFast({
    int limit = 100,
    Map<int, Producto>? productosMap,
  }) async {
    try {
      final pedidosResponse = await client
          .from('pedidos_fabrica')
          .select('*, sucursales(*)')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Recopilar todos los IDs de pedidos
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();

      // Batch: obtener TODOS los detalles en UNA sola query
      final allDetallesResponse = await client
          .from('pedido_fabrica_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      // Agrupar detalles por pedido_id
      final detallesPorPedido = <int, List<PedidoFabricaDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoFabricaDetalle.fromJson(json));
      }

      // Construir objetos PedidoFabrica
      final pedidos = <PedidoFabrica>[];
      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;
        final sucursalJson =
            pedidoJson['sucursales'] as Map<String, dynamic>?;
        final sucursal =
            sucursalJson != null ? Sucursal.fromJson(sucursalJson) : null;

        pedidos.add(
          PedidoFabrica.fromJson(
            pedidoJson,
            sucursal: sucursal,
            detalles: detallesPorPedido[pedidoId] ?? [],
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error (fast) obteniendo pedidos fábrica: $e');
      return [];
    }
  }

  /// Obtiene pedidos de clientes recientes (OPTIMIZADO).
  /// Batch loading de detalles + productosMap pre-cargado.
  static Future<List<PedidoCliente>> getPedidosClientesRecientesFast({
    int limit = 100,
    bool soloHoy = false,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      var query = client.from('pedidos_clientes').select();
      if (soloHoy) {
        final today = DateTime.now().toIso8601String().split('T')[0];
        query = query.eq('fecha_pedido', today);
      }
      final pedidosResponse = await query
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch: obtener todos los detalles en 1 query
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_cliente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      // Agrupar detalles por pedido_id
      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoClienteDetalle.fromJson(json, producto: producto));
      }

      // Construir objetos
      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos clientes: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes recientes (OPTIMIZADO).
  /// Batch loading de detalles + productosMap pre-cargado.
  static Future<List<PedidoCliente>> getPedidosRecurrentesRecientesFast({
    int limit = 100,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch: obtener todos los detalles en 1 query
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_recurrente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      // Agrupar detalles por pedido_id
      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= []).add(
          PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          ),
        );
      }

      // Construir objetos
      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
          esRecurrente: true,
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos recurrentes: $e');
      return [];
    }
  }

  /// Obtiene pedidos de fábrica para despacho (OPTIMIZADO).
  static Future<List<PedidoFabrica>> getPedidosFabricaParaDespachoFast({
    int limit = 100,
    String? estadoFiltro,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      PostgrestFilterBuilder query = client
          .from('pedidos_fabrica')
          .select('*, sucursales(*)')
          .eq('fecha_pedido', today);

      if (estadoFiltro != null) {
        query = query.eq('estado', estadoFiltro);
      } else {
        query = query.or('estado.eq.enviado,estado.eq.entregado');
      }

      final pedidosResponse = await query
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch: obtener todos los detalles en 1 query
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_fabrica_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      // Agrupar detalles por pedido_id
      final detallesPorPedido = <int, List<PedidoFabricaDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoFabricaDetalle.fromJson(json));
      }

      final pedidos = <PedidoFabrica>[];
      for (final pedidoJson in pedidosResponse) {
        final pedidoId = pedidoJson['id'] as int;
        final sucursalJson =
            pedidoJson['sucursales'] as Map<String, dynamic>?;
        final sucursal =
            sucursalJson != null ? Sucursal.fromJson(sucursalJson) : null;

        pedidos.add(
          PedidoFabrica.fromJson(
            pedidoJson,
            sucursal: sucursal,
            detalles: detallesPorPedido[pedidoId] ?? [],
          ),
        );
      }

      return pedidos;
    } catch (e) {
      print('Error (fast) obteniendo pedidos fábrica despacho: $e');
      return [];
    }
  }

  /// Obtiene pedidos de clientes para despacho (OPTIMIZADO).
  static Future<List<PedidoCliente>> getPedidosClientesParaDespachoFast({
    int limit = 100,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('fecha_pedido', today)
          .or('estado.eq.enviado,estado.eq.entregado')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch: obtener todos los detalles en 1 query
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_cliente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      // Agrupar detalles por pedido_id
      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoClienteDetalle.fromJson(json, producto: producto));
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos clientes despacho: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes para despacho (OPTIMIZADO).
  static Future<List<PedidoCliente>> getPedidosRecurrentesParaDespachoFast({
    int limit = 100,
    String? estadoFiltro,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      PostgrestFilterBuilder query = client
          .from('pedidos_recurrentes')
          .select()
          .eq('fecha_pedido', today);

      if (estadoFiltro != null) {
        query = query.eq('estado', estadoFiltro);
      } else {
        query = query.or('estado.eq.enviado,estado.eq.entregado');
      }

      final pedidosResponse = await query
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch: obtener todos los detalles en 1 query
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_recurrente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      // Agrupar detalles por pedido_id
      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= []).add(
          PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          ),
        );
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
          esRecurrente: true,
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos recurrentes despacho: $e');
      return [];
    }
  }

  /// Obtiene pedidos de clientes pagados (OPTIMIZADO) para la página de gastos.
  static Future<List<PedidoCliente>> getPedidosClientesPagadosFast({
    int limit = 1000,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final now = getColombiaDateTime();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('estado_pago', 'pagado')
          .eq('fecha_pago', today)
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch detalles
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_cliente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoClienteDetalle.fromJson(json, producto: producto));
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos pagados: $e');
      return [];
    }
  }

  /// Obtiene pedidos de clientes pagados por fecha (OPTIMIZADO) para histórico de gastos.
  static Future<List<PedidoCliente>> getPedidosClientesPagadosPorFechaFast({
    required String fecha, // formato 'YYYY-MM-DD'
    int limit = 1000,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('estado_pago', 'pagado')
          .eq('fecha_pago', fecha)
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch detalles
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_cliente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoClienteDetalle.fromJson(json, producto: producto));
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos pagados por fecha: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes pagados (OPTIMIZADO) para la página de gastos.
  static Future<List<PedidoCliente>> getPedidosRecurrentesPagadosFast({
    int limit = 1000,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final now = getColombiaDateTime();
      final today =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .eq('estado_pago', 'pagado')
          .eq('fecha_pago', today)
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch detalles
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_recurrente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= []).add(
          PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          ),
        );
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
          esRecurrente: true,
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos recurrentes pagados: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes pagados por fecha (OPTIMIZADO) para histórico de gastos.
  static Future<List<PedidoCliente>> getPedidosRecurrentesPagadosPorFechaFast({
    required String fecha, // formato 'YYYY-MM-DD'
    int limit = 1000,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .eq('estado_pago', 'pagado')
          .eq('fecha_pago', fecha)
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch detalles
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_recurrente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= []).add(
          PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          ),
        );
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
          esRecurrente: true,
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos recurrentes pagados por fecha: $e');
      return [];
    }
  }

  /// Obtiene pedidos de clientes pendientes de pago (OPTIMIZADO).
  static Future<List<PedidoCliente>> getPedidosClientesPendientesFast({
    int limit = 1000,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final pedidosResponse = await client
          .from('pedidos_clientes')
          .select()
          .eq('estado', 'entregado')
          .or('estado_pago.is.null,estado_pago.eq.pendiente')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch detalles
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_cliente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= [])
            .add(PedidoClienteDetalle.fromJson(json, producto: producto));
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos clientes pendientes: $e');
      return [];
    }
  }

  /// Obtiene pedidos recurrentes pendientes de pago (OPTIMIZADO).
  static Future<List<PedidoCliente>> getPedidosRecurrentesPendientesFast({
    int limit = 1000,
    required Map<int, Producto> productosMap,
  }) async {
    try {
      final pedidosResponse = await client
          .from('pedidos_recurrentes')
          .select()
          .eq('estado', 'entregado')
          .or('estado_pago.is.null,estado_pago.eq.pendiente')
          .order('created_at', ascending: false)
          .limit(limit);

      if (pedidosResponse.isEmpty) return [];

      // Batch detalles
      final pedidoIds = pedidosResponse.map((p) => p['id'] as int).toList();
      final allDetallesResponse = await client
          .from('pedido_recurrente_detalles')
          .select()
          .inFilter('pedido_id', pedidoIds);

      final detallesPorPedido = <int, List<PedidoClienteDetalle>>{};
      for (final json in allDetallesResponse) {
        final pedidoId = json['pedido_id'] as int;
        final productoId = json['producto_id'] as int;
        final producto = productosMap[productoId];
        (detallesPorPedido[pedidoId] ??= []).add(
          PedidoClienteDetalle(
            id: json['id'] as int,
            pedidoId: pedidoId,
            productoId: productoId,
            producto: producto,
            cantidad: json['cantidad'] as int,
            precioUnitario: (json['precio_unitario'] as num).toDouble(),
            precioTotal: (json['precio_total'] as num).toDouble(),
            createdAt: DateTime.parse(json['created_at'] as String),
          ),
        );
      }

      return pedidosResponse.map((pedidoJson) {
        final pedidoId = pedidoJson['id'] as int;
        return PedidoCliente.fromJson(
          pedidoJson,
          detalles: detallesPorPedido[pedidoId] ?? [],
          esRecurrente: true,
        );
      }).toList();
    } catch (e) {
      print('Error (fast) obteniendo pedidos recurrentes pendientes pago: $e');
      return [];
    }
  }
}
