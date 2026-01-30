import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database_service.dart';
import 'supabase_service.dart';

/// Servicio que maneja la cola de sincronización de operaciones de Supabase
/// Asegura que todas las operaciones se guarden eventualmente, incluso con conexión lenta o intermitente
class SyncQueueService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  static final SupabaseClient _client = SupabaseService.client;

  /// Inicializa el servicio de cola de sincronización
  static Future<void> initialize() async {
    // Procesar cola inmediatamente al iniciar
    await processSyncQueue();
    
    // Configurar timer para procesar cola cada 30 segundos
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => processSyncQueue(),
    );
    
    print('✅ SyncQueueService inicializado');
  }

  /// Procesa todas las operaciones pendientes en la cola
  static Future<void> processSyncQueue() async {
    if (_isSyncing) {
      print('⏳ Sincronización ya en progreso, omitiendo...');
      return;
    }

    // Verificar conexión primero
    final hasConnection = await SupabaseService.checkConnection();
    if (!hasConnection) {
      print('⚠️ Sin conexión, no se puede procesar cola de sincronización');
      return;
    }

    _isSyncing = true;
    try {
      final pendingOps = await LocalDatabaseService.getPendingSyncOperations(limit: 20);
      
      if (pendingOps.isEmpty) {
        print('✅ No hay operaciones pendientes en la cola');
        return;
      }

      print('🔄 Procesando ${pendingOps.length} operaciones pendientes...');

      for (final op in pendingOps) {
        try {
          final queueId = op['id'] as int;
          final operationType = op['operation_type'] as String;
          final tableName = op['table_name'] as String;
          final data = op['data'] as Map<String, dynamic>;

          bool success = false;

          switch (operationType) {
            case 'insert':
              success = await _processInsert(tableName, data);
              break;
            case 'update':
              success = await _processUpdate(tableName, data);
              break;
            case 'delete':
              success = await _processDelete(tableName, data);
              break;
            case 'rpc':
              success = await _processRpc(tableName, data);
              break;
            default:
              print('⚠️ Tipo de operación desconocido: $operationType');
          }

          if (success) {
            await LocalDatabaseService.markSyncOperationCompleted(queueId);
            print('✅ Operación $queueId completada exitosamente');
          } else {
            await LocalDatabaseService.incrementSyncRetry(queueId);
            print('⚠️ Operación $queueId falló, se reintentará más tarde');
          }
        } catch (e) {
          print('❌ Error procesando operación ${op['id']}: $e');
          await LocalDatabaseService.incrementSyncRetry(op['id'] as int);
        }
      }
    } catch (e) {
      print('❌ Error procesando cola de sincronización: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Procesa una operación de inserción
  static Future<bool> _processInsert(String tableName, Map<String, dynamic> data) async {
    try {
      await _client.from(tableName).insert(data);
      return true;
    } catch (e) {
      print('Error en insert a $tableName: $e');
      return false;
    }
  }

  /// Procesa una operación de actualización
  static Future<bool> _processUpdate(String tableName, Map<String, dynamic> data) async {
    try {
      final id = data['id'];
      if (id == null) {
        print('Error: falta ID para actualización');
        return false;
      }
      
      final updateData = Map<String, dynamic>.from(data);
      updateData.remove('id');
      
      await _client.from(tableName).update(updateData).eq('id', id);
      return true;
    } catch (e) {
      print('Error en update a $tableName: $e');
      return false;
    }
  }

  /// Procesa una operación de eliminación
  static Future<bool> _processDelete(String tableName, Map<String, dynamic> data) async {
    try {
      final id = data['id'];
      if (id == null) {
        print('Error: falta ID para eliminación');
        return false;
      }
      
      await _client.from(tableName).delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error en delete a $tableName: $e');
      return false;
    }
  }

  /// Procesa una llamada RPC
  static Future<bool> _processRpc(String functionName, Map<String, dynamic> data) async {
    try {
      // El data contiene los parámetros del RPC
      await _client.rpc(functionName, params: data);
      return true;
    } catch (e) {
      print('Error en RPC $functionName: $e');
      return false;
    }
  }

  /// Agrega una operación a la cola (se ejecutará cuando haya conexión)
  static Future<int> queueOperation({
    required String operationType,
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    return await LocalDatabaseService.addToSyncQueue(
      operationType: operationType,
      tableName: tableName,
      data: data,
    );
  }

  /// Intenta ejecutar una operación directamente, si falla la agrega a la cola
  static Future<Map<String, dynamic>> executeOrQueue({
    required String operationType,
    required String tableName,
    required Map<String, dynamic> data,
    required Future<dynamic> Function() directOperation,
  }) async {
    try {
      // Intentar ejecutar directamente primero
      final hasConnection = await SupabaseService.checkConnection();
      if (hasConnection) {
        try {
          final result = await directOperation();
          return {
            'success': true,
            'result': result,
            'queued': false,
          };
        } catch (e) {
          // Si falla por timeout o conexión lenta, agregar a cola
          print('⚠️ Operación directa falló, agregando a cola: $e');
        }
      }
      
      // Agregar a cola si no hay conexión o falló
      final queueId = await queueOperation(
        operationType: operationType,
        tableName: tableName,
        data: data,
      );
      
      return {
        'success': true,
        'queued': true,
        'queueId': queueId,
        'message': 'Operación agregada a cola de sincronización',
      };
    } catch (e) {
      print('❌ Error en executeOrQueue: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Detiene el servicio de sincronización
  static void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
