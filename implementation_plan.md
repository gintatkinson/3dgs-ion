# Implementation Plan - 3D ECEF Horizon Clamping & Elliptical Rendering

## 1. Objectives
- Implement 3D ECEF horizon clamping and elliptical ocean/atmosphere drawing in `app_flutter/lib/features/topology/scene_3d_viewport.dart`.
- Clean up outdated 2D viewport earth center screen clamping.
- Validate via targeted tests.

## 2. File Modifications

### `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- In `project` (around line 1097):
  - Replace ECEF coordinate calculation and camera position calculations (lines 1106-1135) to perform culling and clamping directly in 3D ECEF space.
  - Clean up the end of the `project` method by removing the previous 2D clamping `if (isCulled)` block, setting `depthVal = isCulled ? -1.0 : depth;`.
- Add `_getHorizonPath` helper method inside `Scene3DViewportPainter` class.
- Update `paint` method:
  - Move calculation of `rotationAngle` and `tilt` to the beginning of the method.
  - Define `oceanPath` and `_getScaledPath` helper.
  - Replace all `canvas.drawCircle(projectedCenter, ...)` calls for Earth/planetary sphere and corona/atmosphere glows with `canvas.drawPath` of the appropriate paths/scaled paths.
  - Remove duplicate `rotationAngle`/`tilt` declarations.

### `app_flutter/test/topology/scene_3d_viewport_test.dart`
- Update the tilted camera horizon clamping test expectation to compute the correct elliptical projected radius (scaled by 1 / cos(alpha) where alpha is 45 degrees).

## 3. Success / Verification Criteria
- Run target tests:
  `flutter test test/cesium_3d/globe_tile_renderer_test.dart test/topology/scene_3d_viewport_test.dart test/layout_test.dart`
- Verify everything runs and returns exit code 0.
- Verify `git diff origin/main` is completely empty after commit and push to remote.
