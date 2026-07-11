# Implementation Plan - Horizon Culling, Generic Coordinates, and Adversarial Fixes

This plan details the changes to implement generic segment-intersection culling math, resolve coordinate projection defects, fix altitude/elevation alignments, and update the test suite to use domain-independent coordinates and a hermetic loopback test server.

## Target Files & Proposed Changes

### 1. `app_flutter/lib/domain/cesium_3d/tile_fetcher.dart`
- Add a static property `static String? urlOverride` to allow redirecting tile HTTP queries during testing.
- Modify `fetchTile` to check `urlOverride` and, if present, construct request URIs pointing to `urlOverride/${provider.name}/$z/$x/$y.png` instead of the production HTTPS addresses.

### 2. `app_flutter/test/topology/scene_3d_viewport_golden_test.dart`
- Set up a local loopback HTTP server (`HttpServer.bind('localhost', 0)`) in the test setup.
- Configure `TileFetcher.urlOverride` to point to the local HTTP server.
- The local server will load and serve real PNG assets from the local filesystem (ensuring 100% real network I/O and image decoding without using mock classes).
- Add **Test Case 1**: Verifies that when in 3D mode, the layout stack is correct (no 2D map controller leakage).
- Add **Test Case 2 (Warped Horizon Snapping)**: Assert that tile vertices crossing the horizon are not snapped to the flat horizon circle limb, and retain their exaggerated geocentric heights.
- Add **Test Case 3 (Subsurface Occlusion Culling)**: Assert that a subsurface point ($height < R$) is culled correctly when the camera is outside the Earth.
- Add **Test Case 4 (Node-to-Overlay Alignment)**: Assert that `getProjectedPosition` returns the exact screen offsets matching the painter's projection height (under active vertical exaggeration and node altitudes).
- Add **Test Case 5 (Airborne Node Exaggeration)**: Assert that airborne coordinates (meteors, clouds, UOFs) project at absolute heights and are not exaggerated by terrain.

### 3. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- **Correct segment-intersection horizon culling math**:
  - Implement segment-intersection check using the formula.
  - Compute `px, py, pz` using a clamped height of at least `R = 6378137.0` to prevent shallow subsurface coordinates from being incorrectly culled.
- **Warped Horizon Snapping Fix**:
  - Modify `project` to accept a `clampToHorizon` flag (boolean, default `true`).
  - For node projections and the lambda passed to `tileRenderer.renderTiles`, pass `clampToHorizon = false`, projecting them to their natural geocentric coordinate positions.
  - Set the `depthVal` to `-2.0` when a point is culled and `clampToHorizon` is active or generally when culled, so that they can be identified as culled (depth values < -1.5) by the tile renderer.
- **Subsurface Occlusion Culling Fix**:
  - In the culling logic of `project`, check if the camera is outside the Earth ($cRad > R$) and the coordinate is subsurface ($height < R$). If so, force `isCulled = true` to prevent underground points on the camera-facing side from rendering.
- **Airborne/Space Node Classification Fix**:
  - Update classification rules for nodes: Categorize `AIR`, `METEOR`, `CLOUD`, `UOF`, `UFO`, `SPACE`, `SATELLITE` as `'space'` (absolute height, no vertical exaggeration).
- **Elevation Cache Poisoning Fix**:
  - Update the key format for `_nodeElevationCache` to include: latitude, longitude, vertical exaggeration, and astronomical body (e.g. `'$id-${latDeg.toStringAsFixed(6)}-${lngDeg.toStringAsFixed(6)}-$astronomicalBody-$elevationActive'`).
- **Overlay Alignment Fix**:
  - Update `getProjectedPosition` to accept `altitude` and `nodeType` (defaulting to `0.0` and `''` respectively), compute final height matching the painter's formulas, and call `project` with `clampToHorizon: false`.

### 4. `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart`
- In `renderTiles`, update the triangle filtering logic to discard triangles where all vertices are culled (depth values < -1.5). Triangles crossing the horizon (some visible, some culled) should still be rendered without warping to the limb.

### 5. `app_flutter/test/topology/goldens/stars_and_sphere.png`
- **Regenerate Golden File**:
  - Update the golden image to match the corrected horizon culling behavior.

## Verification Plan

1. **Test Failure Verification**:
   - Run the updated test suite using `flutter test test/topology/scene_3d_viewport_golden_test.dart` before applying the fixes to verify that the test fails showing correct failure detection.
2. **Test Success Verification**:
   - Run `flutter test` and confirm all 214 tests pass successfully.
   - Update the goldens on this platform using `flutter test --update-goldens test/topology/scene_3d_viewport_golden_test.dart`.
3. **Commit & Push**:
   - Commit all changes and verify `git diff origin/main` is empty.
