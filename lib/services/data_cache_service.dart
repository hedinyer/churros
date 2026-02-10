import '../models/producto.dart';
import '../models/categoria.dart';
import 'supabase_service.dart';

/// Servicio de caché en memoria para datos que cambian poco (productos, categorías).
/// Evita re-descargar estos datos cada vez que se entra a una sección.
/// El caché se invalida automáticamente después de [_cacheDuration].
class DataCacheService {
  // Caché de productos
  static List<Producto>? _productosCache;
  static DateTime? _productosLastFetch;

  // Caché de categorías
  static List<Categoria>? _categoriasCache;
  static DateTime? _categoriasLastFetch;

  // Mapa de productos por ID (derivado del caché)
  static Map<int, Producto>? _productosMapCache;

  // Mapa de categorías por ID (derivado del caché)
  static Map<int, Categoria>? _categoriasMapCache;

  // Duración del caché: 5 minutos
  static const _cacheDuration = Duration(minutes: 5);

  // Flag para saber si ya se verificó la conexión en este "ciclo"
  static bool? _lastConnectionCheck;
  static DateTime? _lastConnectionCheckTime;
  static const _connectionCheckDuration = Duration(seconds: 30);

  /// Verifica la conexión una sola vez cada 30 segundos (evita queries redundantes)
  static Future<bool> checkConnectionCached() async {
    if (_lastConnectionCheck != null &&
        _lastConnectionCheckTime != null &&
        DateTime.now().difference(_lastConnectionCheckTime!) <
            _connectionCheckDuration) {
      return _lastConnectionCheck!;
    }
    try {
      await SupabaseService.client
          .from('users')
          .select('id')
          .limit(1)
          .maybeSingle();
      _lastConnectionCheck = true;
      _lastConnectionCheckTime = DateTime.now();
      return true;
    } catch (e) {
      _lastConnectionCheck = false;
      _lastConnectionCheckTime = DateTime.now();
      return false;
    }
  }

  /// Obtiene productos activos (desde caché si disponible)
  static Future<List<Producto>> getProductosActivos({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _productosCache != null && _productosLastFetch != null) {
      if (DateTime.now().difference(_productosLastFetch!) < _cacheDuration) {
        return _productosCache!;
      }
    }

    // Cargar desde la red
    final productos = await SupabaseService.getProductosActivos();
    if (productos.isNotEmpty) {
      _productosCache = productos;
      _productosLastFetch = DateTime.now();
      _productosMapCache = {for (var p in productos) p.id: p};
    }
    return productos;
  }

  /// Obtiene categorías (desde caché si disponible)
  static Future<List<Categoria>> getCategorias({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _categoriasCache != null &&
        _categoriasLastFetch != null) {
      if (DateTime.now().difference(_categoriasLastFetch!) < _cacheDuration) {
        return _categoriasCache!;
      }
    }

    // Cargar desde la red
    final categorias = await SupabaseService.getCategorias();
    if (categorias.isNotEmpty) {
      _categoriasCache = categorias;
      _categoriasLastFetch = DateTime.now();
      _categoriasMapCache = {for (var c in categorias) c.id: c};
    }
    return categorias;
  }

  /// Obtiene mapa de productos por ID (desde caché)
  static Future<Map<int, Producto>> getProductosMap({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _productosMapCache != null && _productosLastFetch != null) {
      if (DateTime.now().difference(_productosLastFetch!) < _cacheDuration) {
        return _productosMapCache!;
      }
    }
    await getProductosActivos(forceRefresh: forceRefresh);
    return _productosMapCache ?? {};
  }

  /// Obtiene mapa de categorías por ID (desde caché)
  static Future<Map<int, Categoria>> getCategoriasMap({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _categoriasMapCache != null &&
        _categoriasLastFetch != null) {
      if (DateTime.now().difference(_categoriasLastFetch!) < _cacheDuration) {
        return _categoriasMapCache!;
      }
    }
    await getCategorias(forceRefresh: forceRefresh);
    return _categoriasMapCache ?? {};
  }

  /// Pre-carga productos y categorías en paralelo.
  /// Llamar desde el dashboard para tener datos listos.
  static Future<void> preload() async {
    await Future.wait([
      getProductosActivos(),
      getCategorias(),
    ]);
  }

  /// Invalida todo el caché
  static void invalidateAll() {
    _productosCache = null;
    _productosLastFetch = null;
    _productosMapCache = null;
    _categoriasCache = null;
    _categoriasLastFetch = null;
    _categoriasMapCache = null;
    _lastConnectionCheck = null;
    _lastConnectionCheckTime = null;
  }

  /// Invalida solo el caché de productos
  static void invalidateProductos() {
    _productosCache = null;
    _productosLastFetch = null;
    _productosMapCache = null;
  }

  /// Invalida solo el caché de categorías
  static void invalidateCategorias() {
    _categoriasCache = null;
    _categoriasLastFetch = null;
    _categoriasMapCache = null;
  }
}
