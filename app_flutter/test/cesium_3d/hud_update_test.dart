import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

class _HUDTestWrapper extends StatefulWidget {
  final VirtualCamera camera;

  const _HUDTestWrapper({required this.camera});

  @override
  State<_HUDTestWrapper> createState() => _HUDTestWrapperState();
}

class _HUDTestWrapperState extends State<_HUDTestWrapper> {
  bool _toggleState = false;

  void toggle() {
    setState(() {
      _toggleState = !_toggleState;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            ElevatedButton(
              key: const Key('rebuild_button'),
              onPressed: toggle,
              child: const Text('Rebuild Parent'),
            ),
            Expanded(
              child: Scene3DViewport(
                camera: widget.camera,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Issue #44: HUD updates and retains coordinates across parent rebuilds', (WidgetTester tester) async {
    final camera = VirtualCamera(
      latitude: 35.0,
      longitude: 135.0,
      altitude: 1000.0,
      heading: 0.0,
      pitch: -45.0,
      roll: 0.0,
    );

    await tester.pumpWidget(_HUDTestWrapper(camera: camera));
    await tester.pumpAndSettle();

    // Verify initial values on HUD
    expect(find.textContaining('Latitude: 35.000000'), findsOneWidget);
    expect(find.textContaining('Longitude: 135.000000'), findsOneWidget);

    // Pan camera to a new position
    final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controller = state.cameraController as CameraController;
    controller.pan(const Offset(100.0, 50.0));
    await tester.pump();

    final double newLat = controller.current.latitude;
    final double newLng = controller.current.longitude;
    expect(newLat, isNot(35.0));
    expect(newLng, isNot(135.0));

    // Verify HUD text updated to new coordinates
    expect(find.textContaining('Latitude: 35.000000'), findsNothing);
    expect(find.textContaining('Longitude: 135.000000'), findsNothing);

    // Trigger parent rebuild (GUI interaction simulation)
    await tester.tap(find.byKey(const Key('rebuild_button')));
    await tester.pumpAndSettle();

    // Verify camera and HUD coordinates did not reset to the initial stale values
    final stateAfter = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controllerAfter = stateAfter.cameraController as CameraController;

    expect(controllerAfter.current.latitude, equals(newLat));
    expect(controllerAfter.current.longitude, equals(newLng));
    expect(find.textContaining('Latitude: 35.000000'), findsNothing);
    expect(find.textContaining('Longitude: 135.000000'), findsNothing);
  });
}
