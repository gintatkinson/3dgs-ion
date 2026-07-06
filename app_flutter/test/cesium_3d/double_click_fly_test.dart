import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Issue #49: Double-click flies camera closer to globe', (WidgetTester tester) async {
    final camera = VirtualCamera(
      latitude: 35.0,
      longitude: 135.0,
      altitude: 100000.0,
      heading: 0.0,
      pitch: -45.0,
      roll: 0.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Scene3DViewport(
            camera: camera,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controller = state.cameraController as CameraController;

    expect(controller.current.altitude, equals(100000.0));
    expect(controller.isFlying, isFalse);

    // Simulate double-tap on the viewport
    final viewportFinder = find.byType(Scene3DViewport);
    await tester.tap(viewportFinder);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewportFinder);
    await tester.pump();

    // Verify that the camera is now flying to a target
    expect(controller.isFlying, isTrue);

    // Let the animation tick forward
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.current.altitude, lessThan(100000.0));

    // Wait until fly completes
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(controller.isFlying, isFalse);
    expect(controller.current.altitude, closeTo(50000.0, 0.1));
  });
}
