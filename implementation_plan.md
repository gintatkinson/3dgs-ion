# Implementation Plan - Snapping, Generic Classification, and Culling Corrections

This plan details the changes to implement the generic height reference parser, correct the horizon snapping math to use dynamic geocentric height instead of a hardcoded sea-level radius, update the tile culling logic, and expand testing.

## Target Files & Proposed Changes

### 1. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- **Generic Classification**:
  - In `Scene3DViewportPainter.paint` and `getProjectedPosition`, remove all hardcoded domain type checks (`AIR`, `METEOR`, `CLOUD`, etc.).
  - Implement the generic height reference parser:
    ```dart
    final String heightRef = (node.rawProperties['heightReference'] ?? 
                              node.rawProperties['height_reference'] ?? '').toString().toUpperCase();
    final String type;
    if (heightRef == 'RELATIVE_TO_GROUND' || heightRef == 'CLAMP_TO_GROUND') {
      type = 'ground';
    } else if (heightRef == 'ABSOLUTE') {
      type = 'space';
    } else {
      // Geometric fallback
      type = (alt < 50000.0) ? 'ground' : 'space';
    }
    ```
- **Horizon Snapping Dynamic Height**:
  - In `project`, update the horizon snapping logic when `clampToHorizon` is true. Substitute the parameter `height` (geocentric radius of the point) instead of the hardcoded sea-level radius `R = 6378137.0`:
    ```dart
    final double h2 = height * height;
    final double r2_over_d2 = h2 / d2;
    final double parX = r2_over_d2 * cx;
    final double parY = r2_over_d2 * cy;
    final double parZ = r2_over_d2 * cz;
    ...
    final double rHorizon = height * math.sqrt(1.0 - h2 / d2);
    final double scale = rHorizon / perpLen;
    px = parX + perpX * scale;
    py = parY + perpY * scale;
    pz = parZ + perpZ * scale;
    ```
- **Revert `clampToHorizon` Overrides**:
  - Ensure all projections (including the projection lambdas passed to tile rendering and node projections) use default `clampToHorizon = true`. Remove any `clampToHorizon: false` overrides.

### 2. `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart`
- **Tile Triangle Discarding**:
  - Ensure the tile triangles are discarded if all three vertices are culled (depth < -0.5).
  - Update `renderTiles` and `calculateIndicesForTesting` accordingly.

### 3. `app_flutter/test/topology/scene_3d_viewport_golden_test.dart`
- **Unit Tests**:
  - Add a unit test verifying that for a culled point at height $H$, its projected snapped ECEF coordinates lie precisely on the exaggerated horizon plane at geocentric distance $H \cdot \sqrt{1.0 - H^2/d_2}$.
  - Add a test verifying that nodes with `alt >= 50000.0` default to `'space'` (no vertical exaggeration) while those `< 50000.0` default to `'ground'` (relative to terrain).

## Verification Plan
1. Run `flutter test` and verify that all tests pass.
