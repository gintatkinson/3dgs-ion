# Implementation Plan - Correct Node Classification and Relative Altitude Projection

This plan details the changes to fix node classification and relative altitude rendering in the 3D topology scene, including a new visual test case.

## Target Files & Proposed Changes

### 1. `app_flutter/test/topology/scene_3d_viewport_golden_test.dart`
- **Add Visual Test 5**:
  Add `'Visual Test 5 - Correct Ground, Tower, and Satellite Altitude Projection'`.
  This test instantiates `Scene3DViewportPainter` with `elevationActive: true` and `verticalExaggeration: 10.0`, and passes three nodes:
  1. `Nagoya` (lat: 35.18, lng: 136.90, alt: 0.0, type: 'ground')
  2. `Nagoya-Tower` (lat: 35.18, lng: 136.90, alt: 100.0, type: 'ground')
  3. `Satellite` (lat: 0.0, lng: 0.0, alt: 1000000.0, type: 'space')
  
  The test uses a custom subclass of `Scene3DViewportPainter` that overrides `project` to capture the heights passed to the projection function during rendering, and uses a dummy `Canvas` subclass to capture the paint calls.
  It asserts:
  - Nagoya is classified as `ground` (asserted by verifying no underwater circles are drawn, and that it is instead drawn as a ground node via `drawPoints`).
  - Nagoya's geocentric height is exactly `6378137.0 + getElevation(35.18, 136.90) * 10.0`.
  - Nagoya-Tower's geocentric height is exactly `6378137.0 + getElevation(35.18, 136.90) * 10.0 + 100.0` (verifies tower altitude is not exaggerated).
  - Satellite's geocentric height is exactly `6378137.0 + 1000000.0` (verifies space altitude is not exaggerated).

### 2. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- **Fix 1: Node Classification**:
  Change line 1759:
  ```dart
  final bool isUnderwater = alt <= 10.0;
  ```
  to:
  ```dart
  final bool isUnderwater = nodeType == 'UNDERWATER' || (nodeType.isEmpty && alt < 0.0) || id.toLowerCase().contains('underwater');
  ```

- **Fix 2: Exaggerated Altitude**:
  Change line 1810:
  ```dart
  finalHeight = 6378137.0 + (terrainElev + alt) * verticalExaggeration;
  ```
  to:
  ```dart
  finalHeight = 6378137.0 + terrainElev * verticalExaggeration + alt;
  ```

## Verification Plan
1. Apply the test changes to `scene_3d_viewport_golden_test.dart`.
2. Run the test: `flutter test test/topology/scene_3d_viewport_golden_test.dart` to verify that the new Visual Test 5 fails on the buggy codebase (shows that it successfully automates the detection of the defects).
3. Apply the code fixes to `scene_3d_viewport.dart`.
4. Run the test suite to confirm that Visual Test 5 and all other tests pass successfully.
5. Commit and push the changes.
