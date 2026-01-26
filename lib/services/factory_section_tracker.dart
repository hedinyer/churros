/// Tracks whether the user is currently inside any Factory screen.
///
/// We keep this intentionally simple: each factory page calls `enter()` on
/// `initState` and `exit()` on `dispose`. If multiple factory routes are stacked,
/// the counter will stay > 0.
class FactorySectionTracker {
  static int _depth = 0;

  static bool get isInFactory => _depth > 0;

  static void enter() {
    _depth++;
  }

  static void exit() {
    if (_depth <= 0) return;
    _depth--;
  }
}

