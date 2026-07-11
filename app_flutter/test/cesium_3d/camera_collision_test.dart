import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

void main() {
  group('Camera Terrain Collision Detection & Clamping', () {
    double getMockTerrainHeight(double lat, double lng, bool active) {
      if (!active) return 0.0;
      // Mount Fuji peak: 35.3606° N, 138.7274° E
      final double dLat = lat - 35.3606;
      final double dLng = lng - 138.7274;
      final double distSq = dLat * dLat + dLng * dLng;
      double elev = 0.0;
      final double fujiDist = math.sqrt(distSq);
      if (fujiDist < 0.25) {
        elev += 3776.0 * math.exp(-fujiDist * fujiDist / (0.04 * 0.04));
      }

      // Alps mountain range around central Japan: 34.5° N - 37.5° N, 136.0° E - 140.0° E
      if (lat > 34.5 && lat < 37.5 && lng > 136.0 && lng < 140.0) {
        final double rangeNoise = math.sin(lat * 12.0) * math.cos(lng * 12.0) * 1200.0 +
                                 math.sin(lat * 25.0) * math.sin(lng * 25.0) * 400.0;
        elev += math.max(0.0, rangeNoise);
      }

      return elev * 80.0; // matching 80.0x amplification
    }

    test('Nadir Zoom-in Clamps at Ellipsoid Base Over Ocean (Flat Terrain)', () {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 1000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );
      final controller = CameraController(camera);
      controller.elevationProvider = (lat, lng) => getMockTerrainHeight(lat, lng, true);

      // Attempt to zoom in past the minimum height (minAltitude = 100m)
      controller.zoom(-5000.0);

      // Verify camera altitude is clamped exactly at 100m above flat ocean (terrain = 0)
      expect(controller.current.altitude, equals(6378137.0 + 100.0));
    });

    test('Nadir Zoom-in Clamps Correctly Above Amplified Mount Fuji', () {
      // Position camera directly over Fuji Peak
      final camera = VirtualCamera.clamped(
        latitude: 35.3606,
        longitude: 138.7274,
        altitude: 500000.0, // 500km altitude
        heading: 0,
        pitch: -90,
        roll: 0,
      );
      final controller = CameraController(camera);
      controller.elevationProvider = (lat, lng) => getMockTerrainHeight(lat, lng, true);

      // Zoom in deep
      controller.zoom(-1000000.0);

      // Expected altitude clamp = Fuji Amplified Height (302,080) + minHeight (100) = 302,180m
      const double fujiAmplifiedHeight = 3776.0 * 80.0;
      const double expectedClamp = fujiAmplifiedHeight + 100.0;

      expect(controller.current.altitude, closeTo(6378137.0 + expectedClamp, 1.0));
    });

    test('Panning Toward Rising Terrain Automatically Lifts Camera', () {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 100.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );
      final controller = CameraController(camera);
      controller.elevationProvider = (lat, lng) => getMockTerrainHeight(lat, lng, true);

      // Pan/Update camera directly to Mount Fuji at a low altitude
      controller.updateCamera(VirtualCamera.clamped(
        latitude: 35.3606,
        longitude: 138.7274,
        altitude: 100.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      ));

      // The terrain-aware controller must detect collision and clamp altitude to 302,180m
      const double expectedClamp = (3776.0 * 80.0) + 100.0;
      expect(controller.current.altitude, closeTo(6378137.0 + expectedClamp, 1.0));
    });
  });
}
