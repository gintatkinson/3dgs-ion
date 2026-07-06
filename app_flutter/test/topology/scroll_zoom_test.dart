import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Scroll wheel dispatches to CameraController.zoom', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final camera = VirtualCamera.clamped(
      latitude: 35.0,
      longitude: 140.0,
      altitude: 1000.0,
      heading: 0,
      pitch: -45,
      roll: 0,
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

    final viewportState = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controller = viewportState.cameraController as CameraController;

    final Offset center = tester.getCenter(find.byType(Scene3DViewport));
    final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(center);
    final PointerScrollEvent event = pointer.scroll(const Offset(0, 53));

    tester.binding.handlePointerEvent(event);
    await tester.pump();

    expect(controller.current.altitude, closeTo(1303.43, 0.01));
  });
}
