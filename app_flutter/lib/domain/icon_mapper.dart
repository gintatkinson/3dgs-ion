import 'package:flutter/material.dart';

/// Resolves Material icon name strings to [IconData] at runtime.
///
/// Allows the data source to specify icons by name (e.g. "dns", "bar_chart")
/// without the Flutter code knowing about specific icon choices at compile time.
/// New icon names can be added to this map as needed. Unknown names resolve
/// to a safe fallback icon — the UI never shows a blank or throws.
///
/// Use this whenever you need to display a type icon based on a string name
/// from the data source. For compile-time-known icons, prefer [Icons] directly.
class IconMapper {
  IconMapper._();

  static const Map<String, IconData> _icons = {
    'play_arrow': Icons.play_arrow,
    'bar_chart': Icons.bar_chart,
    'location_on': Icons.location_on,
    'dns': Icons.dns,
    'album': Icons.album,
    'link': Icons.link,
    'folder': Icons.folder,
    'folder_open': Icons.folder_open,
    'insert_drive_file': Icons.insert_drive_file,
    'developer_board': Icons.developer_board,
    'light_mode': Icons.light_mode,
    'dark_mode': Icons.dark_mode,
    'settings_brightness': Icons.settings_brightness,
    'settings': Icons.settings,
    'check': Icons.check,
    'text_fields': Icons.text_fields,
  };

  /// Resolve an icon name string to [IconData].
  ///
  /// Returns [Icons.insert_drive_file] as fallback if the name is unknown.
  /// An empty or null [name] also returns the fallback — it does not throw.
  /// The lookup is case-sensitive; "DNS" does not match "dns".
  static IconData resolve(String name) =>
      _icons[name] ?? Icons.insert_drive_file;
}
