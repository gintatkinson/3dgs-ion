import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:clock/clock.dart';
import 'virtual_camera.dart';

class CameraController extends ChangeNotifier {
  VirtualCamera _camera;

  VirtualCamera? _startCamera;
  VirtualCamera? _targetCamera;
  DateTime _animationStart = DateTime(0);

  static const double dragSensitivity = 0.15;
  static const double scrollSensitivity = 0.5;
  static const double keyboardStep = 5.0;
  static const double minAltitude = 100.0;
  static const double maxAltitude = 40000000.0;

  double Function(double lat, double lng)? elevationProvider;

  double _getTerrainHeight(double lat, double lng) {
    if (elevationProvider == null) return 0.0;
    return elevationProvider!(lat, lng);
  }

  double _clampAltitudeToTerrain(double lat, double lng, double targetAlt) {
    final double terrainH = _getTerrainHeight(lat, lng);
    final double minAlt = 6378137.0 + terrainH + minAltitude;
    return targetAlt < minAlt ? minAlt : targetAlt;
  }

  CameraController(VirtualCamera camera) : _camera = camera.altitude < 6378137.0 ? VirtualCamera.clamped(
    latitude: camera.latitude,
    longitude: camera.longitude,
    altitude: 6378137.0 + camera.altitude,
    heading: camera.heading,
    pitch: camera.pitch,
    roll: camera.roll,
  ) : camera;

  VirtualCamera get current => _camera;

  bool get isFlying => _targetCamera != null;

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

  void flyTo(VirtualCamera target) {
    _startCamera = _camera;
    _targetCamera = target;
    _animationStart = clock.now();
  }

  bool tick() {
    if (_startCamera == null || _targetCamera == null) return true;
    final elapsed = clock.now().difference(_animationStart);
    final duration = const Duration(milliseconds: 500);
    final progress =
        (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final t = _easeInOutCubic(progress);
    _camera = _lerpCamera(_startCamera!, _targetCamera!, t);
    notifyListeners();
    if (progress >= 1.0) {
      _camera = _targetCamera!;
      _startCamera = null;
      _targetCamera = null;
      notifyListeners();
      return true;
    }
    return false;
  }

  static double _easeInOutCubic(double t) {
    return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
  }

  static VirtualCamera _lerpCamera(VirtualCamera a, VirtualCamera b, double t) {
    return VirtualCamera.clamped(
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: _interpolateCircular(a.longitude, b.longitude, t, _wrapLngStatic),
      altitude: a.altitude + (b.altitude - a.altitude) * t,
      heading: _interpolateCircular(a.heading, b.heading, t, _wrapHeadingStatic),
      pitch: _interpolateCircular(a.pitch, b.pitch, t, _wrapPitchStatic),
      roll: a.roll + (b.roll - a.roll) * t,
    );
  }

  static double _interpolateCircular(double from, double to, double t, double Function(double) wrapFn) {
    double diff = to - from;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return wrapFn(from + diff * t);
  }

  static double _wrapLngStatic(double lng) {
    if (lng.isNaN || !lng.isFinite) return 0.0;
    double wrapped = (lng + 180.0) % 360.0;
    if (wrapped < 0.0) wrapped += 360.0;
    double val = wrapped - 180.0;
    if (val == -180.0) {
      return lng >= 0.0 ? 180.0 : -180.0;
    }
    return val;
  }

  static double _wrapHeadingStatic(double heading) {
    if (heading.isNaN || !heading.isFinite) return 0.0;
    double wrapped = heading % 360.0;
    if (wrapped < 0.0) wrapped += 360.0;
    return wrapped;
  }

  void pan(Offset delta, [double shortestSide = 800.0]) {
    if (shortestSide <= 0.0 || shortestSide.isNaN) {
      shortestSide = 800.0;
    }
    final double factor = (_camera.altitude - 6378137.0 + 500000.0) * 2.8074e-5 / shortestSide;
    final double radH = _camera.heading * math.pi / 180.0;
    final double cosH = math.cos(radH);
    final double sinH = math.sin(radH);
    final double dxAligned = delta.dx * cosH + delta.dy * sinH;
    final double dyAligned = -delta.dx * sinH + delta.dy * cosH;
    final newLat = (_camera.latitude - dyAligned * factor).clamp(-90.0, 90.0);
    final newLng = _wrapLng(_camera.longitude - dxAligned * factor);
    final double targetAlt = _clampAltitudeToTerrain(newLat, newLng, _camera.altitude);
    _camera = VirtualCamera.clamped(
      latitude: newLat,
      longitude: newLng,
      altitude: targetAlt,
      heading: _camera.heading,
      pitch: _camera.pitch,
      roll: _camera.roll,
    );
    notifyListeners();
  }

  void tilt(Offset delta) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude,
      heading: _wrapHeading(_camera.heading - delta.dx * dragSensitivity),
      pitch: _wrapPitch(_camera.pitch - delta.dy * dragSensitivity),
      roll: _camera.roll,
    );
    notifyListeners();
  }

  void rotateHeading(Offset delta) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude,
      heading: _wrapHeading(_camera.heading - delta.dx * dragSensitivity),
      pitch: _camera.pitch, roll: _camera.roll,
    );
    notifyListeners();
  }

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

  void keyboardRotate(double degrees) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _wrapLng(_camera.longitude + degrees),
      altitude: _camera.altitude, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
    );
    notifyListeners();
  }

  void keyboardRotateHeading(double degrees) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude,
      heading: _wrapHeading(_camera.heading + degrees),
      pitch: _camera.pitch, roll: _camera.roll,
    );
    notifyListeners();
  }

  void keyboardTilt(double degrees) {
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: _camera.altitude, heading: _camera.heading,
      pitch: _wrapPitch(_camera.pitch + degrees),
      roll: _camera.roll,
    );
    notifyListeners();
  }

  double _wrapLng(double lng) {
    if (lng.isNaN || !lng.isFinite) return 0.0;
    double wrapped = (lng + 180.0) % 360.0;
    if (wrapped < 0.0) wrapped += 360.0;
    double val = wrapped - 180.0;
    if (val == -180.0) {
      return lng >= 0.0 ? 180.0 : -180.0;
    }
    return val;
  }

  double _wrapHeading(double heading) => _wrapHeadingStatic(heading);

  double _wrapPitch(double pitch) => _wrapPitchStatic(pitch);

  static double _wrapPitchStatic(double pitch) {
    if (pitch.isNaN || !pitch.isFinite) return 0.0;
    double wrapped = (pitch + 180.0) % 360.0;
    if (wrapped < 0.0) wrapped += 360.0;
    double val = wrapped - 180.0;
    if (val == -180.0) {
      return pitch >= 0.0 ? 180.0 : -180.0;
    }
    return val;
  }

  @visibleForTesting
  static double wrapLngStaticForTesting(double lng) => _wrapLngStatic(lng);

  @visibleForTesting
  static double wrapHeadingStaticForTesting(double heading) => _wrapHeadingStatic(heading);

  @visibleForTesting
  double wrapLngForTesting(double lng) => _wrapLng(lng);

  @visibleForTesting
  static double wrapPitchStaticForTesting(double pitch) => _wrapPitchStatic(pitch);
}
