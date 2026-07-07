# Implementation Plan - Scenario 4 Automated Tests & Fixes

## 1. Objectives
Expose private testing wrappers in `GlobeTileRenderer` and add Scenario 4 BDD-style unit tests to verify visible tile grid and soft culling logic. Implement Scenario 4 fixes for soft culling, dynamic visible tile range, and polar cap clamping, verifying that all tests pass.

## 2. File Modifications
### `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart`
- Add `import 'package:meta/meta.dart';`.
- Add `@visibleForTesting` wrapper `visibleTilesForTesting(VirtualCamera camera, ui.Size viewportSize)` delegating to `_visibleTiles(camera, viewportSize)`.
- Add `@visibleForTesting` wrapper `latLngToTileForTesting(double lat, double lng, int zoom)` delegating to `_latLngToTile(lat, lng, zoom)`.
- Add `@visibleForTesting` static method `calculateIndicesForTesting(List<double> zs)` running the single subdivision tile loop.
- **Fix 1: Soft Culling**:
  - In `renderTiles` and `calculateIndicesForTesting`, change the triangle culling checks from `&&` to `||` so a triangle is rendered if at least one of its three vertices is visible (z >= 0.0):
    `if (zs[i0] >= 0.0 || zs[i1] >= 0.0 || zs[i2] >= 0.0)`
    `if (zs[i1] >= 0.0 || zs[i3] >= 0.0 || zs[i2] >= 0.0)`
- **Fix 2: Dynamic Visible Tile Range**:
  - In `_visibleTiles`, calculate the horizon angle theta:
    `double theta = acos(R / (R + h))` with R = 6378137.0 and h = camera.altitude.
  - In Tier 3 (zoom) and Tier 2 (midZoom) loops, compute the search radius dynamically:
    `double tileWidth = 360.0 / math.pow(2, zoom);`
    `double thetaDeg = theta * 180.0 / math.pi;`
    `int radius = (thetaDeg / tileWidth).ceil().clamp(2, 16);`
    Use `radius` in the loop boundaries instead of hardcoded 2.
- **Fix 3: Polar Cap Clamping**:
  - In `renderTiles`, when projecting coordinates, clamp latitudes >= 85.0511 to 90.0 and <= -85.0511 to -90.0. Pass the clamped `projLat` to `projectFn`.

## 3. File Creations
### `app_flutter/test/cesium_3d/globe_tile_renderer_test.dart`
- Set up test suite for `GlobeTileRenderer`.
- **Test 1 (visible tile grid)**: Set up a `VirtualCamera` at altitude 500,000m. Invoke `visibleTilesForTesting`. Calculate expected horizon search offset (~16 tiles). Verify that tiles at the edge (dx >= 15) are returned. (Now passes).
- **Test 2 (soft culling)**: Set up 25 vertex depth values where some cross the horizon (visible z >= 0, hidden z < 0). Invoke `calculateIndicesForTesting`. Verify that triangles containing at least one visible vertex are not culled and their indices are populated. (Now passes).
- **Test 3 (polar cap clamping)**: Verify that when coordinates are rendered, latitudes at or near poles clamp to 90.0 and -90.0 and pass correctly to the projection function. (Now passes).

## 4. Success / Verification Criteria
- Run `flutter test test/cesium_3d/globe_tile_renderer_test.dart` (or equivalent package-based test command).
- Verify that all tests pass.
- Ensure the project builds successfully with no compiler/static analysis errors in the test file.
- Push changes to the tracking branch and verify clean git status vs origin.
