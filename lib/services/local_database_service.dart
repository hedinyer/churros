import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseService {
  static Database? _database;
  static const String _databaseName = 'churros_local.db';
  static const int _databaseVersion = 3;
  static const String _tableName = 'users';

  /// Obtiene la instancia de la base de datos
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa la base de datos y crea las tablas
  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crea las tablas en la base de datos
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY,
        user_id TEXT NOT NULL,
        access_key TEXT,
        sucursal INTEGER,
        type INTEGER,
        UNIQUE(user_id)
      )
    ''');
  }

  /// Maneja las migraciones de la base de datos
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar columna sucursal a la tabla users
      await db.execute('ALTER TABLE $_tableName ADD COLUMN sucursal INTEGER');
    }
    if (oldVersion < 3) {
      // Agregar columna type a la tabla users
      await db.execute('ALTER TABLE $_tableName ADD COLUMN type INTEGER');
    }
  }

  /// Verifica las credenciales del usuario en la base de datos local
  /// Retorna el usuario si las credenciales son correctas, null si no
  static Future<Map<String, dynamic>?> verifyUserCredentials(
    String userIdentifier,
    String accessKey,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        _tableName,
        where: 'user_id = ? AND access_key = ?',
        whereArgs: [userIdentifier, accessKey],
        limit: 1,
      );

      if (results.isNotEmpty) {
        // Convertir el resultado a formato compatible con Supabase
        final user = results.first;
        return {
          'id': user['id'],
          'user_id': user['user_id'],
          'access_key': user['access_key'],
          'sucursal': user['sucursal'],
          'type': user['type'],
        };
      }
      return null;
    } catch (e) {
      print('Error verificando credenciales en base de datos local: $e');
      return null;
    }
  }

  /// Convierte un valor de id de Supabase a int para SQLite
  static int? _convertIdToInt(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    if (id is num) return id.toInt();
    return null;
  }

  /// Inserta o actualiza un usuario en la base de datos local
  static Future<void> upsertUser({
    dynamic id,
    required String userId,
    String? accessKey,
    int? sucursalId,
    int? type,
  }) async {
    try {
      final db = await database;
      final convertedId = _convertIdToInt(id);
      await db.insert(
        _tableName,
        {
          if (convertedId != null) 'id': convertedId,
          'user_id': userId,
          'access_key': accessKey,
          'sucursal': sucursalId,
          'type': type,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error insertando/actualizando usuario en base de datos local: $e');
      rethrow;
    }
  }

  /// Obtiene todos los usuarios de la base de datos local
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final db = await database;
      return await db.query(_tableName);
    } catch (e) {
      print('Error obteniendo usuarios de base de datos local: $e');
      return [];
    }
  }

  /// Elimina un usuario de la base de datos local
  static Future<void> deleteUser(String userId) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('Error eliminando usuario de base de datos local: $e');
      rethrow;
    }
  }

  /// Sincroniza usuarios desde Supabase a la base de datos local
  static Future<void> syncUsersFromSupabase(
    List<Map<String, dynamic>> supabaseUsers,
  ) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        for (final user in supabaseUsers) {
          final convertedId = _convertIdToInt(user['id']);
          await txn.insert(
            _tableName,
            {
              if (convertedId != null) 'id': convertedId,
              'user_id': user['user_id'] as String,
              'access_key': user['access_key'] as String?,
              'sucursal': user['sucursal'] as int?,
              'type': user['type'] as int?,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error sincronizando usuarios desde Supabase: $e');
      rethrow;
    }
  }

  /// Cierra la base de datos
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

