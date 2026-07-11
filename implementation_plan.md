# Implementation Plan - Horizon Culling Segment-Intersection & Generic Coordinates

This plan details the changes to implement generic segment-intersection culling math and update the test suite to use domain-independent coordinates.

## Target Files & Proposed Changes

### 1. `app_flutter/test/topology/scene_3d_viewport_golden_test.dart`
- **Rename Nagoya and Satellite to generic terms**:
  - Rename `Nagoya` to `PointA` and `Nagoya-Tower` to `PointB` (or `PointA-Tower`).
  - Rename `Satellite` to `PointC` (representing a space point).
  - Rename helper variables such as `NagoyaNodeLatRad` -> `PointALatRad`, `NagoyaNodeLngRad` -> `PointALngRad`, `expectedNagoyaHeight` -> `expectedPointAHeight`, `expectedTowerHeight` -> `expectedPointBHeight`.
  - Rename keys in `capturedHeights` from `nagoya_group` to `point_a_group` and `satellite` to `point_c`.
  - Rename the description of Visual Test 5 from `'Visual Test 5 - Correct Ground, Tower, and Satellite Altitude Projection'` to `'Visual Test 5 - Correct Ground, Raised Point, and Space Point Altitude Projection'`.
- **Implement Test 5 directly validating the geocentric radii**:
  - Ground point height assert: `6378137.0 + terrainElev * verticalExaggeration`.
  - Raised point height assert: `6378137.0 + terrainElev * verticalExaggeration + 100.0`.
  - Space point height assert: `6378137.0 + 1000000.0`.
- **Ensure Visual Test 3 uses ECEF vectors**:
  - Assert culling results: forward target coordinate (100 km along forward vector) is projected, backward target coordinate (100 km behind camera) is culled.

### 2. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- **Correct segment-intersection horizon culling math**:
  - Implement segment-intersection check using the new formula:
    ```dart
    final double d2 = cRad * cRad;
    final double r2 = R * R;
    final double rx = px - cx;
    final double ry = py - cy;
    final double rz = pz - cz;
    final double dCP2 = rx * rx + ry * ry + rz * rz;
    final double dotPC = px * cx + py * cy + pz * cz;

    bool isCulled = false;
    if (dotPC < r2) {
      final double tMin = (d2 - dotPC) / dCP2;
      if (tMin >= 0.0 && tMin <= 1.0) {
        final double minDistanceSq = d2 - (d2 - dotPC) * (d2 - dotPC) / dCP2;
        if (minDistanceSq < r2) {
          isCulled = true;
        }
      }
    }
    ```
  - For culling checks, compute `px, py, pz` using a clamped height of at least `R = 6378137.0` (i.e. `final double cullHeight = math.max(height, R);`) to prevent shallow subsurface coordinates from being incorrectly culled.
  - Apply the same culling checks where applicable, preserving the projection of coordinates onto the horizon when culled.

### 3. `app_flutter/test/topology/goldens/stars_and_sphere.png`
- **Regenerate Golden File**:
  - Update the golden image to match the corrected horizon culling behavior for climate bands near the WGS84 horizon.

## Verification Plan

1. **Test Failure Verification**:
   - Run `flutter test test/topology/scene_3d_viewport_golden_test.dart` after updating the test file but BEFORE the code fix, and verify that the test fails showing correct failure detection.
2. **Test Success Verification**:
   - Update goldens on this platform using `flutter test --update-goldens test/topology/scene_3d_viewport_golden_test.dart` and confirm all tests pass successfully.
3. **Commit & Push**:
   - Commit all changes and verify `git diff origin/main` is empty.
