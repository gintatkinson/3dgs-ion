import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/domain/cesium_3d/projected_point.dart';
import 'package:app_flutter/domain/cesium_3d/tile_fetcher.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';
import 'package:app_flutter/features/topology/topology_map.dart';
import 'package:app_flutter/features/topology/topographical_view.dart';

void main() {
  group('Scene3DViewport Golden Tests', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind('localhost', 0);
      TileFetcher.urlOverride = 'http://localhost:${server.port}';
      server.listen((HttpRequest request) async {
        try {
          File file = File('test/topology/goldens/exaggerated_fuji_node.png');
          if (!file.existsSync()) {
            file = File('/Users/perkunas/jail/3dgs-ion/app_flutter/test/topology/goldens/exaggerated_fuji_node.png');
          }
          final bytes = await file.readAsBytes();
          request.response
            ..headers.contentType = ContentType('image', 'png')
            ..statusCode = HttpStatus.ok;
          request.response.add(bytes);
        } catch (e) {
          request.response.statusCode = HttpStatus.internalServerError;
        } finally {
          await request.response.close();
        }
      });
    });

    tearDown(() async {
      TileFetcher.urlOverride = null;
      await server.close(force: true);
    });

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

      const Size size = Size(800, 600);
      const Offset center = Offset(400, 300);

      final List<(double, double)> locations = [
        (0.0, 0.0),
        (35.441924, 138.848037),
        (-45.0, 90.0),
        (70.0, -120.0),
        (10.0, -45.0),
      ];

      final List<double> altitudes = [100000.0, 10000000.0];
      final List<double> headings = [0.0, 90.0, 180.0, 270.0];
      final List<double> pitches = [-90.0, -45.0, -15.0];

      for (final loc in locations) {
        final double lat = loc.$1;
        final double lng = loc.$2;
        for (final alt in altitudes) {
          for (final heading in headings) {
            for (final pitch in pitches) {
              // Construct the camera with altitude passed as (6378137.0 + alt)
              // to ensure cRad inside the painter matches the mathematical cRad exactly.
              final camera = VirtualCamera.clamped(
                latitude: lat,
                longitude: lng,
                altitude: 6378137.0 + alt,
                heading: heading,
                pitch: pitch,
                roll: 0.0,
              );

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

              final double rotationAngle = - (camera.longitude * math.pi / 180.0);
              final double tilt = - (camera.latitude * math.pi / 180.0);

              // Vector Math
              final double radLat = lat * math.pi / 180.0;
              final double radLng = lng * math.pi / 180.0;
              final double cRad = 6378137.0 + alt;
              final double cx = cRad * math.cos(radLat) * math.cos(radLng);
              final double cy = cRad * math.cos(radLat) * math.sin(radLng);
              final double cz = cRad * math.sin(radLat);

              final double ux = math.cos(radLat) * math.cos(radLng);
              final double uy = math.cos(radLat) * math.sin(radLng);
              final double uz = math.sin(radLat);

              final double ex = -math.sin(radLng);
              final double ey = math.cos(radLng);
              final double ez = 0.0;

              final double nx = -math.sin(radLat) * math.cos(radLng);
              final double ny = -math.sin(radLat) * math.sin(radLng);
              final double nz = math.cos(radLat);

              final double H_rad = heading * math.pi / 180.0;
              final double P_rad = pitch * math.pi / 180.0;
              final double fx = math.sin(H_rad) * math.cos(P_rad);
              final double fy = math.cos(H_rad) * math.cos(P_rad);
              final double fz = math.sin(P_rad);

              final double fx_ecef = fx * ex + fy * nx + fz * ux;
              final double fy_ecef = fx * ey + fy * ny + fz * uy;
              final double fz_ecef = fx * ez + fy * nz + fz * uz;

              final double px_f = cx + 100000.0 * fx_ecef;
              final double py_f = cy + 100000.0 * fy_ecef;
              final double pz_f = cz + 100000.0 * fz_ecef;

              final double px_b = cx - 100000.0 * fx_ecef;
              final double py_b = cy - 100000.0 * fy_ecef;
              final double pz_b = cz - 100000.0 * fz_ecef;

              final double r_f = math.sqrt(px_f * px_f + py_f * py_f + pz_f * pz_f);
              final double lat_f = math.asin(pz_f / r_f);
              final double lng_f = math.atan2(py_f, px_f);
              final double height_f = r_f;

              final double r_b = math.sqrt(px_b * px_b + py_b * py_b + pz_b * pz_b);
              final double lat_b = math.asin(pz_b / r_b);
              final double lng_b = math.atan2(py_b, px_b);
              final double height_b = r_b;

              final forwardProj = painter.project(
                lat_f,
                lng_f,
                height_f,
                center,
                rotationAngle,
                tilt,
                size,
              );

              final backwardProj = painter.project(
                lat_b,
                lng_b,
                height_b,
                center,
                rotationAngle,
                tilt,
                size,
              );

              expect(
                forwardProj.z,
                greaterThan(0.0),
                reason: 'Forward point not projected for Lat:$lat, Lng:$lng, Alt:$alt, H:$heading, P:$pitch',
              );
              expect(
                backwardProj.z < 0.0 || backwardProj.z == -1.0,
                isTrue,
                reason: 'Backward point not culled (z = ${backwardProj.z}) for Lat:$lat, Lng:$lng, Alt:$alt, H:$heading, P:$pitch',
              );
            }
          }
        }
      }
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

    testWidgets('Visual Test 5 - Correct Ground, Raised Point, and Space Point Altitude Projection', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 35.18,
        longitude: 136.90,
        altitude: 20000000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );

      final topologyData = TopologyData(
        coordinateMapping: const {},
        nodes: [
          TopologyNode(
            id: 'PointA',
            label: 'PointA',
            position: const TopologyNodePosition(
              dim0: 136.90,
              dim1: 35.18,
              dim2: 0.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {'type': 'ground'},
          ),
          TopologyNode(
            id: 'PointB',
            label: 'PointB',
            position: const TopologyNodePosition(
              dim0: 136.90,
              dim1: 35.18,
              dim2: 100.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {'type': 'ground'},
          ),
          TopologyNode(
            id: 'PointC',
            label: 'PointC',
            position: const TopologyNodePosition(
              dim0: 0.0,
              dim1: 0.0,
              dim2: 1000000.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {'type': 'space'},
          ),
        ],
        links: const [],
      );

      final painter = _TestViewportPainter(
        camera: camera,
        elevationActive: true,
        verticalExaggeration: 10.0,
        topologyData: topologyData,
      );

      final canvas = _FakeCanvas();
      painter.paint(canvas, const Size(800, 600));

      // Assert geocentric heights
      expect(painter.capturedHeights['point_a_group'], isNotNull);
      expect(painter.capturedHeights['point_a_group']!.length, equals(2));
      
      final double terrainElev = painter.getElevation(35.18, 136.90);
      final double verticalExaggeration = 10.0;
      final double expectedPointAHeight = 6378137.0 + terrainElev * verticalExaggeration;
      final double expectedPointBHeight = 6378137.0 + terrainElev * verticalExaggeration + 100.0;
      
      expect(painter.capturedHeights['point_a_group']![0], closeTo(expectedPointAHeight, 1e-4));
      expect(painter.capturedHeights['point_a_group']![1], closeTo(expectedPointBHeight, 1e-4));
      
      expect(painter.capturedHeights['point_c'], isNotNull);
      expect(painter.capturedHeights['point_c']!.any((h) => (h - (6378137.0 + 1000000.0)).abs() < 1e-4), isTrue);

      // Verify PointA is classified as ground when rendering
      final double rotationAngle = - (camera.longitude * math.pi / 180.0);
      final double tilt = - (camera.latitude * math.pi / 180.0);
      const Size size = Size(800, 600);
      final Offset center = Offset(size.width * 0.45, size.height * 0.5);
      final double currentLng = PointALngRad + rotationAngle * 0.0; // speed = 0.0
      final pointAProj = painter.project(
        PointALatRad,
        currentLng,
        expectedPointAHeight,
        center,
        rotationAngle,
        tilt,
        size,
      );

      final pointAOffset = pointAProj.offset;
      final bool hasUnderwaterCircle = canvas.circles.any((c) => (c.$1 - pointAOffset).distance < 1e-3 && (c.$2 - 7.5).abs() < 1e-3);
      expect(hasUnderwaterCircle, isFalse, reason: 'PointA should not be classified/drawn as underwater');

      final bool hasGroundPoint = canvas.points.any((pts) => pts.any((p) => (p - pointAOffset).distance < 1e-3));
      expect(hasGroundPoint, isTrue, reason: 'PointA should be classified/drawn as a ground node');
    });

    testWidgets('Test Case 1 - Layout Stack Check', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 35.18,
        longitude: 136.90,
        altitude: 20000000.0,
        heading: 0.0,
        pitch: -90.0,
        roll: 0.0,
      );

      final topologyData = TopologyData(
        coordinateMapping: const {},
        nodes: const [],
        links: const [],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(_FakeThemeService()),
          child: MaterialApp(
            home: Scaffold(
              body: TopographicalView(
                currentView: 'GS-Tokyo',
                onViewSelected: (_) {},
                topologyData: topologyData,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In 3D mode (default), Scene3DViewport should exist
      expect(find.byType(Scene3DViewport), findsOneWidget);

      // Verify no 2D Map controllers leak in the stack
      expect(find.byKey(const ValueKey<String>('playPauseButton')), findsNothing);
      expect(find.byKey(const ValueKey<String>('timeSlider')), findsNothing);
      expect(find.byKey(const ValueKey<String>('speedDropdown')), findsNothing);
    });

    testWidgets('Test Case 2 - Warped Horizon Snapping', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 10000000.0, // outside Earth
        heading: 0.0,
        pitch: -90.0,
        roll: 0.0,
      );
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
      const size = Size(800, 600);
      final center = Offset(400, 300);
      final double rotationAngle = 0.0;
      final double tilt = 0.0;

      final double lat = 0.0;
      final double lng = math.pi; // back side (culled)
      final double height = 6378137.0 + 1000.0;

      final projClamped = painter.project(lat, lng, height, center, rotationAngle, tilt, size, clampToHorizon: true);
      final projNatural = painter.project(lat, lng, height, center, rotationAngle, tilt, size, clampToHorizon: false);

      // Verify that when clampToHorizon is false, we get different projected coordinates (natural coords, not snapped)
      expect(projClamped.offset, isNot(equals(projNatural.offset)));
      expect(projNatural.z, lessThan(0.0));
    });

    testWidgets('Test Case 3 - Subsurface Occlusion Culling', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 6378137.0 + 100000.0, // camera outside Earth
        heading: 0.0,
        pitch: -90.0,
        roll: 0.0,
      );
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
      const size = Size(800, 600);
      final center = Offset(400, 300);
      final double rotationAngle = 0.0;
      final double tilt = 0.0;

      // Subsurface point facing camera (lat: 0, lng: 0, height < R)
      final double lat = 0.0;
      final double lng = 0.0;
      final double height = 6378137.0 - 5000.0;

      final proj = painter.project(lat, lng, height, center, rotationAngle, tilt, size);

      // Must be culled (z < 0)
      expect(proj.z, lessThan(0.0));
    });

    testWidgets('Test Case 4 - Node-to-Overlay Alignment', (WidgetTester tester) async {
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
              dim0: 138.7274,
              dim1: 35.3606,
              dim2: 100.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {'type': 'ground'},
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
              verticalExaggeration: 2.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(Scene3DViewport)) as Scene3DViewportState;
      final Offset projected = state.getProjectedPosition(
        35.3606,
        138.7274,
        altitude: 100.0,
        nodeType: 'ground',
      );

      final double latRad = 35.3606 * math.pi / 180.0;
      final double lngRad = 138.7274 * math.pi / 180.0;
      final double terrainElev = Scene3DViewportPainter.getElevationStatic(35.3606, 138.7274, true);
      final double expectedHeight = 6378137.0 + terrainElev * 2.0 + 100.0;

      final Size size = tester.getSize(find.byType(Scene3DViewport));
      final Offset center = Offset(size.width * 0.45, size.height * 0.5);
      final double rotationAngle = -(camera.longitude * math.pi / 180.0);
      final double tilt = -(camera.latitude * math.pi / 180.0);

      final painter = Scene3DViewportPainter(
        camera: camera,
        activeStyle: 'Satellite Map',
        astronomicalBody: 'Earth',
        elevationActive: true,
        showDevices: true,
        showLinks: true,
        showLabels: true,
        showDropLines: true,
        userRotationX: 0.0,
        userTilt: 0.0,
        zoomScale: 6378137.0 / camera.altitude,
        verticalExaggeration: 2.0,
      );

      final expectedProj = painter.project(
        latRad,
        lngRad,
        expectedHeight,
        center,
        rotationAngle,
        tilt,
        size,
      );

      expect(projected, equals(expectedProj.offset));
    });

    testWidgets('Test Case 5 - Airborne Node Exaggeration', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 35.3606,
        longitude: 138.7274,
        altitude: 1000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );

      final topologyData = TopologyData(
        coordinateMapping: const {},
        nodes: [
          TopologyNode(
            id: 'Meteor-1',
            label: 'Meteor-1',
            position: const TopologyNodePosition(
              dim0: 138.7274,
              dim1: 35.3606,
              dim2: 50000.0,
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {'type': 'METEOR'},
          ),
        ],
        links: const [],
      );

      final painter = _TestViewportPainter(
        camera: camera,
        elevationActive: true,
        verticalExaggeration: 10.0,
        topologyData: topologyData,
      );

      final canvas = _FakeCanvas();
      painter.paint(canvas, const Size(800, 600));

      expect(painter.capturedHeights['meteor_group'], isNotNull);
      expect(painter.capturedHeights['meteor_group']![0], closeTo(6378137.0 + 50000.0, 1e-4));
    });

    testWidgets('Test Case 6 - Dynamic Horizon Snapping Verification', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 0.0,
        longitude: 0.0,
        altitude: 10000000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );

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

      final double lat = 0.0;
      final double lng = 2.0; // Off-axis culled longitude to ensure non-zero perpendicular component
      final double H = 6378137.0 + 200000.0; // Point height
      final double d = 10000000.0; // Camera altitude

      final (px, py, pz) = painter.getSnappedEcefCoordinatesForTesting(lat, lng, H, d);

      // 1. Geocentric distance must be precisely H
      final double geocentricDist = math.sqrt(px * px + py * py + pz * pz);
      expect(geocentricDist, closeTo(H, 1e-4));

      // 2. Snapped distance from the camera center line
      final double h2 = H * H;
      final double d2 = d * d;
      final double r2_over_d2 = h2 / d2;
      final double cx = d;
      final double cy = 0.0;
      final double cz = 0.0;
      final double parX = r2_over_d2 * cx;
      final double parY = r2_over_d2 * cy;
      final double parZ = r2_over_d2 * cz;

      final double dx = px - parX;
      final double dy = py - parY;
      final double dz = pz - parZ;
      final double planeDist = math.sqrt(dx * dx + dy * dy + dz * dz);

      final double expectedPlaneDist = H * math.sqrt(1.0 - h2 / d2);
      expect(planeDist, closeTo(expectedPlaneDist, 1e-4));
    });

    testWidgets('Test Case 7 - Node Elevation Classification Fallback Defaulting', (WidgetTester tester) async {
      final camera = VirtualCamera.clamped(
        latitude: 35.3606,
        longitude: 138.7274,
        altitude: 1000.0,
        heading: 0,
        pitch: -90,
        roll: 0,
      );

      final topologyData = TopologyData(
        coordinateMapping: const {},
        nodes: [
          TopologyNode(
            id: 'SpaceNode-1',
            label: 'SpaceNode-1',
            position: const TopologyNodePosition(
              dim0: 138.7274,
              dim1: 35.3606,
              dim2: 50000.0, // alt >= 50000.0 -> space fallback
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {},
          ),
          TopologyNode(
            id: 'GroundNode-1',
            label: 'GroundNode-1',
            position: const TopologyNodePosition(
              dim0: 138.7274,
              dim1: 35.3606,
              dim2: 1000.0, // alt < 50000.0 -> ground fallback
              timeIndex: 0,
              vector: [],
            ),
            status: 'Active',
            rawProperties: const {},
          ),
        ],
        links: const [],
      );

      final painter = _TestViewportPainter(
        camera: camera,
        elevationActive: true,
        verticalExaggeration: 10.0,
        topologyData: topologyData,
      );

      final canvas = _FakeCanvas();
      painter.paint(canvas, const Size(800, 600));

      expect(painter.capturedHeights['fuji_group'], isNotNull);
      final heights = painter.capturedHeights['fuji_group']!;
      expect(heights.length, equals(3));

      final double expectedSpaceHeight = 6378137.0 + 50000.0;
      final double terrainElev = painter.getElevation(35.3606, 138.7274);
      final double expectedGroundHeight = 6378137.0 + terrainElev * 10.0 + 1000.0;

      expect(heights, contains(closeTo(expectedSpaceHeight, 1e-4)));
      expect(heights, contains(closeTo(expectedGroundHeight, 1e-4)));
    });
  });
}

const double PointALatRad = 35.18 * math.pi / 180.0;
const double PointALngRad = 136.90 * math.pi / 180.0;

class _FakeCanvas extends Fake implements Canvas {
  final List<(Offset, double)> circles = [];
  final List<List<Offset>> points = [];

  @override
  void drawCircle(Offset center, double radius, Paint paint) {
    circles.add((center, radius));
  }

  @override
  void drawPoints(PointMode pointMode, List<Offset> pointsList, Paint paint) {
    points.add(List.from(pointsList));
  }

  @override
  void drawParagraph(Paragraph paragraph, Offset offset) {}

  @override
  void drawPath(Path path, Paint paint) {}

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {}

  @override
  void drawRRect(RRect rrect, Paint paint) {}

  @override
  void save() {}

  @override
  void translate(double dx, double dy) {}

  @override
  void rotate(double radians) {}

  @override
  void restore() {}
}

class _TestViewportPainter extends Scene3DViewportPainter {
  final Map<String, List<double>> capturedHeights = {};

  _TestViewportPainter({
    required super.camera,
    required super.elevationActive,
    required super.verticalExaggeration,
    super.topologyData,
  }) : super(
          activeStyle: 'dark',
          astronomicalBody: 'Earth',
          showDevices: true,
          showLinks: true,
          showLabels: true,
          showDropLines: true,
          userRotationX: 0.0,
          userTilt: 0.0,
          zoomScale: 1.0,
        );

  @override
  ProjectedPoint project(
    double lat,
    double lng,
    double height,
    Offset center,
    double rotationY,
    double tilt,
    Size size, {
    bool clampToHorizon = true,
  }) {
    final double latDeg = lat * 180.0 / math.pi;
    final double lngDeg = lng * 180.0 / math.pi;

    if ((latDeg - 35.18).abs() < 1e-3 && (lngDeg - 136.90).abs() < 1e-3) {
      capturedHeights.putIfAbsent('point_a_group', () => []).add(height);
    } else if (latDeg.abs() < 1e-3 && lngDeg.abs() < 1e-3) {
      capturedHeights.putIfAbsent('point_c', () => []).add(height);
    } else if ((latDeg - 35.3606).abs() < 1e-3 && (lngDeg - 138.7274).abs() < 1e-3 && height > 6378137.0 + 40000.0) {
      capturedHeights.putIfAbsent('meteor_group', () => []).add(height);
    }

    if ((latDeg - 35.3606).abs() < 1e-3 && (lngDeg - 138.7274).abs() < 1e-3) {
      capturedHeights.putIfAbsent('fuji_group', () => []).add(height);
    }

    return super.project(lat, lng, height, center, rotationY, tilt, size, clampToHorizon: clampToHorizon);
  }
}

class _FakeThemeService implements ThemeService {
  @override
  Future<ThemeMode> loadThemeMode() async => ThemeMode.system;
  @override
  Future<void> saveThemeMode(ThemeMode mode) async {}
  @override
  Future<int> loadThemeScheme() async => 0;
  @override
  Future<void> saveThemeScheme(int scheme) async {}
  @override
  Future<double> loadTextScale() async => 1.0;
  @override
  Future<void> saveTextScale(double scale) async {}
  @override
  Future<Axis> loadLayoutSplitAxis() async => Axis.vertical;
  @override
  Future<void> saveLayoutSplitAxis(Axis axis) async {}
  @override
  Future<double> loadPanelOpacity() async => 0.85;
  @override
  Future<void> savePanelOpacity(double opacity) async {}
}
