import 'dart:async';
import 'package:flutter/material.dart';
import 'theme_service.dart';

/// Manages a clamped text scale factor and persists it via [ThemeService].
///
/// Exposes a [ChangeNotifier] interface for reactive UI updates. The
/// scale is clamped to the range [0.7, 1.5] on every write so that text
/// never becomes unreadable at either extreme.
///
/// **State**: caches the current scale in memory and persists through
/// [ThemeService] on every [setScale] call. Persistence failures are
/// logged via [debugPrint] but never thrown.
///
/// **Edge cases**: a null [ThemeService] skips persistence entirely;
/// values outside [0.7, 1.5] are silently clamped.
class TextScalerController extends ChangeNotifier {
  TextScalerController([this._themeService]);
  final ThemeService? _themeService;
  double _scale = 1.0;
  bool _disposed = false;

  /// The current text scale factor, always in [0.7, 1.5].
  double get scale => _scale;

  /// Loads the persisted scale factor from [ThemeService].
  ///
  /// Returns `1.0` when no value has been saved or when the service is
  /// null. Fires `notifyListeners()` after loading so the UI refreshes.
  Future<void> load() async {
    final val = await _themeService?.loadTextScale() ?? 1.0;
    if (_disposed) return;
    _scale = val;
    notifyListeners();
  }

  /// Sets the scale factor (clamped to [0.7, 1.5]) and persists it.
  ///
  /// Notifies listeners immediately and schedules persistence
  /// asynchronously. Persistence errors are caught and logged via
  /// [debugPrint] — they never propagate to the caller.
  void setScale(double value) {
    _scale = value.clamp(0.7, 1.5);
    notifyListeners();
    unawaited(_themeService?.saveTextScale(_scale).catchError((Object e) {
      debugPrint('Failed to save text scale: $e');
    }));
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
