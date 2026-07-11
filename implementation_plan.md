# Implementation Plan - Optical Axis Projection, Rotation Fixes, and Golden Tests

This plan details the fixes for the optical axis projection tilt/pitch, ECEF double-elevation fallback, heading rotation matrix, sphere shader gradient alignment, and the regression/golden test updates.

## Target Files & Proposed Changes

### 1. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- **Fix 1: ECEF Fallback (No internal double-elevation)**:
  In `project` method (lines 1177-1199), replace the ECEF calculation block:
  ```dart
    final CesiumEngine? engine = CesiumEngine.instance;
    final double radLng = -rotationY;
    final double radLat = -tilt;

    final double R = 6378137.0;

    double px = 0.0;
    double py = 0.0;
    double pz = 0.0;

    if (engine != null && engine.isReady) {
      final ecef = engine.cartographicToEcef(lat * 180.0 / math.pi, lng * 180.0 / math.pi, height - R);
      if (ecef != null) {
        final (x, y, z) = ecef;
        px = x;
        py = y;
        pz = z;
      }
    } else {
      px = height * math.cos(lat) * math.cos(lng);
      py = height * math.cos(lat) * math.sin(lng);
      pz = height * math.sin(lat);
    }
  ```
  with WGS84/geocentric fallback directly (since elevation is already added in `finalHeight` computation and passed as `height` parameter):
  ```dart
    final double radLng = -rotationY;
    final double radLat = -tilt;

    final double R = 6378137.0;

    final double px = height * math.cos(lat) * math.cos(lng);
    final double py = height * math.cos(lat) * math.sin(lng);
    final double pz = height * math.sin(lat);
  ```

- **Fix 2: Correct heading rotation matrix** (both in `project` and `_getHorizonPath` methods):
  Replace heading rotation matrix in `project` (lines 1265-1266):
  ```dart
    final double x1 = x_enu * cosH + y_enu * sinH;
    final double y1 = -x_enu * sinH + y_enu * cosH;
  ```
  with:
  ```dart
    final double x1 = x_enu * cosH - y_enu * sinH;
    final double y1 = x_enu * sinH + y_enu * cosH;
  ```
  Replace heading rotation matrix in `_getHorizonPath` (lines 1377-1378):
  ```dart
      final double x1 = x_enu * cosH + y_enu * sinH;
      final double y1 = -x_enu * sinH + y_enu * cosH;
  ```
  with:
  ```dart
      final double x1 = x_enu * cosH - y_enu * sinH;
      final double y1 = x_enu * sinH + y_enu * cosH;
  ```

- **Fix 3: Correct pitch rotation signs** (already implemented local-side in `project` and `_getHorizonPath`):
  Ensure pitch rotation in `project` (lines 1270-1271) and `_getHorizonPath` (lines 1382-1383) uses:
  ```dart
    final double y_cam = y1 * cosA + z1 * sinA;
    final double z_cam = -y1 * sinA + z1 * cosA;
  ```

- **Fix 4: Align sphere shader gradient**:
  In `paint` method (around line 1421), replace the stationary center projection:
  ```dart
    final ProjectedPoint earthCenterProj = project(0.0, 0.0, 0.0, center, 0.0, 0.0, size);
  ```
  with:
  ```dart
    final ProjectedPoint earthCenterProj = project(0.0, 0.0, 0.0, center, rotationAngle, tilt, size);
  ```

- **Testing Utility**:
  Add public helper `getEcefCoordinatesForTesting` to `Scene3DViewportPainter` so the new test case can verify intermediate ECEF values:
  ```dart
  (double, double, double) getEcefCoordinatesForTesting(double lat, double lng, double height) {
    final double px = height * math.cos(lat) * math.cos(lng);
    final double py = height * math.cos(lat) * math.sin(lng);
    final double pz = height * math.sin(lat);
    return (px, py, pz);
  }
  ```

### 2. `app_flutter/test/topology/scene_3d_viewport_golden_test.dart`
- In `'Visual Test 3 - Forward/Backward Projection Inversion Culling'`, change the culling assertions to represent the correct physical view (Nagoya Southwest/behind is culled, Tokyo Northeast/in front is projected):
  Replace:
  ```dart
  expect(nagoyaProj.z, greaterThan(0.0));
  expect(tokyoProj.z, lessThan(0.0));
  ```
  with:
  ```dart
  expect(nagoyaProj.z, lessThan(0.0));
  expect(tokyoProj.z, greaterThan(0.0));
  ```
- Add `'Visual Test 4 - Double Elevation Verification'` checking that when projecting a node at (135.0, 35.0, 6378137.0 + 800.0) with `elevationActive = true`, its computed ECEF vector magnitude exactly equals `6378137.0 + 800.0` (not double-added).

## Verification Plan
1. Modify the Golden Test File (`scene_3d_viewport_golden_test.dart`) to apply the new assertions and add the new test case.
2. Run target test: `flutter test test/topology/scene_3d_viewport_golden_test.dart` to verify that the tests fail under the buggy code (failure detection loop).
3. Surgically modify `scene_3d_viewport.dart` to apply Fixes 1, 2, and 4, and add the helper method.
4. Regenerate golden visual baselines by running:
   `flutter test --update-goldens test/topology/scene_3d_viewport_golden_test.dart`
5. Run the entire test suite `flutter test` to ensure all 213 unit and visual tests pass successfully.
6. Commit all modified files and new golden PNG files, and push changes to origin tracking branch.
