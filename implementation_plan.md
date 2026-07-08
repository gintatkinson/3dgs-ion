# Implementation Plan - Near-Plane Depth Clamping

## 1. Objectives
- Implement near-plane depth clamping in `app_flutter/lib/features/topology/scene_3d_viewport.dart` to prevent division by zero or extreme scaling values for close coordinates (clamping depth to a minimum of 10000.0).

## 2. File Modifications

### `app_flutter/lib/features/topology/scene_3d_viewport.dart`

- In the `project` method (around line 1223):
  - Replace:
    ```dart
    final double pScale = depth <= 0.0 ? 1.0 : F / depth;
    ```
    with:
    ```dart
    final double safeDepth = depth <= 10000.0 ? 10000.0 : depth;
    final double pScale = F / safeDepth;
    ```

- In the `_getHorizonPath` method (around line 1325):
  - Replace:
    ```dart
    final double pScale = depth <= 0.0 ? 1.0 : F / depth;
    ```
    with:
    ```dart
    final double safeDepth = depth <= 10000.0 ? 10000.0 : depth;
    final double pScale = F / safeDepth;
    ```

## 3. Success / Verification Criteria
- Run target tests in `app_flutter` to ensure everything passes:
  `flutter test test/cesium_3d/globe_tile_renderer_test.dart test/topology/scene_3d_viewport_test.dart test/features/topology/globe_rendering_benchmark_test.dart`
- Verify that tests pass.
- Stage, commit, and push the changes to remote tracking branch.
- Verify `git diff origin/main` (or the tracking branch) is empty before generating walkthrough and final report.
