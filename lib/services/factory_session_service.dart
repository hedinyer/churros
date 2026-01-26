import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the current logged-in session is "Factory" (type == 2).
///
/// This is used to enable noisy realtime notifications even if the user is not
/// currently on a specific factory route (e.g., when navigating to shared pages).
class FactorySessionService {
  FactorySessionService._();

  static const String _keyIsFactorySession = 'is_factory_session_v1';

  static bool _initialized = false;
  static bool _isFactorySession = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _isFactorySession = prefs.getBool(_keyIsFactorySession) ?? false;
    _initialized = true;
  }

  static bool get isFactorySessionSync => _isFactorySession;

  static Future<bool> isFactorySession() async {
    await ensureInitialized();
    return _isFactorySession;
  }

  static Future<void> setFactorySession(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsFactorySession, value);
    _isFactorySession = value;
    _initialized = true;
  }
}

