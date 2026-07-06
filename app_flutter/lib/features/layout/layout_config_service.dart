var _coordinateMappingCache = Expando<Map<String, String>>();
var _labelsMappingCache = Expando<Map<String, String>>();

void clearLayoutConfigCaches() {
  _coordinateMappingCache = Expando<Map<String, String>>();
  _labelsMappingCache = Expando<Map<String, String>>();
  _defaultRatioMemo.clear();
}

final _defaultRatioMemo = <({int configHash, String key}), double>{};

double getDefaultRatio(Map<String, dynamic> layoutConfig, String key, double fallback) {
  final memoKey = (configHash: identityHashCode(layoutConfig), key: key);
  final cached = _defaultRatioMemo[memoKey];
  if (cached != null) return cached;
  try {
    final parts = key.split('.');
    dynamic current = layoutConfig;
    for (final part in parts) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        _defaultRatioMemo[memoKey] = fallback;
        return fallback;
      }
    }
    if (current is num) {
      final result = current.toDouble();
      _defaultRatioMemo[memoKey] = result;
      return result;
    }
  } catch (_) {}
  _defaultRatioMemo[memoKey] = fallback;
  return fallback;
}

Map<String, String> resolveCoordinateMapping(Map<String, dynamic> layoutConfig) {
  final cached = _coordinateMappingCache[layoutConfig];
  if (cached != null) return cached;
  try {
    if (layoutConfig['layout_mappings'] != null &&
        layoutConfig['layout_mappings']['coordinate_mapping'] != null) {
      final Map<String, dynamic> rawMap =
          layoutConfig['layout_mappings']['coordinate_mapping'] as Map<String, dynamic>;
      final result = rawMap.map((key, value) => MapEntry(key, value.toString()));
      _coordinateMappingCache[layoutConfig] = result;
      return result;
    }
  } catch (_) {}
  final fallback = const <String, String>{
    'x': 'position/dim_0',
    'y': 'position/dim_1',
    'z': 'position/dim_2',
    't': 'position/time_index',
    'trajectory': 'position/vector',
  };
  _coordinateMappingCache[layoutConfig] = fallback;
  return fallback;
}

Map<String, String> resolveLabelsMapping(Map<String, dynamic> layoutConfig) {
  final cached = _labelsMappingCache[layoutConfig];
  if (cached != null) return cached;
  try {
    if (layoutConfig['layout_mappings'] != null &&
        layoutConfig['layout_mappings']['labels'] != null) {
      final Map<String, dynamic> rawLabels =
          layoutConfig['layout_mappings']['labels'] as Map<String, dynamic>;
      final result = rawLabels.map((key, value) => MapEntry(key, value.toString()));
      _labelsMappingCache[layoutConfig] = result;
      return result;
    }
  } catch (_) {}
  const fallback = <String, String>{};
  _labelsMappingCache[layoutConfig] = fallback;
  return fallback;
}
