import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Issue #46: Shift+drag tilts camera', (WidgetTester tester) async {
    final camera = VirtualCamera(
      latitude: 35.0,
      longitude: 135.0,
      altitude: 1000.0,
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

    // Simulate key down event for Shift key
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    // Perform drag gesture
    final viewportFinder = find.byType(Scene3DViewport);
    await tester.drag(viewportFinder, const Offset(0.0, 50.0));
    await tester.pump(const Duration(seconds: 1));

    // Simulate key up event for Shift key
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    // Verify camera tilt occurred (pitch changed, but lat/lng remained unchanged)
    expect(controller.current.pitch, isNot(-45.0));
    expect(controller.current.latitude, equals(35.0));
    expect(controller.current.longitude, equals(135.0));
  });
}
