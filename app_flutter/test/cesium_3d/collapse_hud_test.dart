import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  testWidgets('Collapse and expand HUD panels in Scene3DViewport', (WidgetTester tester) async {
    final camera = VirtualCamera(
      latitude: 35.0,
      longitude: 135.0,
      altitude: 1000.0,
      heading: 0.0,
      pitch: -45.0,
      roll: 0.0,
    );

    // Build the viewport widget
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

    // 1. Initial State: both panels are expanded (visible)
    expect(find.textContaining('CAMERA STATS'), findsOneWidget);
    expect(find.textContaining('MAP CONFIGURATION'), findsOneWidget);
    expect(find.byKey(const Key('collapse_camera_stats_button')), findsOneWidget);
    expect(find.byKey(const Key('collapse_map_config_button')), findsOneWidget);

    // Expand buttons are not visible initially
    expect(find.byKey(const Key('expand_camera_stats_button')), findsNothing);
    expect(find.byKey(const Key('expand_map_config_button')), findsNothing);

    // 2. Collapse Camera Stats
    await tester.tap(find.byKey(const Key('collapse_camera_stats_button')));
    await tester.pump(const Duration(seconds: 1));

    // Verify Camera Stats panel is hidden and expand button is visible
    expect(find.textContaining('CAMERA STATS'), findsNothing);
    expect(find.byKey(const Key('expand_camera_stats_button')), findsOneWidget);
    expect(find.byKey(const Key('collapse_camera_stats_button')), findsNothing);

    // Map Configuration should still be expanded
    expect(find.textContaining('MAP CONFIGURATION'), findsOneWidget);

    // 3. Collapse Map Configuration
    await tester.tap(find.byKey(const Key('collapse_map_config_button')));
    await tester.pump(const Duration(seconds: 1));

    // Verify Map Configuration panel is hidden and expand button is visible
    expect(find.textContaining('MAP CONFIGURATION'), findsNothing);
    expect(find.byKey(const Key('expand_map_config_button')), findsOneWidget);
    expect(find.byKey(const Key('collapse_map_config_button')), findsNothing);

    // 4. Expand Camera Stats
    await tester.tap(find.byKey(const Key('expand_camera_stats_button')));
    await tester.pump(const Duration(seconds: 1));

    // Verify Camera Stats panel is restored
    expect(find.textContaining('CAMERA STATS'), findsOneWidget);
    expect(find.byKey(const Key('expand_camera_stats_button')), findsNothing);
    expect(find.byKey(const Key('collapse_camera_stats_button')), findsOneWidget);

    // 5. Expand Map Configuration
    await tester.tap(find.byKey(const Key('expand_map_config_button')));
    await tester.pump(const Duration(seconds: 1));

    // Verify Map Configuration panel is restored
    expect(find.textContaining('MAP CONFIGURATION'), findsOneWidget);
    expect(find.byKey(const Key('expand_map_config_button')), findsNothing);
    expect(find.byKey(const Key('collapse_map_config_button')), findsOneWidget);
  });
}
