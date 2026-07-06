import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  group('Scene3DViewportPainter horizon culling regression tests', () {
    const double R = 6378137.0;

    test('Camera looking down from 20,000 km altitude', () {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 20000000.0, // 20,000 km
        heading: 0,
        pitch: -90, // looking straight down
        roll: 0,
      );

      final painter = Scene3DViewportPainter(
        camera: camera,
        activeStyle: 'dark',
        astronomicalBody: 'Earth',
        elevationActive: false,
        showDevices: true,
        showLinks: true,
        showLabels: true,
        showDropLines: true,
        userRotationX: 0.0,
        userTilt: 0.0,
        zoomScale: 1.0,
      );

      // Node A: on the near surface directly under the camera
      final resultA = painter.project(
        0.0, // 0 radians lat
        0.0, // 0 radians lng
        R,   // surface of the Earth
        const Offset(400, 300),
        0.0,
        0.0,
        const Size(800, 600),
      );

      // Node directly under camera on the near side should NOT be culled
      expect(resultA.z, greaterThan(0.0));

      // Node B: on the opposite side of the Earth
      final resultB = painter.project(
        0.0,
        math.pi, // opposite longitude
        R,       // surface
        const Offset(400, 300),
        0.0,
        0.0,
        const Size(800, 600),
      );

      // Node on the opposite side must be culled
      expect(resultB.z, equals(-1.0));
    });

    test('Camera looking up from 1000 km altitude towards a high-altitude satellite', () {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 1000000.0, // 1000 km
        heading: 0,
        pitch: 90, // looking straight up
        roll: 0,
      );

      final painter = Scene3DViewportPainter(
        camera: camera,
        activeStyle: 'dark',
        astronomicalBody: 'Earth',
        elevationActive: false,
        showDevices: true,
        showLinks: true,
        showLabels: true,
        showDropLines: true,
        userRotationX: 0.0,
        userTilt: 0.0,
        zoomScale: 1.0,
      );

      // Node C: high-altitude satellite directly overhead at 20,000 km altitude
      // distance from camera is 19,000 km (which exceeds the camera's horizon distance limit)
      final resultC = painter.project(
        0.0,
        0.0,
        R + 20000000.0, // 20,000 km alt
        const Offset(400, 300),
        0.0,
        0.0,
        const Size(800, 600),
      );

      // Directly overhead high-altitude satellite should NOT be culled by the new logic
      expect(resultC.z, greaterThan(0.0));
    });
  });
}
