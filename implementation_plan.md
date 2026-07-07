# Implementation Plan - Scenario 5 Performance Fixes & Cache Budget Safety

## 1. Objectives
Implement the performance fixes to clamp the tile search radius for Tiers 2 and 3, increase the cache capacity to 128, and update the test assertions to verify that high-resolution tiles are capped at a search radius of 2. Verify that all 5 tests in the suite pass successfully.

## 2. File Modifications

### `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart`
- In image cache eviction logic:
  - Increase the cache capacity limit from `64` to `128`.
- In `_visibleTiles`:
  - Dynamically compute `radius` for Tier 3 and clamp the search radius to `1` to `2`:
    `int radius = (thetaDeg / tileWidth).ceil().clamp(1, 2);`
  - Dynamically compute `midRadius` for Tier 2, renaming `tileWidth` to `midTileWidth` and `radius` to `midRadius`, and clamp the search radius to `1` to `2`:
    `int midRadius = (thetaDeg / midTileWidth).ceil().clamp(1, 2);`
- Ensure soft culling logic in `renderTiles` and `calculateIndicesForTesting` remains soft (logical OR: `zs[i0] >= 0.0 || zs[i1] >= 0.0 || zs[i2] >= 0.0`).
- Ensure polar cap latitudes >= 85.0511 are clamped to 90.0, and <= -85.0511 to -90.0.

### `app_flutter/test/cesium_3d/globe_tile_renderer_test.dart`
- Modify Test 1 (`horizon search radius verification at high altitude`) to assert that the high-resolution (zoom 8) search radius is clamped to a safe maximum of `2`:
  - Replace the existing `hasEdgeTile` check with:
    `final hasEdgeTile = zoom8Tiles.any((t) => (t.x - centerTile.x).abs() > 2);`
    `expect(hasEdgeTile, isFalse, reason: 'High-res search radius must be capped at 2 to fit cache budget');`
- Modify `CountingTileFetcher` class to use default `cacheCapacity = 128`.
- Modify Test 5 to instantiate `CountingTileFetcher` with `cacheCapacity: 128`.

## 3. Success / Verification Criteria
- Run `flutter test test/cesium_3d/globe_tile_renderer_test.dart` in `app_flutter`.
- Verify that all 5 tests compile and pass successfully.
- Verify `git diff` is clean on remote tracking branch before declaring done.
