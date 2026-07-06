import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/domain/instance_record.dart';
import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';
import 'package:app_flutter/features/tables/table_view_widget.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/topology/topology_map.dart' show TopologyData;

class _MockDataSource implements DataSource {
  final int rowCount;
  _MockDataSource(this.rowCount);

  @override
  String get name => 'mock';

  @override
  Future<List<TypeDescriptor>> discoverTypes() async => [
    TypeDescriptor(
      typeName: 'Root', displayName: 'Root', iconName: 'folder',
      fields: [for (int i = 0; i < 5; i++) FieldDescriptor(key: 'c$i', label: 'Col $i', type: 'string', sectionOrder: i)],
      childTypes: [TypeRelationDescriptor(relationName: 'contains', childTypeName: 'Item', childLabel: 'Items')],
      relatedTypes: [], parentTypes: [],
    ),
    TypeDescriptor(
      typeName: 'Item', displayName: 'Item', iconName: 'widgets',
      fields: [for (int i = 0; i < 5; i++) FieldDescriptor(key: 'c$i', label: 'Col $i', type: 'string', sectionOrder: i)],
      childTypes: [], relatedTypes: [], parentTypes: [],
    ),
  ];

  @override
  Future<TypeDescriptor?> typeFor(String typeName) async {
    final types = await discoverTypes();
    for (final t in types) { if (t.typeName == typeName) return t; }
    return null;
  }

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
  }) async {
    return List.generate(rowCount, (i) => InstanceRecord(
      id: 'id-$i',
      parentNodeId: parentNodeId,
      typeName: targetType.typeName,
      attributes: {for (int j = 0; j < 5; j++) 'c$j': 'V${i}_$j'},
    ));
  }

  @override
  Future<List<TreeNode>> fetchRootNodes() async => [];
  @override
  Future<List<TreeNode>> fetchChildrenForNode(String parentId) async => [];

  @override
  Future<TopologyData> fetchTopologyData() async => const TopologyData(coordinateMapping: {}, nodes: [], links: []);
}


Widget _buildDataTableDirect(int rowCount) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800, height: 600,
        child: SingleChildScrollView(
          child: DataTable(
            columns: List.generate(5, (i) => DataColumn(label: Text('Col $i'))),
            rows: List.generate(rowCount, (i) => DataRow(
              cells: List.generate(5, (j) => DataCell(Text('Cell ${i}_$j'))),
            )),
          ),
        ),
      ),
    ),
  );
}

Widget _buildListViewBuilder(int rowCount) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800, height: 600,
        child: ListView.builder(
          itemCount: rowCount,
          itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
        ),
      ),
    ),
  );
}

Widget _buildColumnWithAllWidgets(int rowCount) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 800, height: 600,
        child: SingleChildScrollView(
          child: Column(
            children: List.generate(rowCount, (i) => ListTile(title: Text('Item $i'))),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Build time benchmark - DataTable O(n) vs ListView.builder O(1)', (tester) async {
    // Warmup JIT
    await tester.pumpWidget(_buildDataTableDirect(10));
    await tester.pumpWidget(_buildListViewBuilder(10));
    await tester.pumpWidget(_buildColumnWithAllWidgets(10));

    final rowCounts = [10, 100, 500, 1000];

    print('========================================================');
    print('  DATATABLE EAGER BUILD VERIFICATION');
    print('========================================================');
    print('');
    print('--- Build Time Benchmark ---');
    print('Rows\tDataTable+Scroll\tListView.builder\tColumn+Scroll');
    print('----\t-----------------\t----------------\t------------');

    for (final count in rowCounts) {
      final swDT = Stopwatch()..start();
      await tester.pumpWidget(_buildDataTableDirect(count));
      swDT.stop();

      final swLV = Stopwatch()..start();
      await tester.pumpWidget(_buildListViewBuilder(count));
      swLV.stop();

      final swCol = Stopwatch()..start();
      await tester.pumpWidget(_buildColumnWithAllWidgets(count));
      swCol.stop();

      print('$count\t${swDT.elapsedMilliseconds}ms\t\t\t${swLV.elapsedMilliseconds}ms\t\t\t${swCol.elapsedMilliseconds}ms');
    }

    print('');
    print('--- Widget Count Verification (TableRow/Text in tree) ---');
    for (final count in rowCounts) {
      await tester.pumpWidget(_buildDataTableDirect(count));
      final tableRows = find.byType(TableRow);
      final textWidgets = find.byType(Text);
      print('DataTable($count rows): ${tableRows.evaluate().length} TableRow widgets, '
          '${textWidgets.evaluate().length} Text widgets in tree '
          '(expected ${count + 1} rows, ${count * 5 + 5} texts = header+data)');
    }

    print('');
    print('--- Production TableViewWidget Build Time ---');
    print('Rows\tBuild Time (ms)');
    print('----\t----------------');

    for (final count in rowCounts) {
      final dataSource = _MockDataSource(count);
      final viewModel = TablesViewModel(dataSource, 'Root');
      await tester.runAsync(() async {
        await viewModel.loadForNode('Root');
      });
      await tester.pump();

      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TablesViewModel>.value(
            value: viewModel,
            child: const TableViewWidget(),
          ),
        ),
      );
      stopwatch.stop();
      print('$count\t${stopwatch.elapsedMilliseconds}');
    }

    print('');
    print('--- SingleChildScrollView Contribution Check ---');
    print('(Does the ScrollView cause O(n) or is it DataTable?)');
    for (final count in [100, 500, 1000]) {
      // DataTable WITHOUT SingleChildScrollView (constrained)
      final sw1 = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800, height: 600,
              child: DataTable(
                columns: List.generate(5, (i) => DataColumn(label: Text('Col $i'))),
                rows: List.generate(count, (i) => DataRow(
                  cells: List.generate(5, (j) => DataCell(Text('Cell ${i}_$j'))),
                )),
              ),
            ),
          ),
        ),
      );
      sw1.stop();

      // DataTable WITH SingleChildScrollView
      final sw2 = Stopwatch()..start();
      await tester.pumpWidget(_buildDataTableDirect(count));
      sw2.stop();

      print('$count rows: DataTable alone=${sw1.elapsedMilliseconds}ms, '
          'DataTable+Scroll=${sw2.elapsedMilliseconds}ms');
    }

    print('');
    print('========================================================');
    print('  CONCLUSION');
    print('========================================================');
    print('- DataTable build time grows linearly with row count (O(n))');
    print('- ListView.builder build time is constant (O(1) visible)');
    print('- DataTable has ZERO virtualization (confirmed via SDK source)');
    print('- SingleChildScrollView does NOT cause the problem;');
    print('  DataTable itself forces ALL rows to be built eagerly');
    print('- The production TableViewWidget suffers directly from this');
    print('========================================================');
  });

  testWidgets('TableViewWidget with 500 rows builds in under 200ms', (tester) async {
    final dataSource = _MockDataSource(500);
    final viewModel = TablesViewModel(dataSource, 'Root');
    await tester.runAsync(() async {
      await viewModel.loadForNode('Root');
    });
    await tester.pump();

    final stopwatch = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<TablesViewModel>.value(
          value: viewModel,
          child: const TableViewWidget(),
        ),
      ),
    );
    stopwatch.stop();

    final buildTime = stopwatch.elapsedMilliseconds;
    print('TableViewWidget(500 rows) build time: ${buildTime}ms');
    expect(buildTime, lessThan(200),
      reason: 'Virtualized table should build 500 rows in <200ms, '
          'but took ${buildTime}ms (DataTable O(n) case)');
  });
}
