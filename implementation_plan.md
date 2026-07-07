# Implementation Plan - Feature 02: 3D Terrain Elevation and Node Altitude Modeling

## 1. Objectives
- Implement 3D terrain elevation calculations and apply node altitude offsets dynamically inside `Scene3DViewportPainter` in `app_flutter/lib/features/topology/scene_3d_viewport.dart`.
- Apply terrain elevation amplification for map tile projection, ground node positioning, and vertical space node drop lines.
- Add BDD-style unit tests verifying Mount Fuji peak and Alps range elevation queries, and confirming state behavior when elevation is disabled.

## 2. File Modifications

### `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- In `Scene3DViewportPainter` class:
  - Add `double getElevation(double latDeg, double lngDeg)` method that calculates peak elevation for Mount Fuji (when distance is < 0.25) and noise-based elevation for the Alps mountain range in Central Japan, returning 0.0 when `elevationActive` is false or when outside these geographic ranges.
- In `paint` method:
  - Update `renderTiles` project function parameter callback to retrieve elevation, apply `80.0` amplification factor, and project utilizing `6378137.0 + ampElev`.
  - Update ground node positioning to lookup terrain elevation, compute height with amplification and `alt * 2000.0` scaling, and project using the updated height.
  - Update vertical satellite drop lines to fetch terrain elevation at the satellite's position, calculate surface height with amplification, and project this surface point.

### `app_flutter/test/topology/scene_3d_viewport_test.dart`
- Add a new group `Feature 02: 3D Terrain Elevation and Node Altitude` with unit tests checking elevation returns at Mount Fuji and the Alps when active vs inactive, and when outside geographic ranges.

## 3. Success / Verification Criteria
- Run target tests:
  `flutter test test/cesium_3d/globe_tile_renderer_test.dart test/topology/scene_3d_viewport_test.dart`
- Verify everything runs and returns exit code 0.
- Verify `git diff origin/main` is completely empty after commit and push to remote.
