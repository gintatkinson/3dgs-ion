import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';
import 'package:app_flutter/features/topology/topology_map.dart';

void main() {
  group('Scene3DViewport Golden Tests', () {
    testWidgets('Visual Test 1 - Stars and Sphere View', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 20000000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Scene3DViewport(
              camera: camera,
              topologyData: const TopologyData(
                coordinateMapping: {},
                nodes: [],
                links: [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scene3DViewport),
        matchesGoldenFile('goldens/stars_and_sphere.png'),
      );
    });

    testWidgets('Visual Test 2 - Exaggerated Node Elevation Alignment', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final camera = VirtualCamera.clamped(
        latitude: 35.3606,
        longitude: 138.7274,
        altitude: 1000.0,
        heading: 0,
        pitch: -45,
        roll: 0,
      );

      final topologyData = TopologyData(
        coordinateMapping: const {},
        nodes: [
          TopologyNode(
            id: 'Fuji',
            label: 'Fuji',
            position: const TopologyNodePosition(
              dim0: 138.7274, // longitude
              dim1: 35.3606,  // latitude
              dim2: 0.0,      // alt
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
          ),
        ],
        links: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Scene3DViewport(
              camera: camera,
              topologyData: topologyData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scene3DViewport),
        matchesGoldenFile('goldens/exaggerated_fuji_node.png'),
      );
    });

    testWidgets('Visual Test 3 - Forward/Backward Projection Inversion Culling', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final camera = VirtualCamera.clamped(
        latitude: 35.441924,
        longitude: 138.848037,
        altitude: 90635.83,
        heading: 56.65,
        pitch: -19.79,
        roll: 0.0,
      );

      // Perform non-visual coordinate projection checks directly on the Scene3DViewportPainter
      final painter = Scene3DViewportPainter(
        camera: camera,
        activeStyle: 'dark',
        astronomicalBody: 'Earth',
        elevationActive: false,
        showDevices: true,
        showLinks: true,
        showLabels: true,
        showDropLines: true,
        userRotationX: 0.0,
        userTilt: 0.0,
        zoomScale: 1.0,
        verticalExaggeration: 1.0,
      );

      const double R = 6378137.0;
      const Size size = Size(800, 600);
      const Offset center = Offset(400, 300);

      final double rotationAngle = - (camera.longitude * math.pi / 180.0);
      final double tilt = - (camera.latitude * math.pi / 180.0);

      final nagoyaProj = painter.project(
        35.18 * math.pi / 180.0,
        136.90 * math.pi / 180.0,
        R + 0.0,
        center,
        rotationAngle,
        tilt,
        size,
      );

      final tokyoProj = painter.project(
        36.00 * math.pi / 180.0,
        140.00 * math.pi / 180.0,
        R + 0.0,
        center,
        rotationAngle,
        tilt,
        size,
      );

      // Assert correct behavior: Nagoya (Southwest, behind) is culled; Tokyo (Northeast, in front) is projected.
      expect(nagoyaProj.z, lessThan(0.0));
      expect(tokyoProj.z, greaterThan(0.0));

      // Widget visual test
      final topologyData = TopologyData(
        coordinateMapping: const {},
        nodes: [
          TopologyNode(
            id: 'Nagoya-OPT-Core',
            label: 'Nagoya-OPT-Core',
            position: const TopologyNodePosition(
              dim0: 136.90, // longitude
              dim1: 35.18,  // latitude
              dim2: 0.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
          ),
          TopologyNode(
            id: 'Tokyo-OPT-Core',
            label: 'Tokyo-OPT-Core',
            position: const TopologyNodePosition(
              dim0: 140.00, // longitude
              dim1: 36.00,  // latitude
              dim2: 0.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
          ),
        ],
        links: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Scene3DViewport(
              camera: camera,
              topologyData: topologyData,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scene3DViewport),
        matchesGoldenFile('goldens/correct_view_culling.png'),
      );
    });

    testWidgets('Visual Test 4 - Double Elevation Verification', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 35.0,
        longitude: 135.0,
        altitude: 1000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );

      final painter = Scene3DViewportPainter(
        camera: camera,
        activeStyle: 'dark',
        astronomicalBody: 'Earth',
        elevationActive: true,
        showDevices: true,
        showLinks: true,
        showLabels: true,
        showDropLines: true,
        userRotationX: 0.0,
        userTilt: 0.0,
        zoomScale: 1.0,
        verticalExaggeration: 1.0,
      );

      // 1. Check at (135.0, 35.0)
      final double latRad = 35.0 * math.pi / 180.0;
      final double lngRad = 135.0 * math.pi / 180.0;
      final double height = 6378137.0 + 800.0;

      final (px, py, pz) = painter.getEcefCoordinatesForTesting(latRad, lngRad, height);
      final double magnitude = math.sqrt(px * px + py * py + pz * pz);
      expect(magnitude, closeTo(6378137.0 + 800.0, 1e-4));

      // 2. Check at (138.0, 35.0) where elevation is non-zero
      final double latRad2 = 35.0 * math.pi / 180.0;
      final double lngRad2 = 138.0 * math.pi / 180.0;
      final (px2, py2, pz2) = painter.getEcefCoordinatesForTesting(latRad2, lngRad2, height);
      final double magnitude2 = math.sqrt(px2 * px2 + py2 * py2 + pz2 * pz2);
      expect(magnitude2, closeTo(6378137.0 + 800.0, 1e-4));
    });
  });
}
