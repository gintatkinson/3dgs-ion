import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Issue #42: Scroll zoom changes altitude', (WidgetTester tester) async {
    final camera = VirtualCamera(
      latitude: 35.0,
      longitude: 135.0,
      altitude: 10000.0,
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

    // Verify initial altitude HUD
    expect(find.textContaining('Altitude: 10000.0 meters'), findsOneWidget);

    // Simulate scroll zoom in (negative dy)
    final viewportFinder = find.byType(Scene3DViewport);
    final center = tester.getCenter(viewportFinder);
    
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    await tester.sendEventToBinding(pointer.scroll(const Offset(0.0, -100.0)));
    await tester.pump(const Duration(seconds: 1));

    // Retrieve viewport state and verify camera changes
    final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controller = state.cameraController as CameraController;

    expect(controller.current.altitude, lessThan(10000.0));

    // Verify HUD text is updated and does not display the old altitude value
    expect(find.textContaining('Altitude: 10000.0 meters'), findsNothing);
  });
}
