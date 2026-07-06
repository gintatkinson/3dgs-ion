import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Issue #43: Globe focus and arrow keys navigation', (WidgetTester tester) async {
    final camera = VirtualCamera(
      latitude: 35.0,
      longitude: 135.0,
      altitude: 1000.0,
      heading: 0.0,
      pitch: -45.0,
      roll: 0.0,
    );

    // Build the viewport inside a scrollable ancestor to ensure arrow keys are not intercepted
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              height: 800,
              width: 800,
              child: Scene3DViewport(
                camera: camera,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
    final CameraController controller = state.cameraController as CameraController;

    // Verify initial values
    expect(controller.current.heading, 0.0);
    expect(controller.current.pitch, -45.0);

    // Ensure the viewport focus node is focused
    final FocusNode focusNode = state.globeFocusNode as FocusNode;
    expect(focusNode.hasFocus, isTrue);

    // Press Arrow Up key
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(controller.current.pitch, greaterThan(-45.0));

    // Press Arrow Down key
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(controller.current.pitch, equals(-45.0));

    // Press Arrow Left key
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.current.longitude, lessThan(135.0));

    // Press Arrow Right key
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(controller.current.longitude, equals(135.0));

    // Hold Shift and press Arrow Left key (should rotate heading, longitude stays 135.0)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.current.longitude, equals(135.0));
    expect(controller.current.heading, greaterThan(0.0));

    // Hold Shift and press Arrow Right key (should rotate heading back to 0)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(controller.current.longitude, equals(135.0));
    expect(controller.current.heading, equals(0.0));
  });
}
