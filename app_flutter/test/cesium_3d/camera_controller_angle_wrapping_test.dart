import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';

void main() {
  group('CameraController Angle Wrapping Tests', () {
    test('Non-finite safe coordinate wrapping returns 0.0', () {
      // _wrapLngStatic
      expect(CameraController.wrapLngStaticForTesting(double.infinity), 0.0);
      expect(CameraController.wrapLngStaticForTesting(double.negativeInfinity), 0.0);
      expect(CameraController.wrapLngStaticForTesting(double.nan), 0.0);

      // _wrapHeadingStatic
      expect(CameraController.wrapHeadingStaticForTesting(double.infinity), 0.0);
      expect(CameraController.wrapHeadingStaticForTesting(double.negativeInfinity), 0.0);
      expect(CameraController.wrapHeadingStaticForTesting(double.nan), 0.0);

      // _wrapPitchStatic
      expect(CameraController.wrapPitchStaticForTesting(double.infinity), 0.0);
      expect(CameraController.wrapPitchStaticForTesting(double.negativeInfinity), 0.0);
      expect(CameraController.wrapPitchStaticForTesting(double.nan), 0.0);

      // _wrapLng (instance method)
      final dummyCam = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 500.0,
        heading: 0.0,
        pitch: 0.0,
        roll: 0.0,
      );
      final controller = CameraController(dummyCam);
      expect(controller.wrapLngForTesting(double.infinity), 0.0);
      expect(controller.wrapLngForTesting(double.negativeInfinity), 0.0);
      expect(controller.wrapLngForTesting(double.nan), 0.0);
    });

    test('Extremely large finite values wrap successfully and quickly (loop-safety)', () {
      // e.g. 1e15, which would cause an infinite loop or massive latency in while-loop logic
      // Lng wrapping should map 1e15 to its corresponding [-180, 180] value
      final double largeVal = 1e15;
      
      final wrappedLngStatic = CameraController.wrapLngStaticForTesting(largeVal);
      expect(wrappedLngStatic, greaterThanOrEqualTo(-180.0));
      expect(wrappedLngStatic, lessThanOrEqualTo(180.0));

      final wrappedHeadingStatic = CameraController.wrapHeadingStaticForTesting(largeVal);
      expect(wrappedHeadingStatic, greaterThanOrEqualTo(0.0));
      expect(wrappedHeadingStatic, lessThan(360.0));

      final wrappedPitchStatic = CameraController.wrapPitchStaticForTesting(largeVal);
      expect(wrappedPitchStatic, greaterThanOrEqualTo(-180.0));
      expect(wrappedPitchStatic, lessThanOrEqualTo(180.0));

      final dummyCam = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 500.0,
        heading: 0.0,
        pitch: 0.0,
        roll: 0.0,
      );
      final controller = CameraController(dummyCam);
      final wrappedLng = controller.wrapLngForTesting(largeVal);
      expect(wrappedLng, greaterThanOrEqualTo(-180.0));
      expect(wrappedLng, lessThanOrEqualTo(180.0));
    });

    test('Standard boundary coordinates wrap correctly', () {
      // Standard Lng boundaries: [-180, 180]
      expect(CameraController.wrapLngStaticForTesting(180.0), 180.0);
      expect(CameraController.wrapLngStaticForTesting(-180.0), -180.0);
      expect(CameraController.wrapLngStaticForTesting(181.0), -179.0);
      expect(CameraController.wrapLngStaticForTesting(-181.0), 179.0);
      expect(CameraController.wrapLngStaticForTesting(360.0), 0.0);
      expect(CameraController.wrapLngStaticForTesting(-360.0), 0.0);

      // Standard Heading boundaries: [0, 360)
      expect(CameraController.wrapHeadingStaticForTesting(0.0), 0.0);
      expect(CameraController.wrapHeadingStaticForTesting(360.0), 0.0);
      expect(CameraController.wrapHeadingStaticForTesting(-1.0), 359.0);
      expect(CameraController.wrapHeadingStaticForTesting(361.0), 1.0);
      expect(CameraController.wrapHeadingStaticForTesting(720.0), 0.0);

      // Standard Pitch boundaries: [-180, 180]
      expect(CameraController.wrapPitchStaticForTesting(180.0), 180.0);
      expect(CameraController.wrapPitchStaticForTesting(-180.0), -180.0);
      expect(CameraController.wrapPitchStaticForTesting(181.0), -179.0);
      expect(CameraController.wrapPitchStaticForTesting(-181.0), 179.0);
      expect(CameraController.wrapPitchStaticForTesting(360.0), 0.0);
    });
  });
}
