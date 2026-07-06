import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Issue #41: Globe drag changes camera position', (WidgetTester tester) async {
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

    // Verify initial HUD coordinates
    expect(find.textContaining('Latitude: 35.000000'), findsOneWidget);
    expect(find.textContaining('Longitude: 135.000000'), findsOneWidget);

    // Perform drag gesture on the globe viewport
    final viewportFinder = find.byType(Scene3DViewport);
    await tester.drag(viewportFinder, const Offset(-100.0, 50.0));
    await tester.pump(const Duration(seconds: 1));

    // Retrieve viewport state and verify camera changes
    final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controller = state.cameraController as CameraController;

    expect(controller.current.longitude, isNot(135.0));
    expect(controller.current.latitude, isNot(35.0));

    // Verify HUD text is updated and does not display the old values
    expect(find.textContaining('Latitude: 35.000000'), findsNothing);
    expect(find.textContaining('Longitude: 135.000000'), findsNothing);
  });
}
