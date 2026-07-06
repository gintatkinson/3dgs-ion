import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';
import 'package:app_flutter/domain/cesium_3d/camera_controller.dart';
import 'package:app_flutter/domain/cesium_3d/virtual_camera.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';
import 'package:app_flutter/features/topology/topographical_view.dart';
import 'package:app_flutter/features/topology/topology_map.dart';

class FakeThemeService implements ThemeService {
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

// dim0 = longitude (x), dim1 = latitude (y) per resolveCoordinate
const _topologyData = TopologyData(
  coordinateMapping: {},
  nodes: <TopologyNode>[
    TopologyNode(
      id: 'ViewA',
      label: 'View A',
      position: TopologyNodePosition(
        dim0: 140.0, // longitude (x)
        dim1: 35.0,  // latitude (y)
        dim2: 0.0,
        timeIndex: 0,
        vector: [],
      ),
      status: 'Active',
    ),
    TopologyNode(
      id: 'ViewB',
      label: 'View B',
      position: TopologyNodePosition(
        dim0: -75.0, // longitude (x)
        dim1: 50.0,   // latitude (y)
        dim2: 0.0,
        timeIndex: 0,
        vector: [],
      ),
      status: 'Active',
    ),
  ],
  links: [],
);

class _ParentWrapper extends StatefulWidget {
  final String currentView;
  final ValueChanged<String> onViewSelected;
  final TopologyData topologyData;

  const _ParentWrapper({
    super.key,
    required this.currentView,
    required this.onViewSelected,
    required this.topologyData,
  });

  @override
  State<_ParentWrapper> createState() => _ParentWrapperState();
}

class _ParentWrapperState extends State<_ParentWrapper> {
  String _currentView = 'ViewA';

  @override
  void initState() {
    super.initState();
    _currentView = widget.currentView;
  }

  @override
  void didUpdateWidget(_ParentWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentView != oldWidget.currentView) {
      setState(() {
        _currentView = widget.currentView;
      });
    }
  }

  void forceViewChange(String newView) {
    if (mounted) {
      setState(() {
        _currentView = newView;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeController>(
      create: (_) => ThemeController(FakeThemeService()),
      child: MaterialApp(
        home: Scaffold(
          body: TopographicalView(
            currentView: _currentView,
            onViewSelected: widget.onViewSelected,
            topologyData: widget.topologyData,
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Camera reset reproduction (Issue #50)', () {
    VirtualCamera _makeCamera(double lat, double lng) {
      return VirtualCamera(
        latitude: lat,
        longitude: lng,
        altitude: 500.0,
        heading: 0.0,
        pitch: -45.0,
        roll: 0.0,
      );
    }

    Future<_ParentWrapperState> _pumpTopographicalView(
      WidgetTester tester, {
      String startView = 'ViewA',
    }) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _ParentWrapper(
          currentView: startView,
          onViewSelected: (_) {},
          topologyData: _topologyData,
        ),
      );
      await tester.pumpAndSettle();

      return tester.state(find.byType(_ParentWrapper));
    }

    CameraController _findCameraController(WidgetTester tester) {
      expect(find.byType(Scene3DViewport), findsOneWidget);
      final state = tester.state(find.byType(Scene3DViewport)) as dynamic;
      return state.cameraController as CameraController;
    }

    testWidgets(
      'Camera resets when parent rebuild changes currentView to a different node',
      (WidgetTester tester) async {
        final wrapperState = await _pumpTopographicalView(tester, startView: 'ViewA');

        final CameraController controller = _findCameraController(tester);

        // Verify initial camera is at ViewA coordinates (dim1=35.0 latency, dim0=140.0 lng)
        expect(controller.current.latitude, 35.0);
        expect(controller.current.longitude, 140.0);

        // Simulate user panning: move the camera
        controller.pan(const Offset(-100, 0));
        final double pannedLongitude = controller.current.longitude;
        expect(pannedLongitude, greaterThan(140.0),
            reason: 'Camera should have panned right');

        // Simulate what _LayoutState._updateCurrentViewFromLayout() does:
        // silently changes _currentView to the first tree node
        // This represents the TreeViewModel notification path
        wrapperState.forceViewChange('ViewB');
        await tester.pumpAndSettle();

        // BUG: Camera should be at ViewB coordinates (50.0, -75.0),
        // discarding the user's pan
        final CameraController afterController = _findCameraController(tester);
        expect(afterController.current.latitude, 50.0,
            reason: 'BUG: Camera reset to ViewB latitude, discarding user pan');
        expect(afterController.current.longitude, -75.0,
            reason: 'BUG: Camera reset to ViewB longitude, discarding user pan');
        expect(afterController.current.latitude, isNot(35.0),
            reason: 'Camera moved to new node — but pan was discarded');
      });

    testWidgets(
      'Camera state is preserved when currentView does not change during parent rebuild',
      (WidgetTester tester) async {
        final wrapperState = await _pumpTopographicalView(tester, startView: 'ViewA');
        final CameraController controller = _findCameraController(tester);

        // Pan the camera
        controller.pan(const Offset(-50, -50));
        final double pannedLat = controller.current.latitude;
        final double pannedLng = controller.current.longitude;

        // Force a rebuild without changing the view
        // (simulates a TreeViewModel notification when _currentView doesn't change)
        wrapperState.forceViewChange('ViewA');
        await tester.pumpAndSettle();

        final CameraController afterController = _findCameraController(tester);
        expect(afterController.current.latitude, pannedLat,
            reason: 'Camera latitude should be preserved when view is unchanged');
        expect(afterController.current.longitude, pannedLng,
            reason: 'Camera longitude should be preserved when view is unchanged');
      });

    testWidgets(
      'didUpdateWidget in Scene3DViewport overwrites camera when widget.camera differs',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final originalCam = _makeCamera(35.0, 135.0);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Scene3DViewport(
                camera: originalCam,
                topologyData: _topologyData,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final CameraController controller = _findCameraController(tester);

        // Pan to a different position
        controller.pan(const Offset(-200, -100));
        expect(controller.current.longitude, isNot(135.0));

        // Parent rebuild passes a NEW camera instance with different values
        // (simulating what _resolveCamera does after view change)
        final newCam = _makeCamera(50.0, -75.0);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Scene3DViewport(
                camera: newCam,
                topologyData: _topologyData,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // BUG: Camera was overwritten to the new camera values
        final CameraController afterController = _findCameraController(tester);
        expect(afterController.current.latitude, 50.0);
        expect(afterController.current.longitude, -75.0);
      });

    testWidgets(
      'didUpdateWidget preserves camera when widget.camera is unchanged',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final initialCam = VirtualCamera.clamped(
          latitude: 35.0,
          longitude: 135.0,
          altitude: 500.0,
          heading: 0.0,
          pitch: -45.0,
          roll: 0.0,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Scene3DViewport(
                camera: initialCam,
                topologyData: _topologyData,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final CameraController controller = _findCameraController(tester);
        controller.pan(const Offset(-200, 0));
        final double pannedLng = controller.current.longitude;

        // Rebuild with the same camera values (not reference, but equal by value)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Scene3DViewport(
                camera: VirtualCamera.clamped(
                  latitude: 35.0,
                  longitude: 135.0,
                  altitude: 500.0,
                  heading: 0.0,
                  pitch: -45.0,
                  roll: 0.0,
                ),
                topologyData: _topologyData,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final CameraController afterController = _findCameraController(tester);
        expect(afterController.current.longitude, pannedLng,
            reason: 'Camera state should be preserved when widget camera is value-equal');
      });

    testWidgets(
      'Camera is preserved after tree notification (simulating expand/collapse)',
      (WidgetTester tester) async {
        final wrapperState = await _pumpTopographicalView(tester, startView: 'ViewB');
        final CameraController controller = _findCameraController(tester);

        expect(controller.current.latitude, 50.0);
        expect(controller.current.longitude, -75.0);

        controller.pan(const Offset(-150, 0));
        final double pannedLat = controller.current.latitude;
        final double pannedLng = controller.current.longitude;

        wrapperState.forceViewChange('ViewB');
        await tester.pumpAndSettle();

        final CameraController afterController = _findCameraController(tester);
        expect(afterController.current.latitude, pannedLat,
            reason: 'Camera latitude preserved after tree notification');
        expect(afterController.current.longitude, pannedLng,
            reason: 'Camera longitude preserved after tree notification');
      });

    testWidgets(
      'currentView is NOT overwritten on subsequent tree notifications',
      (WidgetTester tester) async {
        final wrapperState = await _pumpTopographicalView(tester, startView: 'ViewA');
        final CameraController controller = _findCameraController(tester);

        wrapperState.forceViewChange('ViewB');
        await tester.pumpAndSettle();

        final CameraController afterNavController = _findCameraController(tester);
        expect(afterNavController.current.latitude, 50.0);
        expect(afterNavController.current.longitude, -75.0);

        final CameraController ctrl = _findCameraController(tester);
        ctrl.pan(const Offset(-100, -50));
        final double pannedLat = ctrl.current.latitude;
        final double pannedLng = ctrl.current.longitude;

        wrapperState.forceViewChange('ViewB');
        await tester.pumpAndSettle();

        final CameraController afterController = _findCameraController(tester);
        expect(afterController.current.latitude, pannedLat,
            reason: 'currentView NOT overwritten to ViewA by tree notification');
        expect(afterController.current.longitude, pannedLng,
            reason: 'currentView NOT overwritten to ViewA by tree notification');
        expect(afterController.current.latitude, isNot(35.0),
            reason: 'Camera should NOT have reset to ViewA (first tree node)');
        expect(afterController.current.longitude, isNot(140.0),
            reason: 'Camera should NOT have reset to ViewA (first tree node)');
      });

    testWidgets(
      'Initial view selection still works correctly on first launch',
      (WidgetTester tester) async {
        await _pumpTopographicalView(tester, startView: 'ViewB');
        final CameraController controller = _findCameraController(tester);

        expect(controller.current.latitude, 50.0,
            reason: 'Initial camera should be at ViewB latitude');
        expect(controller.current.longitude, -75.0,
            reason: 'Initial camera should be at ViewB longitude');
        expect(controller.current.latitude, isNot(35.0),
            reason: 'Initial camera should NOT be at ViewA when ViewB is specified');
      });
  });

  group('_resolveCamera coordinate resolution', () {
    testWidgets(
      'resolves camera from topology node coordinates via resolveCoordinate',
      (WidgetTester tester) async {
        const data = TopologyData(
          coordinateMapping: {},
          nodes: [
            TopologyNode(
              id: 'TestNode',
              label: 'Test',
              position: TopologyNodePosition(
                dim0: 50.0,
                dim1: -75.0,
                dim2: 0.0,
                timeIndex: 0,
                vector: [],
              ),
              status: 'Active',
            ),
          ],
          links: [],
        );

        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController(FakeThemeService()),
            child: MaterialApp(
              home: Scaffold(
                body: TopographicalView(
                  currentView: 'TestNode',
                  onViewSelected: (_) {},
                  topologyData: data,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final viewportState = tester.state(find.byType(Scene3DViewport)) as dynamic;
        final CameraController controller = viewportState.cameraController as CameraController;

        expect(controller.current.latitude, -75.0);
        expect(controller.current.longitude, 50.0);
        expect(controller.current.altitude, 500.0);
        expect(controller.current.heading, 0.0);
        expect(controller.current.pitch, -89.9);
      });
  });
}
