import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

void main() {
  group('CameraController', () {
    VirtualCamera _makeCam({
      double lat = 35.0,
      double lng = 135.0,
      double alt = 500.0,
      double heading = 0.0,
      double pitch = 0.0,
      double roll = 0.0,
    }) {
      return VirtualCamera.clamped(
        latitude: lat,
        longitude: lng,
        altitude: alt,
        heading: heading,
        pitch: pitch,
        roll: roll,
      );
    }

    test('pan changes lat/lng', () {
      final c = CameraController(_makeCam());
      c.pan(const Offset(100, 50));
      final cam = c.current;
      expect(cam.longitude, lessThan(135.0));
      expect(cam.latitude, lessThan(35.0));
    });

    test('pan left (negative dx) increases longitude', () {
      final c = CameraController(_makeCam(lng: 135.0));
      final before = c.current.longitude;
      c.pan(const Offset(-200, 0));
      final after = c.current;
      expect(after.longitude, greaterThan(before));
      expect(after.latitude, equals(35.0));
      expect(after.altitude, equals(500.0));
      expect(after.pitch, equals(0.0));
      expect(after.heading, equals(0.0));
    });

    test('pan up (negative dy) increases latitude', () {
      final c = CameraController(_makeCam(lat: 35.0));
      final before = c.current.latitude;
      c.pan(const Offset(0, -100));
      final after = c.current;
      expect(after.latitude, greaterThan(before));
      expect(after.longitude, equals(135.0));
      expect(after.altitude, equals(500.0));
    });

    test('pan with pixel-accurate precision', () {
      final c = CameraController(_makeCam(lat: 0.0, lng: 0.0));
      c.pan(const Offset(100, 100));
      expect(c.current.longitude, closeTo(-1.75638, 0.0001));
      expect(c.current.latitude, closeTo(-1.75638, 0.0001));
    });

    test('pan clamps latitude to [-90, 90]', () {
      final c = CameraController(_makeCam(lat: 85.0));
      c.pan(const Offset(0, -1000000.0));
      expect(c.current.latitude, equals(90.0));
    });

    test('pan wraps longitude past 180', () {
      final c = CameraController(_makeCam(lng: 175.0));
      c.pan(const Offset(-1000.0, 0));
      expect(c.current.longitude, lessThan(-160.0));
    });

    test('tilt changes pitch/heading, not lat/lng', () {
      final c = CameraController(_makeCam(pitch: -45));
      final before = c.current;
      c.tilt(const Offset(0, 100));
      final after = c.current;
      expect(after.pitch, lessThan(before.pitch));
      expect(after.latitude, equals(before.latitude));
      expect(after.longitude, equals(before.longitude));
    });

    test('rotateHeading changes heading only', () {
      final c = CameraController(_makeCam());
      c.rotateHeading(const Offset(100, 50));
      final after = c.current;
      expect(after.heading, isNot(0));
      expect(after.latitude, equals(35.0));
      expect(after.pitch, equals(0.0));
    });

    test('shift+drag (tilt) modifies pitch and heading, not lat/lng', () {
      final c = CameraController(_makeCam(pitch: -45, heading: 90));
      final before = c.current;
      c.tilt(const Offset(20, 80));
      final after = c.current;
      expect(after.pitch, isNot(before.pitch));
      expect(after.heading, isNot(before.heading));
      expect(after.latitude, equals(before.latitude));
      expect(after.longitude, equals(before.longitude));
    });

    test('ctrl+drag (rotateHeading) modifies heading, not lat/lng/pitch', () {
      final c = CameraController(_makeCam(pitch: -30));
      final before = c.current;
      c.rotateHeading(const Offset(50, 100));
      final after = c.current;
      expect(after.heading, isNot(before.heading));
      expect(after.latitude, equals(before.latitude));
      expect(after.longitude, equals(before.longitude));
      expect(after.pitch, equals(before.pitch));
    });

    test('zoom changes altitude', () {
      final c = CameraController(_makeCam());
      c.zoom(-200);
      expect(c.current.altitude, lessThan(500.0));
    });

    test('heading wraps at 360', () {
      final c = CameraController(_makeCam(heading: 358));
      c.rotateHeading(const Offset(100, 0));
      expect(c.current.heading, lessThan(360));
      expect(c.current.heading, greaterThan(340));
    });

    test('longitude wraps around -180/+180 boundary', () {
      final c = CameraController(_makeCam(lng: -175));
      c.pan(const Offset(1000.0, 0));
      expect(c.current.longitude, lessThan(180));
      expect(c.current.longitude, greaterThan(155));
    });

    test('keyboardRotate changes longitude only', () {
      final c = CameraController(_makeCam());
      c.keyboardRotate(10);
      expect(c.current.longitude, equals(145.0));
      expect(c.current.latitude, equals(35.0));
    });

    test('keyboardRotateHeading changes heading only', () {
      final c = CameraController(_makeCam());
      c.keyboardRotateHeading(10);
      expect(c.current.heading, equals(10.0));
      expect(c.current.longitude, equals(135.0));
      expect(c.current.latitude, equals(35.0));
    });

    test('keyboardTilt changes pitch only', () {
      final c = CameraController(_makeCam());
      c.keyboardTilt(5);
      expect(c.current.pitch, equals(5.0));
    });

    test('zoom clamps to minAltitude', () {
      final c = CameraController(_makeCam(alt: 200));
      c.zoom(-10000);
      expect(c.current.altitude, equals(CameraController.minAltitude));
    });

    test('zoom clamps to maxAltitude', () {
      final c = CameraController(_makeCam());
      c.zoom(1000000000);
      expect(c.current.altitude, equals(CameraController.maxAltitude));
    });

    group('Scroll zoom behavior', () {
      test('negative delta decreases altitude (scroll up = zoom in)', () {
        final c = CameraController(_makeCam(alt: 500000));
        c.zoom(-100);
        expect(c.current.altitude, lessThan(500000));
      });

      test('positive delta increases altitude (scroll down = zoom out)', () {
        final c = CameraController(_makeCam(alt: 500000));
        c.zoom(100);
        expect(c.current.altitude, greaterThan(500000));
      });

      test('zoom respects scrollSensitivity', () {
        final c = CameraController(_makeCam(alt: 500000));
        c.zoom(-1);
        expect(c.current.altitude, closeTo(500000 - CameraController.scrollSensitivity, 0.01));
        c.zoom(1);
        expect(c.current.altitude, closeTo(500000, 0.01));
      });

      test('zoom does not affect lat/lng/pitch/heading', () {
        final c = CameraController(_makeCam(lat: 35, lng: 135, pitch: -45, heading: 90));
        final before = c.current;
        c.zoom(-200);
        final after = c.current;
        expect(after.latitude, equals(before.latitude));
        expect(after.longitude, equals(before.longitude));
        expect(after.pitch, equals(before.pitch));
        expect(after.heading, equals(before.heading));
      });

      test('small scroll delta produces visible altitude change', () {
        final c = CameraController(_makeCam(alt: 500000));
        c.zoom(-10);
        expect(c.current.altitude, closeTo(500000 - 5.0, 0.01));
      });

      test('scroll up from minAltitude stays at minAltitude', () {
        final c = CameraController(_makeCam(alt: CameraController.minAltitude));
        c.zoom(-1);
        expect(c.current.altitude, equals(CameraController.minAltitude));
      });

      test('scroll down from maxAltitude stays at maxAltitude', () {
        final c = CameraController(_makeCam(alt: CameraController.maxAltitude));
        c.zoom(1);
        expect(c.current.altitude, equals(CameraController.maxAltitude));
      });
    });

    test('keyboardTilt wraps pitch past 180', () {
      final c = CameraController(_makeCam(pitch: 175));
      c.keyboardTilt(10);
      expect(c.current.pitch, equals(-175.0));
    });

    test('keyboardTilt wraps pitch past -180', () {
      final c = CameraController(_makeCam(pitch: -175));
      c.keyboardTilt(-10);
      expect(c.current.pitch, equals(175.0));
    });
  });

  group('VirtualCamera equality', () {
    test('identical cameras compare equal', () {
      final a = VirtualCamera(latitude: 35, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      final b = VirtualCamera(latitude: 35, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      expect(a, equals(b));
    });
    test('different values compare not equal', () {
      final a = VirtualCamera(latitude: 35, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      final b = VirtualCamera(latitude: 36, longitude: 135, altitude: 500, heading: 0, pitch: -45, roll: 0);
      expect(a, isNot(equals(b)));
    });
  });
}
