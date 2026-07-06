import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/domain/column_model.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/domain/instance_record.dart';
import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';
import 'package:app_flutter/features/tables/table_view_widget.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/topology/topology_map.dart' show TopologyData;

/// A test subclass that exposes setter methods for overriding internal state.
class _TestTablesViewModel extends TablesViewModel {
  _TestTablesViewModel(super.dataSource, super.activeView);

  @override
  List<ColumnModel> get headers => _overrideHeaders;
  List<ColumnModel> _overrideHeaders = [];

  Set<String> _overrideHiddenKeys = {};

  @override
  List<ColumnModel> get visibleColumnModels =>
      _overrideHeaders
          .where((cm) => cm.visible)
          .where((cm) => _overrideHiddenKeys.isEmpty || !_overrideHiddenKeys.contains(cm.key))
          .toList();

  @override
  List<ColumnModel> get columnModels => _overrideColumnModels;
  List<ColumnModel> _overrideColumnModels = [];

  @override
  List<List<String>> get rows => _overrideRows;
  List<List<String>> _overrideRows = [];

  @override
  bool get loading => _overrideLoading;
  bool _overrideLoading = false;

  void setState({
    List<ColumnModel>? headers,
    List<ColumnModel>? columnModels,
    List<List<String>>? rows,
    bool? loading,
    Set<String>? hiddenKeys,
  }) {
    if (headers != null) _overrideHeaders = headers;
    if (columnModels != null) _overrideColumnModels = columnModels;
    if (rows != null) _overrideRows = rows;
    if (loading != null) _overrideLoading = loading;
    if (hiddenKeys != null) _overrideHiddenKeys = hiddenKeys;
    notifyListeners();
  }
}

class _MockDataSource implements DataSource {
  _MockDataSource({this.fields = const []});

  final List<FieldDescriptor> fields;

  @override
  String get name => 'mock';

  @override
  Future<List<TypeDescriptor>> discoverTypes() async => [];

  @override
  Future<TypeDescriptor?> typeFor(String typeName) async => null;

  @override
  Future<List<(String, String)>> discoverHierarchy() async => [];

  @override
  Future<Map<String, dynamic>> fetchProperties(String nodeId) async => {};

  @override
  Future<void> saveProperties(String nodeId, Map<String, dynamic> data) async {}

  @override
  Stream<Map<String, dynamic>> watchProperties(String nodeId) async* { yield {}; }

  @override
  Future<List<InstanceRecord>> fetchRelatedInstances({
    required String parentNodeId,
    required TypeDescriptor targetType,
  }) async => [];

  @override
  Future<List<TreeNode>> fetchRootNodes() async => [];
  @override
  Future<List<TreeNode>> fetchChildrenForNode(String parentId) async => [];

  @override
  Future<TopologyData> fetchTopologyData() async => const TopologyData(coordinateMapping: {}, nodes: [], links: []);
}


Widget buildTableWithModel({
  required List<ColumnModel> headers,
  List<ColumnModel>? columnModels,
  List<List<String>> rows = const [],
}) {
  final viewModel = _TestTablesViewModel(_MockDataSource(), 'Root');
  viewModel.setState(
    headers: headers,
    columnModels: columnModels ?? headers,
    rows: rows,
    loading: false,
  );

  return MaterialApp(
    home: ChangeNotifierProvider<TablesViewModel>.value(
      value: viewModel,
      child: const TableViewWidget(),
    ),
  );
}

Widget buildTableFromModel({required _TestTablesViewModel model}) {
  return MaterialApp(
    home: ChangeNotifierProvider<TablesViewModel>.value(
      value: model,
      child: const TableViewWidget(),
    ),
  );
}

void main() {
  group('TableViewWidget header rendering', () {
    testWidgets('renders labels from ColumnModel when available', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
        columnModels: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
      ));

      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('falls back to raw headers when ColumnModel is empty', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
        columnModels: [],
      ));

      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('column count matches FieldDescriptor count', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
        columnModels: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
        rows: [
          ['v1', 'v2', 'v3'],
        ],
      ));

      await tester.pump();

      // 3 header cells + 3 data cells = 6 total Text widgets expected
      expect(find.byType(Text), findsNWidgets(6));
    });

    testWidgets('renders labels from headers directly when no separate columnModels', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
      ));

      await tester.pump();

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });
  });

  group('TableViewWidget cell type rendering', () {
    testWidgets('renders string cells as plain Text', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'name', label: 'Name', type: 'string'),
        ],
        columnModels: [
          const ColumnModel(key: 'name', label: 'Name', type: 'string'),
        ],
        rows: [
          ['Alice'],
        ],
      ));

      await tester.pump();

      final textWidget = tester.widget<Text>(find.text('Alice'));
      expect(textWidget.textAlign, isNull);
    });

    testWidgets('renders int cells right-aligned with monospace font', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'name', label: 'Name', type: 'string'),
          const ColumnModel(key: 'count', label: 'Count', type: 'int'),
        ],
        columnModels: [
          const ColumnModel(key: 'name', label: 'Name', type: 'string'),
          const ColumnModel(key: 'count', label: 'Count', type: 'int'),
        ],
        rows: [
          ['Foo', '42'],
        ],
      ));

      await tester.pump();

      final countText = tester.widget<Text>(find.text('42'));
      expect(countText.textAlign, TextAlign.right);
      expect(countText.style?.fontFamily, 'monospace');
    });

    testWidgets('renders double cells right-aligned with monospace font', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'val', label: 'Value', type: 'double'),
        ],
        columnModels: [
          const ColumnModel(key: 'val', label: 'Value', type: 'double'),
        ],
        rows: [
          ['3.14'],
        ],
      ));

      await tester.pump();

      final valText = tester.widget<Text>(find.text('3.14'));
      expect(valText.textAlign, TextAlign.right);
      expect(valText.style?.fontFamily, 'monospace');
    });

    testWidgets('renders enum-type cells as chips', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'status', label: 'Status', type: 'enum'),
        ],
        columnModels: [
          const ColumnModel(key: 'status', label: 'Status', type: 'enum'),
        ],
        rows: [
          ['Active'],
        ],
      ));

      await tester.pump();

      final textFinder = find.text('Active');
      final ancestorContainer = find.ancestor(
        of: textFinder,
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(ancestorContainer.first);
      expect(container.decoration, isNotNull);
    });

    testWidgets('renders date-type cells formatted', (tester) async {
      await tester.pumpWidget(buildTableWithModel(
        headers: [
          const ColumnModel(key: 'date', label: 'Date', type: 'date'),
        ],
        columnModels: [
          const ColumnModel(key: 'date', label: 'Date', type: 'date'),
        ],
        rows: [
          ['2024-01-15T00:00:00'],
        ],
      ));

      await tester.pump();

      expect(find.text('2024-01-15'), findsOneWidget);
    });
  });

  group('TableViewWidget visibleColumnModels', () {
    test('visibleColumnModels returns all columns when no hidden keys set', () {
      final viewModel = _TestTablesViewModel(_MockDataSource(), 'Root');
      viewModel.setState(
        headers: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
        ],
        loading: false,
      );

      expect(viewModel.visibleColumnModels.length, equals(2));
      expect(viewModel.visibleColumnModels.map((c) => c.key).toList(), equals(['a', 'b']));
    });

    test('visibleColumnModels filters out hidden columns by key', () {
      final viewModel = _TestTablesViewModel(_MockDataSource(), 'Root');
      viewModel.setState(
        headers: [
          const ColumnModel(key: 'a', label: 'Alpha', type: 'string'),
          const ColumnModel(key: 'b', label: 'Beta', type: 'string'),
          const ColumnModel(key: 'c', label: 'Gamma', type: 'string'),
        ],
        loading: false,
        hiddenKeys: {'b'},
      );

      expect(viewModel.visibleColumnModels.length, equals(2));
      expect(viewModel.visibleColumnModels.any((c) => c.key == 'b'), isFalse);
      expect(viewModel.visibleColumnModels.map((c) => c.key).toList(), equals(['a', 'c']));
    });
  });

  group('TableViewWidget sorting', () {
    testWidgets('tapping sortable column header sorts rows ascending', (tester) async {
      final columns = [
        const ColumnModel(key: 'a', label: 'Name', type: 'string', sortable: true),
      ];
      await tester.pumpWidget(buildTableWithModel(
        headers: columns,
        columnModels: columns,
        rows: [
          ['Charlie'],
          ['Alice'],
          ['Bob'],
        ],
      ));

      await tester.pump();

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data != null && !t.data!.startsWith('Name'))
          .map((t) => t.data!)
          .toList();
      expect(texts, equals(['Alice', 'Bob', 'Charlie']));
    });

    testWidgets('tapping same column again reverses sort direction', (tester) async {
      final columns = [
        const ColumnModel(key: 'a', label: 'Name', type: 'string', sortable: true),
      ];
      await tester.pumpWidget(buildTableWithModel(
        headers: columns,
        columnModels: columns,
        rows: [
          ['Bob'],
          ['Alice'],
          ['Charlie'],
        ],
      ));

      await tester.pump();

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Name'));
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data != null && !t.data!.startsWith('Name'))
          .map((t) => t.data!)
          .toList();
      expect(texts, equals(['Charlie', 'Bob', 'Alice']));
    });

    testWidgets('non-sortable column header does not trigger sort', (tester) async {
      final columns = [
        const ColumnModel(key: 'a', label: 'Name', type: 'string', sortable: false),
      ];
      await tester.pumpWidget(buildTableWithModel(
        headers: columns,
        columnModels: columns,
        rows: [
          ['Charlie'],
          ['Alice'],
          ['Bob'],
        ],
      ));

      await tester.pump();

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data != null && t.data != 'Name')
          .map((t) => t.data!)
          .toList();
      expect(texts, equals(['Charlie', 'Alice', 'Bob']));
    });

    testWidgets('sort indicator renders on active sort column', (tester) async {
      final columns = [
        const ColumnModel(key: 'a', label: 'Name', type: 'string', sortable: true),
      ];
      await tester.pumpWidget(buildTableWithModel(
        headers: columns,
        columnModels: columns,
        rows: [
          ['Charlie'],
          ['Alice'],
          ['Bob'],
        ],
      ));

      await tester.pump();

      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();

      expect(find.textContaining('↑'), findsOneWidget);
    });
  });

  group('TableViewWidget visibility filtering', () {
    testWidgets('visible:false columns are excluded from render', (tester) async {
      final columns = [
        const ColumnModel(key: 'a', label: 'Visible A', type: 'string', visible: true),
        const ColumnModel(key: 'b', label: 'Hidden B', type: 'string', visible: false),
        const ColumnModel(key: 'c', label: 'Visible C', type: 'string', visible: true),
      ];
      final model = _TestTablesViewModel(_MockDataSource(), 'Root');
      model.setState(headers: columns, rows: [
        ['A', 'B', 'C']
      ]);
      model.setHiddenColumnKeys(null);
      await tester.pumpWidget(buildTableFromModel(model: model));

      expect(find.text('Visible A'), findsOneWidget);
      expect(find.text('Hidden B'), findsNothing);
      expect(find.text('Visible C'), findsOneWidget);
      expect(find.text('B'), findsNothing);
    });
  });
}
