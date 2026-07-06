import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';
import 'package:app_flutter/core/app_config.dart';

/// The set of imagery tile providers whose URL patterns are known.
///
/// Each value has a corresponding template URL constructed by
/// [TileFetcher.urlFor].
enum ImageryProvider {
  /// OpenStreetMap standard tiles (raster PNG).
  openStreetMap,

  /// ArcGIS World Imagery satellite tiles (raster).
  arcGisSatellite,

  /// CartoDB dark-themed basemap tiles.
  cartoDark,

  /// CartoDB light-themed basemap tiles.
  cartoLight,
}

/// An in-memory LRU cache for raw tile bytes with a fixed maximum capacity.
///
/// Eviction follows least-recently-used semantics: whenever a full cache
/// receives a new insertion the entry that has not been accessed for the
/// longest time is removed first.
class TileCache {
  final int _maxSize;
  final LinkedHashMap<String, Uint8List> _map = LinkedHashMap<String, Uint8List>();

  /// Creates a cache that holds at most [maxSize] entries.
  ///
  /// The default maximum is 256 entries — one PNG tile per entry.
  TileCache({int maxSize = 256}) : _maxSize = maxSize;

  /// Returns the byte buffer for [key], or `null` if not cached.
  ///
  /// Access moves [key] to the most-recently-used position so it is the last
  /// candidate for eviction.
  Uint8List? get(String key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
    }
    return value;
  }

  /// Inserts [value] under [key], evicting the LRU entry first if the cache
  /// is already at capacity.
  void put(String key, Uint8List value) {
    if (_map.length >= _maxSize) {
      _map.remove(_map.keys.first);
    }
    _map[key] = value;
  }

  /// Removes every cached entry.
  void clear() {
    _map.clear();
  }

  /// The current number of cached entries.
  int get length => _map.length;

  /// The maximum number of entries the cache can hold.
  int get maxSize => _maxSize;
}

/// An HTTP-based tile fetcher that respects the compile-time
/// [AppConfig.mapImageryEnabled] flag and caches results locally.
///
/// Each fetch respects a short connection timeout. Tile bytes are held in a
/// bounded LRU [TileCache] so repeated requests for the same tile avoid
/// network round-trips.
///
/// Callers can permanently disable the fetcher at runtime with [disable];
/// once disabled every subsequent [fetchTile] returns `null` immediately
/// without touching the network.
class TileFetcher {
  bool _enabled = AppConfig.mapImageryEnabled;

  final HttpClient _client = HttpClient()
    ..userAgent = 'PlatformConsole/1.0'
    ..connectionTimeout = const Duration(seconds: 5);

  final TileCache _cache = TileCache();

  /// Whether the fetcher is permitted to make outbound HTTP requests.
  bool isEnabled() => _enabled;

  /// Permanently disables the fetcher for the remainder of the process
  /// lifetime. After this call [isEnabled] returns `false` and [fetchTile]
  /// always returns `null`.
  void disable() {
    _enabled = false;
  }

  /// Empties the internal tile cache. Useful when switching providers so
  /// stale imagery is not displayed.
  void clearCache() {
    _cache.clear();
  }

  /// The number of entries currently held in the tile cache.
  int get cacheLength => _cache.length;

  /// Builds the HTTPS URL for a tile at the given [provider], zoom level
  /// [z], and tile coordinates ([x], [y]).
  ///
  /// This method is public so that integration tests can verify URL
  /// construction without making actual network calls.
  static String urlFor(ImageryProvider provider, int z, int x, int y) {
    switch (provider) {
      case ImageryProvider.openStreetMap:
        return 'https://tile.openstreetmap.org/$z/$x/$y.png';
      case ImageryProvider.arcGisSatellite:
        return 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/$z/$y/$x';
      case ImageryProvider.cartoDark:
        return 'https://basemaps.cartocdn.com/dark_all/$z/$x/$y.png';
      case ImageryProvider.cartoLight:
        return 'https://basemaps.cartocdn.com/light_all/$z/$x/$y.png';
    }
  }

  String _urlFor(ImageryProvider provider, int z, int x, int y) {
    return urlFor(provider, z, x, y);
  }

  /// Fetches the tile image bytes for [provider] at zoom [z] and tile
  /// coordinates ([x], [y]).
  ///
  /// Returns `null` immediately when [isEnabled] is `false` or when any
  /// network error occurs (timeout, non-200 status, DNS failure, etc.).
  ///
  /// On success the raw PNG bytes are returned and also stored in the
  /// internal LRU cache. Subsequent calls for the same
  /// (provider, z, x, y) tuple will be served from cache.
  Future<Uint8List?> fetchTile(
      ImageryProvider provider, int z, int x, int y) async {
    if (!_enabled) return null;

    final key = '$z/$x/$y/${provider.name}';
    final cached = _cache.get(key);
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(_urlFor(provider, z, x, y));
      final request = await _client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytes = await response
            .fold<List<int>>(<int>[], (prev, chunk) => prev..addAll(chunk));
        final data = Uint8List.fromList(bytes);
        _cache.put(key, data);
        return data;
      }
    } catch (_) {
      // Swallow — return null on any failure.
    }
    return null;
  }
}
