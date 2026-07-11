# Implementation Plan - ECEF Scroll-Zoom Math Corrections

This plan details the surgical changes to implement ECEF scroll-zoom math corrections and align tests.

## Target Files & Proposed Diffs

### 1. `app_flutter/lib/domain/cesium_3d/camera_controller.dart`
- Update constructor to handle absolute ECEF conversion:
```dart
  CameraController(VirtualCamera camera) : _camera = camera.altitude < 6378137.0 ? VirtualCamera.clamped(
    latitude: camera.latitude,
    longitude: camera.longitude,
    altitude: 6378137.0 + camera.altitude,
    heading: camera.heading,
    pitch: camera.pitch,
    roll: camera.roll,
  ) : camera;
```
- Update `updateCamera` to handle absolute conversion for relative altitude (`< 6378137.0`) input before clamping:
```dart
  void updateCamera(VirtualCamera camera) {
    final absoluteCamera = camera.altitude < 6378137.0 ? VirtualCamera.clamped(
      latitude: camera.latitude,
      longitude: camera.longitude,
      altitude: 6378137.0 + camera.altitude,
      heading: camera.heading,
      pitch: camera.pitch,
      roll: camera.roll,
    ) : camera;
    final double targetAlt = _clampAltitudeToTerrain(absoluteCamera.latitude, absoluteCamera.longitude, absoluteCamera.altitude);
    final clampedCam = VirtualCamera.clamped(
      latitude: absoluteCamera.latitude,
      longitude: absoluteCamera.longitude,
      altitude: targetAlt,
      heading: absoluteCamera.heading,
      pitch: absoluteCamera.pitch,
      roll: absoluteCamera.roll,
    );
    if (_camera == clampedCam) return;
    _camera = clampedCam;
    _targetCamera = null;
    _startCamera = null;
    notifyListeners();
  }
```
- Update `_clampAltitudeToTerrain` to compute `minAlt` as absolute:
```dart
  double _clampAltitudeToTerrain(double lat, double lng, double targetAlt) {
    final double terrainH = _getTerrainHeight(lat, lng);
    final double minAlt = 6378137.0 + terrainH + minAltitude;
    return targetAlt < minAlt ? minAlt : targetAlt;
  }
```
- Update `pan` to compute relative altitude for the drag speed factor:
```dart
  void pan(Offset delta, [double shortestSide = 800.0]) {
    if (shortestSide <= 0.0 || shortestSide.isNaN) {
      shortestSide = 800.0;
    }
    final double factor = (_camera.altitude - 6378137.0 + 500000.0) * 2.8074e-5 / shortestSide;
    // ... rest remains same ...
  }
```
- Update `zoom` (lines 166-181) to compute relative height above terrain by subtracting `6378137.0`:
```dart
  void zoom(double scrollDelta) {
    final double terrainH = _getTerrainHeight(_camera.latitude, _camera.longitude);
    final double currentHeightAGL = _camera.altitude - (6378137.0 + terrainH);
    final double targetHeightAGL = currentHeightAGL + scrollDelta * scrollSensitivity;
    final double clampedHeightAGL = targetHeightAGL.clamp(minAltitude, maxAltitude);
    final double newAlt = 6378137.0 + clampedHeightAGL + terrainH;
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude,
      longitude: _camera.longitude,
      altitude: newAlt,
      heading: _camera.heading,
      pitch: _camera.pitch,
      roll: _camera.roll,
    );
    notifyListeners();
  }
```
- Update `zoomInteractive` (lines 183-199) to compute relative height above terrain by subtracting `6378137.0`, clamp `scrollDelta` to `[-100.0, 100.0]`, and change the multiplier from `0.005` to `0.001`:
```dart
  void zoomInteractive(double scrollDelta) {
    final double clampedDelta = scrollDelta.clamp(-100.0, 100.0);
    final double factor = math.exp(clampedDelta * 0.001);
    final double terrainH = _getTerrainHeight(_camera.latitude, _camera.longitude);
    final double currentHeightAGL = _camera.altitude - (6378137.0 + terrainH);
    final double targetHeightAGL = currentHeightAGL * factor;
    final double clampedHeightAGL = targetHeightAGL.clamp(minAltitude, maxAltitude);
    final double newAlt = 6378137.0 + clampedHeightAGL + terrainH;
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude,
      longitude: _camera.longitude,
      altitude: newAlt,
      heading: _camera.heading,
      pitch: _camera.pitch,
      roll: _camera.roll,
    );
    notifyListeners();
  }
```

### 2. `app_flutter/test/cesium_3d/camera_collision_test.dart`
- Update assertions expecting relative altitudes to expect absolute ECEF altitudes by adding `6378137.0`:
  - `expect(controller.current.altitude, equals(6378137.0 + 100.0));`
  - `expect(controller.current.altitude, closeTo(6378137.0 + expectedClamp, 1.0));`

### 3. `app_flutter/test/topology/scroll_zoom_test.dart`
- Initial camera has altitude `1000.0`. Since `1000.0 < 6378137.0`, `CameraController` constructor clamps/transforms it to:
  `6378137.0 + 1000.0 = 6379137.0` (absolute ECEF altitude).
- In the test, a scroll event of `Offset(0, 53)` triggers `zoomInteractive(53)`.
- Inside `zoomInteractive(53)`:
  - `clampedDelta = 53.0`
  - `factor = math.exp(53.0 * 0.001) = 1.05443242095`
  - `terrainH = 0.0`
  - `currentHeightAGL = 6379137.0 - (6378137.0 + 0) = 1000.0`
  - `targetHeightAGL = 1000.0 * 1.05443242095 = 1054.43242095`
  - `clampedHeightAGL = 1054.43242095`
  - `newAlt = 6378137.0 + 1054.43242095 + 0.0 = 6379191.43242095`
- The expected target absolute altitude is therefore `6379191.43` (rounded). We update the test assertion to:
  `expect(controller.current.altitude, closeTo(6379191.43, 0.01));`

### 4. `app_flutter/test/cesium_3d/camera_controller_test.dart`
- Update assertions expecting relative altitudes to expect absolute ECEF altitudes by adding `6378137.0`:
  - Line 40: `expect(after.altitude, equals(6378137.0 + 500.0));`
  - Line 52: `expect(after.altitude, equals(6378137.0 + 500.0));`
  - Line 118: `expect(c.current.altitude, lessThan(6378137.0 + 500.0));`
  - Line 159: `expect(c.current.altitude, equals(6378137.0 + CameraController.minAltitude));`
  - Line 165: `expect(c.current.altitude, equals(6378137.0 + CameraController.maxAltitude));`
  - Line 172: `expect(c.current.altitude, lessThan(6378137.0 + 500000));`
  - Line 178: `expect(c.current.altitude, greaterThan(6378137.0 + 500000));`
  - Line 184: `expect(c.current.altitude, closeTo(6378137.0 + 500000 - CameraController.scrollSensitivity, 0.01));`
  - Line 186: `expect(c.current.altitude, closeTo(6378137.0 + 500000, 0.01));`
  - Line 203: `expect(c.current.altitude, closeTo(6378137.0 + 500000 - 5.0, 0.01));`
  - Line 209: `expect(c.current.altitude, equals(6378137.0 + CameraController.minAltitude));`
  - Line 215: `expect(c.current.altitude, equals(6378137.0 + CameraController.maxAltitude));`

### 5. `app_flutter/lib/features/topology/scene_3d_viewport.dart`
- Surgically modify the file to replace the 4 occurrences of `cRad` calculation:
  - Occurrence 1 (hitTest, lines 424-425):
    Replace:
    ```dart
    final double camElevation = _elevationActive ? Scene3DViewportPainter.getElevationStatic(camera.latitude, camera.longitude, true) * widget.verticalExaggeration : 0.0;
    final double cRad = camera.altitude + camElevation;
    ```
    with:
    ```dart
    final double cRad = camera.altitude;
    ```
  - Occurrence 2 (project, lines 1201-1202):
    Replace:
    ```dart
    final double camElevation = elevationActive ? getElevation(camera.latitude, camera.longitude) * verticalExaggeration : 0.0;
    final double cRad = camera.altitude + camElevation;
    ```
    with:
    ```dart
    final double cRad = camera.altitude;
    ```
  - Occurrence 3 (_getHorizonPath, lines 1322-1323):
    Replace:
    ```dart
    final double camElevation = elevationActive ? getElevation(camera.latitude, camera.longitude) * verticalExaggeration : 0.0;
    final double cRad = camera.altitude + camElevation;
    ```
    with:
    ```dart
    final double cRad = camera.altitude;
    ```
  - Occurrence 4 (paint, lines 1425-1426):
    Replace:
    ```dart
    final double camElevation = elevationActive ? getElevation(camera.latitude, camera.longitude) * verticalExaggeration : 0.0;
    final double cRad = camera.altitude + camElevation;
    ```
    with:
    ```dart
    final double cRad = camera.altitude;
    ```

## Verification Plan

- Run the flutter tests:
  `flutter test`
- Ensure all tests pass.
- Verify `git diff origin/main` matches expectations and there are no extraneous changes.
- Push and check remote sync.


