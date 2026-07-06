double getDefaultRatio(Map<String, dynamic> layoutConfig, String key, double fallback) {
  try {
    final parts = key.split('.');
    dynamic current = layoutConfig;
    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return fallback;
      }
    }
    if (current is num) return current.toDouble();
  } catch (_) {}
  return fallback;
}

Map<String, String> resolveCoordinateMapping(Map<String, dynamic> layoutConfig) {
  try {
    if (layoutConfig['layout_mappings'] != null &&
        layoutConfig['layout_mappings']['coordinate_mapping'] != null) {
      final Map<String, dynamic> rawMap =
          layoutConfig['layout_mappings']['coordinate_mapping'] as Map<String, dynamic>;
      return rawMap.map((key, value) => MapEntry(key, value.toString()));
    }
  } catch (_) {}
  return const <String, String>{
    'x': 'position/dim_0',
    'y': 'position/dim_1',
    'z': 'position/dim_2',
    't': 'position/time_index',
    'trajectory': 'position/vector',
  };
}

Map<String, String> resolveLabelsMapping(Map<String, dynamic> layoutConfig) {
  try {
    if (layoutConfig['layout_mappings'] != null &&
        layoutConfig['layout_mappings']['labels'] != null) {
      final Map<String, dynamic> rawLabels =
          layoutConfig['layout_mappings']['labels'] as Map<String, dynamic>;
      return rawLabels.map((key, value) => MapEntry(key, value.toString()));
    }
  } catch (_) {}
  return const <String, String>{};
}
