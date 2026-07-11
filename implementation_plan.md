# Implementation Plan - Optical Axis Projection Fix and Visual Regression Tests

This plan details the changes to create a visual regression test suite and fix the optical axis projection tilt/pitch rotation signs.

## Target Files & Proposed Changes

### 1. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- In `project` method (around line 1268-1269):
  Replace:
  ```dart
  final double y_cam = y1 * cosA - z1 * sinA;
  final double z_cam = y1 * sinA + z1 * cosA;
  ```
  with:
  ```dart
  final double y_cam = y1 * cosA + z1 * sinA;
  final double z_cam = -y1 * sinA + z1 * cosA;
  ```
- In `_getHorizonPath` method (around line 1380-1381):
  Replace:
  ```dart
  final double y_cam = y1 * cosA - z1 * sinA;
  final double z_cam = y1 * sinA + z1 * cosA;
  ```
  with:
  ```dart
  final double y_cam = y1 * cosA + z1 * sinA;
  final double z_cam = -y1 * sinA + z1 * cosA;
  ```

### 2. `app_flutter/test/topology/scene_3d_viewport_golden_test.dart`
- Create this new visual regression test file with three test cases:
  1. **Visual Test 1 - Stars and Sphere View**
     - Camera latitude=0.0, longitude=0.0, altitude=20000000.0, heading=0, pitch=-90, roll=0.
     - Empty TopologyData nodes.
     - Settle/pump, assert match to `goldens/stars_and_sphere.png`.
  2. **Visual Test 2 - Exaggerated Node Elevation Alignment**
     - Camera latitude=35.3606, longitude=138.7274, altitude=1000.0, heading=0, pitch=-45, roll=0.
     - Node at Mt. Fuji (138.7274, 35.3606) with alt=0.0.
     - Settle/pump, assert match to `goldens/exaggerated_fuji_node.png`.
  3. **Visual Test 3 - Forward/Backward Projection Inversion Culling**
     - Camera latitude=35.441924, longitude=138.848037, altitude=90635.83, heading=56.65, pitch=-19.79, roll=0.
     - Node 1: Nagoya-OPT-Core (136.90, 35.18, 0.0) - Southwest (behind camera, should be culled).
     - Node 2: Tokyo-OPT-Core (140.00, 36.00, 0.0) - Northeast (in front of camera, should be rendered).
     - First perform non-visual coordinate projection checks directly on the `Scene3DViewportPainter` using the buggy values to confirm the inversion bug (Nagoya projected, Tokyo culled).
     - Assert visual identity matching `goldens/correct_view_culling.png`.

### 3. Golden Images in `app_flutter/test/topology/goldens/`
- `stars_and_sphere.png`
- `exaggerated_fuji_node.png`
- `correct_view_culling.png`

## Optimization Changes

### 1. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- In `Scene3DViewportPainter` class:
  - Add a static cache map for node elevations:
    `static final Map<String, double> _nodeElevationCache = {};`
  - In `paint` method:
    - Inside the node project loop (around lines 1812 and 1825), replace:
      ```dart
      final double terrainElev = getElevation(latDeg, currentLng * 180.0 / math.pi);
      ```
      with:
      ```dart
      final String cacheKey = '$id-$verticalExaggeration-$elevationActive';
      final double terrainElev = _nodeElevationCache.putIfAbsent(cacheKey, () => getElevation(latDeg, lngDeg));
      ```

## Verification Plan
1. Run the test suite on the buggy code to confirm the non-visual check fails:
   `flutter test test/topology/scene_3d_viewport_golden_test.dart`
2. Apply the mathematical fix in `scene_3d_viewport.dart`.
3. Generate the corrected golden images:
   `flutter test --update-goldens test/topology/scene_3d_viewport_golden_test.dart`
4. Run the node elevation optimization benchmark to ensure performance matches instructions (< 22ms average frame render time):
   `flutter test test/features/topology/globe_rendering_benchmark_test.dart`
5. Run the entire test suite to ensure all unit and visual tests pass:
   `flutter test`
6. Verify `git diff` to make sure changes are clean and correct.
7. Commit changes and push to origin tracking branch.

