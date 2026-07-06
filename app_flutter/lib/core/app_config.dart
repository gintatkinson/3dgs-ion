/// Central holder for application-wide constants.
///
/// Every UI layer reads the app and window title from here so that a single
/// change propagates everywhere. Alternative: [StringResources] for
/// user-facing strings that need runtime override.
///
/// No file should hardcode its own copy of the application title.
class AppConfig {
  AppConfig._();

  /// The human-readable application title shown in window chrome and
  /// branding surfaces.
  static const String title = 'Platform Console';

  /// The title used for platform window decoration (e.g. macOS title bar).
  static const String windowTitle = 'Platform Console';

  /// Whether HTTP map-imagery tile fetching is permitted at runtime.
  ///
  /// Disable with the compile-time flag
  /// `--dart-define=MAP_IMAGERY_ENABLED=false`. When `false`, tile fetchers
  /// treat themselves as disabled and never make outbound requests.
  static const bool mapImageryEnabled =
      bool.fromEnvironment('MAP_IMAGERY_ENABLED', defaultValue: true);
}
