import 'dart:convert';
import 'package:flutter/services.dart';

/// Runtime-loaded string resources backed by a JSON file.
///
/// All UI display strings come from `assets/strings.json` so they can be
/// updated without a code rebuild. Call [load] once during app startup
/// (e.g. in `main()`) before any widget reads from [get]. For tests use
/// [loadFromJson] to inject strings without touching the filesystem.
///
/// **State**: caches the entire map in a static field after loading.
/// **Edge cases**: missing keys return the key itself or an optional
/// [fallback]; loading invalid JSON throws.
class StringResources {
  static Map<String, String> _strings = {};

  /// Loads strings from `assets/strings.json` via [rootBundle].
  ///
  /// Must be called before any call to [get]. Calling this again replaces
  /// the entire string map. Throws on invalid JSON or missing asset.
  static Future<void> load() async {
    final json = await rootBundle.loadString('assets/strings.json');
    _strings = Map<String, String>.from(jsonDecode(json) as Map);
  }

  /// Returns the string for [key] or [fallback] (defaults to [key] itself).
  ///
  /// When [key] is missing and [fallback] is null the raw key is returned so
  /// that missing translations degrade gracefully instead of crashing.
  static String get(String key, {String? fallback}) =>
      _strings[key] ?? fallback ?? key;

  /// Loads strings from a raw JSON string — intended for tests.
  ///
  /// Replaces any previously cached strings. Throws on invalid JSON input.
  /// Does **not** touch `rootBundle` or the filesystem.
  static void loadFromJson(String json) {
    _strings = Map<String, String>.from(jsonDecode(json) as Map);
  }
}
