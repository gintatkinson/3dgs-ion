# Implementation Plan - ECEF Coordinate Corrections

## 1. Objectives
- Implement ECEF coordinate corrections in `app_flutter/lib/features/topology/scene_3d_viewport.dart` and `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart`.
- Correct the ground/underwater node elevation logic in `Scene3DViewportPainter` to use `getElevation`.
- Adjust the Camera Stats HUD altitude display to show the relative altitude (subtracting Earth radius `6378137.0` and formatting).
- Correct camera absolute radius `cRad` calculations across `scene_3d_viewport.dart` to not add Earth radius/R since `camera.altitude` already holds absolute radial distance.
- Update `GlobeTileRenderer._visibleTiles` to compute relative altitude and use it for zoom selection and horizon angle calculations.
- Update test cases to align with the formatted HUD output and absolute camera altitude changes.
- Verify changes compile and pass tests.

## 2. File Modifications

### `app_flutter/lib/features/topology/scene_3d_viewport.dart` (Modify)
- **Mod 1: paint ground/underwater node calculation (Lines 1771-1777)**
  - Original:
    ```dart
      double finalHeight = orbitHeight;
      if (type == 'ground' || type == 'underwater') {
        if (elevationActive) {
          finalHeight = 6378137.0 + alt * verticalExaggeration;
        } else {
          finalHeight = 6378137.0 + alt;
        }
      }
    ```
  - Replacement:
    ```dart
      double finalHeight = orbitHeight;
      if (type == 'ground' || type == 'underwater') {
        if (elevationActive) {
          final double terrainElev = getElevation(latDeg, currentLng * 180.0 / math.pi);
          finalHeight = 6378137.0 + (terrainElev + alt) * verticalExaggeration;
        } else {
          finalHeight = 6378137.0 + alt;
        }
      }
    ```

- **Mod 2: Camera Stats HUD altitude display (Lines 624-631)**
  - Original:
    ```dart
                            Text(
                              'Altitude: ${_cameraController.current.altitude} meters',
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
    ```
  - Replacement:
    ```dart
                            Text(
                              'Altitude: ${(_cameraController.current.altitude - 6378137.0).toStringAsFixed(2)} meters',
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontFamily: 'monospace',
                                fontSize: 11,
                              ),
                            ),
    ```

- **Mod 3: `cRad` calculation at lines 391, 1159, 1280, 1383**
  - Line 391 Original:
    ```dart
        final double cRad = 6378137.0 + camera.altitude + camElevation;
    ```
  - Line 391 Replacement:
    ```dart
        final double cRad = camera.altitude + camElevation;
    ```
  - Line 1159 Original:
    ```dart
        final double cRad = R + camera.altitude + camElevation;
    ```
  - Line 1159 Replacement:
    ```dart
        final double cRad = camera.altitude + camElevation;
    ```
  - Line 1280 Original:
    ```dart
        final double cRad = R + camera.altitude + camElevation;
    ```
  - Line 1280 Replacement:
    ```dart
        final double cRad = camera.altitude + camElevation;
    ```
  - Line 1383 Original:
    ```dart
        final double cRad = 6378137.0 + camera.altitude + camElevation;
    ```
  - Line 1383 Replacement:
    ```dart
        final double cRad = camera.altitude + camElevation;
    ```

### `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart` (Modify)
- **Mod 1: `_visibleTiles` method zoom/horizon calculation (Lines 152-160)**
  - Original:
    ```dart
        final zoom = _zoomForAltitude(camera.altitude, viewportSize.width);
        final center = _latLngToTile(camera.latitude, camera.longitude, zoom);
        final List<TileCoord> tiles = [];

        // Horizon angle theta = acos(R / (R + h)) where R = 6378137.0
        final double R = 6378137.0;
        final double h = camera.altitude;
        final double theta = math.acos(R / (R + h));
    ```
  - Replacement:
    ```dart
        final double R = 6378137.0;
        final double relativeAlt = camera.altitude < R ? camera.altitude : camera.altitude - R;
        final zoom = _zoomForAltitude(relativeAlt, viewportSize.width);
        final center = _latLngToTile(camera.latitude, camera.longitude, zoom);
        final List<TileCoord> tiles = [];

        // Horizon angle theta = acos(R / (R + h)) where R = 6378137.0
        final double h = relativeAlt < 0.1 ? 0.1 : relativeAlt;
        final double theta = math.acos(R / (R + h));
    ```

### `app_flutter/test/topology/scene_3d_viewport_test.dart` (Modify)
- Document test updates for `scene_3d_viewport_test.dart`:
  - Set camera altitude at line 110 to `6378137.0 + 10000000.0` (absolute distance from Earth center).
  - Update `cRad` calculation at line 161 to use `camera.altitude` directly instead of adding `R`.

### `app_flutter/test/cesium_3d/scroll_zoom_test.dart` (Modify)
- Update HUD text search from `10000.0 meters` to `10000.00 meters` (due to new `toStringAsFixed(2)` formatting).

### `app_flutter/test/cesium_3d/double_click_fly_test.dart` (Modify)
- Update camera test setup to use absolute altitude (`6378137.0 + 100000.0`) and update assertions accordingly.

## 3. Success / Verification Criteria
- Run `flutter test test/topology/scene_3d_viewport_test.dart` and confirm all tests pass.
- Run `flutter test test/cesium_3d/globe_tile_renderer_test.dart` and confirm all tests pass.
- Run `flutter test test/cesium_3d/adversarial_fuzzer_test.dart` and confirm all tests pass.
- Run `flutter test test/features/topology/globe_rendering_benchmark_test.dart` and confirm all tests pass.
- Ensure no compilation or lint errors.
