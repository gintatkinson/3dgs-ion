# Implementation Plan - Configurable Vertical Exaggeration

## 1. Objectives
- Implement configurable vertical exaggeration in `app_flutter/lib/features/topology/scene_3d_viewport.dart`.
- Add `final double verticalExaggeration` to `Scene3DViewport`, defaulting to `1.0` in its constructor.
- Propagate `verticalExaggeration` to `Scene3DViewportPainter` field, parameter, constructor, and all instantiations (including fuzzer, renderer, benchmark, and viewport tests).
- Replace all occurrences of hardcoded `* 80.0` multiplier in `scene_3d_viewport.dart` with the dynamic `verticalExaggeration` factor.
- Verify changes by running all topology/cesium tests to ensure they compile and pass cleanly.

## 2. File Modifications

### `app_flutter/lib/features/topology/scene_3d_viewport.dart` (Modify)
- In class `Scene3DViewport`:
  - Add `final double verticalExaggeration;`
  - Update constructor to include `this.verticalExaggeration = 1.0`.
- In class `Scene3DViewportPainter`:
  - Add `final double verticalExaggeration;`
  - Update constructor to accept `required this.verticalExaggeration`.
- Instantiations of `Scene3DViewportPainter`:
  - In `getProjectedPosition`, pass `verticalExaggeration: widget.verticalExaggeration`.
  - In `_clickToCamera`, pass `verticalExaggeration: widget.verticalExaggeration`.
  - In `build`, pass `verticalExaggeration: widget.verticalExaggeration`.
- Hardcoded multiplier `* 80.0` replacements:
  - In `initState()` (line 140) -> replace `* 80.0` with `* widget.verticalExaggeration`.
  - In `_clickToCamera` (line 386) -> replace `* 80.0` with `* widget.verticalExaggeration`.
  - In `project()` (line 1151) -> replace `* 80.0` with `* verticalExaggeration`.
  - In `_getHorizonPath()` (line 1272) -> replace `* 80.0` with `* verticalExaggeration`.
  - In `paint()` (line 1375) -> replace `* 80.0` with `* verticalExaggeration`.
  - In `paint()` (line 1609) -> replace `ampElev = elev * 80.0;` with `ampElev = elev * verticalExaggeration;`.
  - In `paint()` (line 1766) -> replace `alt * 80.0` with `alt * verticalExaggeration`.
  - In `paint()` (line 1779) -> replace `terrainElev * 80.0` with `terrainElev * verticalExaggeration`.

### `app_flutter/test/cesium_3d/adversarial_fuzzer_test.dart` (Modify)
- Update `Scene3DViewportPainter` instantiation (line 99) to pass `verticalExaggeration: 1.0`.

### `app_flutter/test/cesium_3d/globe_tile_renderer_test.dart` (Modify)
- Update instantiations of `Scene3DViewportPainter` (lines 252, 386) to pass `verticalExaggeration: 1.0`.

### `app_flutter/test/features/topology/globe_rendering_benchmark_test.dart` (Modify)
- Update instantiations of `Scene3DViewportPainter` (lines 80, 113) to pass `verticalExaggeration: 1.0`.

### `app_flutter/test/topology/scene_3d_viewport_test.dart` (Modify)
- Update all instantiations of `Scene3DViewportPainter` (lines 21, 74, 114, 181, 218, 231) to pass `verticalExaggeration: 1.0`.

## 3. Success / Verification Criteria
- Run `flutter test test/topology/scene_3d_viewport_test.dart` and confirm all tests pass.
- Run `flutter test test/cesium_3d/globe_tile_renderer_test.dart` and confirm all tests pass.
- Run `flutter test test/cesium_3d/adversarial_fuzzer_test.dart` and confirm all tests pass.
- Run `flutter test test/features/topology/globe_rendering_benchmark_test.dart` and confirm all tests pass.
- Ensure no compilation or lint errors.
