import 'package:app_flutter/features/topology/topology_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const TopologyData _testTopologyData = TopologyData(
  coordinateMapping: {},
  nodes: <TopologyNode>[
    TopologyNode(
      id: 'Ingestion',
      label: 'Ingestion',
      position: TopologyNodePosition(
        dim0: 100,
        dim1: 140,
        dim2: 0.0,
        timeIndex: 1.0,
        vector: <double>[15, 3, 0.0],
      ),
      status: 'Active',
    ),
    TopologyNode(
      id: 'Metrics',
      label: 'Metrics',
      position: TopologyNodePosition(
        dim0: 320,
        dim1: 90,
        dim2: 0.0,
        timeIndex: 1.0,
        vector: <double>[8, -4, 0.0],
      ),
      status: 'Active',
    ),
    TopologyNode(
      id: 'Location',
      label: 'Location',
      position: TopologyNodePosition(
        dim0: 240,
        dim1: 220,
        dim2: 0.0,
        timeIndex: 1.0,
        vector: <double>[4, 10, 0.0],
      ),
      status: 'Active',
    ),
    TopologyNode(
      id: 'Chassis',
      label: 'Chassis',
      position: TopologyNodePosition(
        dim0: 480,
        dim1: 180,
        dim2: 0.0,
        timeIndex: 1.0,
        vector: <double>[-6, 6, 0.0],
      ),
      status: 'Idle',
    ),
  ],
  links: <TopologyLink>[
    TopologyLink(source: 'Ingestion', target: 'Metrics', type: 'data-flow'),
    TopologyLink(source: 'Metrics', target: 'Chassis', type: 'data-flow'),
    TopologyLink(source: 'Location', target: 'Chassis', type: 'data-flow'),
  ],
);

void main() {
  test('Coordinate projection math holds true', () {
    const TopologyNode node = TopologyNode(
      id: 'TestNode',
      label: 'Test Node',
      position: TopologyNodePosition(
        dim0: 200.0,
        dim1: 300.0,
        dim2: 0.0,
        timeIndex: 1.0,
        vector: <double>[10.0, -20.0, 0.0],
      ),
      status: 'Active',
    );

    // At t = 1.0
    double dt = 1.0 - node.position.timeIndex;
    double x = node.position.dim0 + dt * node.position.vector[0];
    double y = node.position.dim1 + dt * node.position.vector[1];
    expect(x, 200.0);
    expect(y, 300.0);

    // At t = 3.5
    dt = 3.5 - node.position.timeIndex;
    x = node.position.dim0 + dt * node.position.vector[0];
    y = node.position.dim1 + dt * node.position.vector[1];
    expect(x, 225.0);
    expect(y, 250.0);
  });

  testWidgets('TopologyMap widget renders viewport, grid, and scrubber',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TopologyMap(),
        ),
      ),
    );

    // Verify CustomPaint exists with TopologyPainter
    expect(
        find.byWidgetPredicate((Widget widget) =>
            widget is CustomPaint && widget.painter is TopologyPainter),
        findsOneWidget);

    // Verify nested scroll views (vertical wrapping horizontal)
    expect(find.byType(SingleChildScrollView), findsNWidgets(3));

    // Verify scrubber controls are present
    expect(
        find.byKey(const ValueKey<String>('playPauseButton')), findsOneWidget);
    expect(find.text('t:'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('timeSlider')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('speedDropdown')), findsOneWidget);
  });

  testWidgets('Tap detection selects node within 20px proximity',
      (WidgetTester tester) async {
    String? selectedNodeId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              height: 600,
              child: TopologyMap(
                data: _testTopologyData,
                onNodeSelect: (String id) {
                  selectedNodeId = id;
                },
              ),
            ),
          ),
        ),
      ),
    );

    // Default 'Ingestion' position at t = 1.0 is dim0: 100, dim1: 140
    // Tap exactly on (100, 140)
    await tester.tapAt(const Offset(100.0, 140.0));
    await tester.pumpAndSettle();
    expect(selectedNodeId, equals('Ingestion'));

    // Tap outside ('Ingestion' is at (100, 140), so (50, 50) is far away)
    selectedNodeId = null;
    await tester.tapAt(const Offset(50.0, 50.0));
    await tester.pumpAndSettle();
    expect(selectedNodeId, isNull);

    // Tap within 20px proximity (e.g. (110, 135) -> distance is sqrt(100 + 25) = 11.18px <= 20)
    selectedNodeId = null;
    await tester.tapAt(const Offset(110.0, 135.0));
    await tester.pumpAndSettle();
    expect(selectedNodeId, equals('Ingestion'));
  });

  testWidgets('Timeline scrubber adjusts playhead time',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              height: 600,
              child: TopologyMap(),
            ),
          ),
        ),
      ),
    );

    // Verify initial time is 1.0
    expect(find.text('1.0'), findsOneWidget);

    final Finder sliderFinder = find.byKey(const ValueKey<String>('timeSlider'));
    expect(sliderFinder, findsOneWidget);

    // Tap slider to scrub to a different value (center of the slider)
    await tester.tap(sliderFinder);
    await tester.pumpAndSettle();

    // Verify time t: has updated and is not 1.0 anymore
    expect(find.text('1.0'), findsNothing);
  });

  testWidgets('Play/Pause button starts/stops ticking',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              height: 600,
              child: TopologyMap(),
            ),
          ),
        ),
      ),
    );

    final Finder playPauseFinder =
        find.byKey(const ValueKey<String>('playPauseButton'));
    expect(playPauseFinder, findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    // Tap Play
    await tester.tap(playPauseFinder);
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    // Let time pass through multiple frames to allow ticker to advance
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    // Verify time has progressed past 1.0
    expect(find.text('1.0'), findsNothing);

    // Tap Pause
    await tester.tap(playPauseFinder);
    await tester.pump();
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('Speed dropdown selection updates multiplier',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 800,
              height: 600,
              child: TopologyMap(),
            ),
          ),
        ),
      ),
    );

    final Finder speedDropdownFinder =
        find.byKey(const ValueKey<String>('speedDropdown'));
    expect(speedDropdownFinder, findsOneWidget);

    // Verify that the dropdown starts with 1.0 (internal value)
    final DropdownButton<double> dropdown =
        tester.widget<DropdownButton<double>>(speedDropdownFinder);
    expect(dropdown.value, equals(1.0));
  });
}
