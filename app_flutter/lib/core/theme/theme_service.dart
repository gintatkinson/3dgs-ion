import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistence contract for theme-related user preferences.
///
/// Implementations store and retrieve values from a platform-specific
/// store (e.g. [SharedPreferences], secure storage, or in-memory for
/// tests). All load methods return a sensible default when no value has
/// been persisted yet. No method throws on missing keys.
abstract class ThemeService {
  /// Loads the persisted [ThemeMode]; defaults to [ThemeMode.system] when
  /// no value has been saved yet.
  Future<ThemeMode> loadThemeMode();

  /// Persists [themeMode] so it survives app restarts.
  Future<void> saveThemeMode(ThemeMode themeMode);

  /// Loads the persisted colour-scheme index; defaults to `0`.
  Future<int> loadThemeScheme();

  /// Persists the colour-scheme [index] so it survives app restarts.
  Future<void> saveThemeScheme(int index);

  /// Loads the persisted text scale factor; defaults to `1.0`.
  Future<double> loadTextScale();

  /// Persists the text [scale] factor so it survives app restarts.
  Future<void> saveTextScale(double scale);

  /// Loads the persisted workspace split axis orientation; defaults to
  /// [Axis.horizontal] if the key is missing or invalid.
  Future<Axis> loadLayoutSplitAxis();

  /// Persists [axis] so it survives app restarts.
  Future<void> saveLayoutSplitAxis(Axis axis);

  /// Loads the persisted panel opacity; defaults to `0.85`.
  Future<double> loadPanelOpacity();

  /// Persists the panel [opacity] so it survives app restarts.
  Future<void> savePanelOpacity(double opacity);
}

/// [ThemeService] implementation backed by [SharedPreferences].
///
/// Stores each value under its own key. Missing keys return the same
/// default as the abstract interface: [ThemeMode.system], `0`, and `1.0`.
/// Does not catch or wrap platform exceptions (e.g. if the plugin is not
/// initialised).
class SharedPreferencesThemeService implements ThemeService {
  static const _modeKey = 'theme_mode';
  static const _schemeKey = 'theme_scheme';
  static const _textScaleKey = 'text_scale';
  static const _layoutSplitAxisKey = 'layout_split_axis';
  static const _panelOpacityKey = 'panel_opacity';

  /// Reads the theme-mode string; unknown values fall back to system.
  @override
  Future<ThemeMode> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_modeKey);
      switch (value) {
        case 'light': return ThemeMode.light;
        case 'dark': return ThemeMode.dark;
        default: return ThemeMode.system;
      }
    } catch (e, stackTrace) {
      debugPrint('Error in loadThemeMode: $e\n$stackTrace');
      return ThemeMode.system;
    }
  }

  /// Writes a "light" / "dark" / "system" string.
  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = themeMode == ThemeMode.light ? 'light'
          : themeMode == ThemeMode.dark ? 'dark'
          : 'system';
      await prefs.setString(_modeKey, value);
    } catch (e, stackTrace) {
      debugPrint('Error in saveThemeMode: $e\n$stackTrace');
    }
  }

  /// Reads an integer index; returns `0` when absent.
  @override
  Future<int> loadThemeScheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_schemeKey) ?? 0;
    } catch (e, stackTrace) {
      debugPrint('Error in loadThemeScheme: $e\n$stackTrace');
      return 0;
    }
  }

  /// Persists the scheme [index] as an integer.
  @override
  Future<void> saveThemeScheme(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_schemeKey, index);
    } catch (e, stackTrace) {
      debugPrint('Error in saveThemeScheme: $e\n$stackTrace');
    }
  }

  /// Reads a double; returns `1.0` when absent.
  @override
  Future<double> loadTextScale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_textScaleKey) ?? 1.0;
    } catch (e, stackTrace) {
      debugPrint('Error in loadTextScale: $e\n$stackTrace');
      return 1.0;
    }
  }

  /// Persists the [scale] as a double.
  @override
  Future<void> saveTextScale(double scale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_textScaleKey, scale);
    } catch (e, stackTrace) {
      debugPrint('Error in saveTextScale: $e\n$stackTrace');
    }
  }

  /// Reads the workspace split axis string; unknown/invalid values fall back to horizontal.
  @override
  Future<Axis> loadLayoutSplitAxis() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_layoutSplitAxisKey);
      switch (value) {
        case 'vertical':
          return Axis.vertical;
        case 'horizontal':
          return Axis.horizontal;
        default:
          return Axis.vertical;
      }
    } catch (e, stackTrace) {
      debugPrint('Error in loadLayoutSplitAxis: $e\n$stackTrace');
      return Axis.vertical;
    }
  }

  /// Writes a "horizontal" or "vertical" string.
  @override
  Future<void> saveLayoutSplitAxis(Axis axis) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = axis == Axis.vertical ? 'vertical' : 'horizontal';
      await prefs.setString(_layoutSplitAxisKey, value);
    } catch (e, stackTrace) {
      debugPrint('Error in saveLayoutSplitAxis: $e\n$stackTrace');
    }
  }

  @override
  Future<double> loadPanelOpacity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_panelOpacityKey) ?? 0.85;
    } catch (e, stackTrace) {
      debugPrint('Error in loadPanelOpacity: $e\n$stackTrace');
      return 0.85;
    }
  }

  @override
  Future<void> savePanelOpacity(double opacity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_panelOpacityKey, opacity);
    } catch (e, stackTrace) {
      debugPrint('Error in savePanelOpacity: $e\n$stackTrace');
    }
  }
}
