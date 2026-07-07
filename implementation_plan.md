# Implementation Plan - Ground Node Height Scaling Correction & Globe Rendering Benchmark

## 1. Objectives
- Correct the ground and underwater node height scaling in `Scene3DViewportPainter` inside `app_flutter/lib/features/topology/scene_3d_viewport.dart`.
- Replace the existing double-amplification/summing logic for ground/underwater nodes with a clean WGS84 ellipsoid height scaling that uses `elevationActive`.
- Implement and run the performance benchmark in `app_flutter/test/features/topology/globe_rendering_benchmark_test.dart` to stress test 10k nodes and 50k links rendering loop and ensure average frame render time is under 16.6ms.

## 2. File Modifications

### `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- In `paint` method (around line 1729):
  - Replace the double-amplification/summing logic for ground and underwater nodes:
    ```dart
    // Project the node
    double finalHeight = orbitHeight;
    if (type == 'ground') {
      final double terrainElev = getElevation(latDeg, currentLng * 180.0 / math.pi);
      finalHeight = 6378137.0 + terrainElev * 80.0 + alt * 2000.0;
    } else if (type == 'underwater') {
      finalHeight = 6378137.0 + alt; // Keep underwater depth flat/as-is
    }
    ```
    with:
    ```dart
    // Project the node
    double finalHeight = orbitHeight;
    if (type == 'ground' || type == 'underwater') {
      if (elevationActive) {
        finalHeight = 6378137.0 + alt * 80.0;
      } else {
        finalHeight = 6378137.0 + alt;
      }
    }
    ```
- Optimize node and link rendering loops to use batched canvas draw calls (`canvas.drawPoints` with `PointMode.points`/`PointMode.lines`) rather than individual `canvas.drawCircle`/`canvas.drawLine` calls, reducing native bridge invocations from ~150,000 to under 10.
- Add optimized paint fields `_gsPointPaint`, `_gsGlowPointPaint`, and `_packetPointPaint`.

### `app_flutter/lib/domain/cesium_3d/globe_tile_renderer.dart`
- In `renderTiles` method (around line 323):
  - Replace:
    ```dart
    const int subdivisions = 4;
    ```
    with:
    ```dart
    final int subdivisions = (z == 0) ? 16 : ((z == 1) ? 12 : ((z == 2) ? 8 : 4));
    ```

### `app_flutter/test/features/topology/globe_rendering_benchmark_test.dart`
- Create a new file containing stress test of 10k nodes and 50k links rendering loop to benchmark performance.

## 3. Success / Verification Criteria
- Run target tests in `app_flutter`:
  `flutter test test/cesium_3d/globe_tile_renderer_test.dart test/topology/scene_3d_viewport_test.dart`
- Run the benchmark test:
  `flutter test test/features/topology/globe_rendering_benchmark_test.dart`
- Verify that tests pass.
- Stage, commit, and push the changes to remote tracking branch.
- Verify `git diff origin/main` (or the tracking branch) is empty before generating walkthrough and final report.
