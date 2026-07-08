# Implementation Plan - Camera-Terrain Collision & Clamping

## 1. Objectives
- Implement camera-terrain collision detection and clamping algorithms to prevent the camera from going below the terrain.
- Create a test file `app_flutter/test/cesium_3d/camera_collision_test.dart` to verify clamping behavior over ocean (flat terrain), Mount Fuji (amplified terrain), and when panning towards rising terrain.
- Update `CameraController` to support terrain height clamping for `updateCamera`, `zoom`, `zoomInteractive`, and `pan`.
- Share the elevation calculation in `Scene3DViewport` as a static method and set up `elevationProvider` inside `Scene3DViewportPainter`'s camera controller initialization.
- Adjust distance computations in `Scene3DViewportPainter` to include dynamic terrain elevation.

## 2. File Modifications

### `app_flutter/test/cesium_3d/camera_collision_test.dart` (Create)
- Create a new unit test suite as specified in the instructions, testing the following cases:
  - Nadir Zoom-in Clamps at Ellipsoid Base Over Ocean (Flat Terrain).
  - Nadir Zoom-in Clamps Correctly Above Amplified Mount Fuji.
  - Panning Toward Rising Terrain Automatically Lifts Camera.

### `app_flutter/lib/domain/cesium_3d/camera_controller.dart` (Modify)
- Add `double Function(double lat, double lng)? elevationProvider` field.
- Add helper methods `_getTerrainHeight` and `_clampAltitudeToTerrain`.
- Update `updateCamera` to clamp target altitude.
- Update `zoom` to clamp target altitude AGL.
- Update `zoomInteractive` to clamp target altitude AGL.
- Update `pan` to clamp target altitude.

### `app_flutter/lib/features/topology/scene_3d_viewport.dart` (Modify)
- Make elevation calculation static as `getElevationStatic`.
- Update standard `getElevation` to call `getElevationStatic`.
- In `initState()` of `_Scene3DViewportState`, assign `elevationProvider` to the camera controller.
- Update `cRad` definitions in `_clickToCamera`, `project`, `_getHorizonPath`, and `paint` within `scene_3d_viewport.dart` to compensate for dynamic terrain elevation.

## 3. Success / Verification Criteria
- Run unit/widget tests to confirm:
  `flutter test test/cesium_3d/camera_collision_test.dart test/topology/scene_3d_viewport_test.dart test/cesium_3d/globe_tile_renderer_test.dart`
- Verify that `git diff origin/main` is clean after changes are successfully pushed.
