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

  CameraController(this._camera);

  VirtualCamera get current => _camera;

  bool get isFlying => _targetCamera != null;

  void updateCamera(VirtualCamera camera) {
    if (_camera == camera) return;
    _camera = camera;
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
    double lerpLng(double from, double to) {
      double diff = to - from;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      return _wrapLngStatic(from + diff * t);
    }
    double lerpHeading(double from, double to) {
      double diff = to - from;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      return _wrapHeadingStatic(from + diff * t);
    }
    double lerpPitch(double from, double to) {
      double diff = to - from;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      return _wrapPitchStatic(from + diff * t);
    }

    return VirtualCamera.clamped(
      latitude: a.latitude + (b.latitude - a.latitude) * t,
      longitude: lerpLng(a.longitude, b.longitude),
      altitude: a.altitude + (b.altitude - a.altitude) * t,
      heading: lerpHeading(a.heading, b.heading),
      pitch: lerpPitch(a.pitch, b.pitch),
      roll: a.roll + (b.roll - a.roll) * t,
    );
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
    final double factor = (_camera.altitude + 500000.0) * 2.8074e-5 / shortestSide;
    
    // Rotate the drag delta by the camera heading to align panning with the screen axes
    final double radH = _camera.heading * math.pi / 180.0;
    final double cosH = math.cos(radH);
    final double sinH = math.sin(radH);
    
    final double dxAligned = delta.dx * cosH + delta.dy * sinH;
    final double dyAligned = -delta.dx * sinH + delta.dy * cosH;
    
    final newLat = (_camera.latitude - dyAligned * factor).clamp(-90.0, 90.0);
    final newLng = _wrapLng(_camera.longitude - dxAligned * factor);
    _camera = VirtualCamera.clamped(
      latitude: newLat, longitude: newLng,
      altitude: _camera.altitude, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
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
    final newAlt = (_camera.altitude + scrollDelta * scrollSensitivity).clamp(minAltitude, maxAltitude);
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: newAlt, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
    );
    notifyListeners();
  }

  void zoomInteractive(double scrollDelta) {
    final double factor = math.exp(scrollDelta * 0.005);
    final newAlt = (_camera.altitude * factor).clamp(minAltitude, maxAltitude);
    _camera = VirtualCamera.clamped(
      latitude: _camera.latitude, longitude: _camera.longitude,
      altitude: newAlt, heading: _camera.heading,
      pitch: _camera.pitch, roll: _camera.roll,
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
