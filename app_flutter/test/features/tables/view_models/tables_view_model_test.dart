import 'package:app_flutter/domain/column_model.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/domain/instance_record.dart';
import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/topology/topology_map.dart' show TopologyData;

class _MockDataSource implements DataSource {
  @override
  String get name => 'mock';

  Future<TypeDescriptor?> Function(String typeName)? onTypeFor;
  Future<List<InstanceRecord>> Function({
    required String parentNodeId,
    required TypeDescriptor targetType,
  })? onFetchRelatedInstances;

  @override
  Future<List<TypeDescriptor>> discoverTypes() async => [];

  @override
  Future<TypeDescriptor?> typeFor(String typeName) async =>
      onTypeFor?.call(typeName) ?? null;

  @override
  Future<List<(String, String)>> discoverHierarchy() async => [];

  @override
  Future<Map<String, dynamic>> fetchProperties(String nodeId) async => {};

  @override
  Future<void> saveProperties(String nodeId, Map<String, dynamic> data) async {}

  @override
  Stream<Map<String, dynamic>> watchProperties(String nodeId) =>
      const Stream.empty();

  @override
  Future<List<InstanceRecord>> fetchRelatedInstances({
    required String parentNodeId,
    required TypeDescriptor targetType,
  }) async =>
      onFetchRelatedInstances?.call(
        parentNodeId: parentNodeId,
        targetType: targetType,
      ) ?? [];

  @override
  Future<List<TreeNode>> fetchRootNodes() async => [];
  @override
  Future<List<TreeNode>> fetchChildrenForNode(String parentId) async => [];

  @override
  Future<TopologyData> fetchTopologyData() async => const TopologyData(coordinateMapping: {}, nodes: [], links: []);
}


void main() {
  group('TablesViewModel columnModels', () {
    late _MockDataSource dataSource;
    late TablesViewModel viewModel;

    setUp(() {
      dataSource = _MockDataSource();
      viewModel = TablesViewModel(dataSource, 'test');
    });

    test('columnModels is empty before load', () {
      expect(viewModel.columnModels, isEmpty);
    });

    test('columnModels count matches FieldDescriptor count', () async {
      final fields = [
        FieldDescriptor(key: 'k1', label: 'Col 1', type: 'string'),
        FieldDescriptor(key: 'k2', label: 'Col 2', type: 'int'),
        FieldDescriptor(key: 'k3', label: 'Col 3', type: 'double'),
      ];

      dataSource.onTypeFor = (typeName) async {
        if (typeName == 'root') {
          return TypeDescriptor(
            typeName: 'root',
            displayName: 'Root',
            iconName: 'folder',
            fields: [],
            childTypes: [],
            relatedTypes: [
              TypeRelationDescriptor(
                relationName: 'has',
                childTypeName: 'ChildType',
                childLabel: 'Child Label',
              ),
            ],
            parentTypes: [],
          );
        }
        if (typeName == 'ChildType') {
          return TypeDescriptor(
            typeName: 'ChildType',
            displayName: 'Child',
            iconName: 'child',
            fields: fields,
            childTypes: [],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        return null;
      };

      dataSource.onFetchRelatedInstances = ({
        required parentNodeId,
        required targetType,
      }) async => [
        InstanceRecord(
          id: '1',
          parentNodeId: parentNodeId,
          typeName: targetType.typeName,
          attributes: {'k1': 'a', 'k2': '1', 'k3': '1.0'},
        ),
      ];

      await viewModel.loadForNode('root');
      expect(viewModel.columnModels.length, fields.length);
    });

    test('columnModels is populated correctly in _loadData', () async {
      final fields = [
        FieldDescriptor(key: 'voltage', label: 'Voltage (V)', type: 'double'),
        FieldDescriptor(key: 'current', label: 'Current (A)', type: 'double'),
      ];

      dataSource.onTypeFor = (typeName) async {
        if (typeName == 'root') {
          return TypeDescriptor(
            typeName: 'root',
            displayName: 'Root',
            iconName: 'folder',
            fields: [],
            childTypes: [],
            relatedTypes: [
              TypeRelationDescriptor(
                relationName: 'has',
                childTypeName: 'ChildType',
                childLabel: 'Child Label',
              ),
            ],
            parentTypes: [],
          );
        }
        if (typeName == 'ChildType') {
          return TypeDescriptor(
            typeName: 'ChildType',
            displayName: 'Child',
            iconName: 'child',
            fields: fields,
            childTypes: [],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        return null;
      };

      dataSource.onFetchRelatedInstances = ({
        required parentNodeId,
        required targetType,
      }) async => [
        InstanceRecord(
          id: '1',
          parentNodeId: parentNodeId,
          typeName: targetType.typeName,
          attributes: {'voltage': '220.0', 'current': '1.5'},
        ),
      ];

      await viewModel.loadForNode('root');

      expect(viewModel.columnModels.length, 2);
      expect(viewModel.columnModels[0].key, 'voltage');
      expect(viewModel.columnModels[0].label, 'Voltage (V)');
      expect(viewModel.columnModels[0].type, 'double');
      expect(viewModel.columnModels[1].key, 'current');
      expect(viewModel.columnModels[1].label, 'Current (A)');
      expect(viewModel.columnModels[1].type, 'double');
    });

    test('columnModels is cleared on error', () async {
      dataSource.onTypeFor = (typeName) async {
        if (typeName == 'root') {
          return TypeDescriptor(
            typeName: 'root',
            displayName: 'Root',
            iconName: 'folder',
            fields: [],
            childTypes: [
              TypeRelationDescriptor(
                relationName: 'contains',
                childTypeName: 'ChildType',
                childLabel: 'Child Type',
              ),
            ],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        if (typeName == 'ChildType') {
          return TypeDescriptor(
            typeName: 'ChildType',
            displayName: 'Child',
            iconName: 'child',
            fields: [
              FieldDescriptor(key: 'k1', label: 'Col 1', type: 'string'),
            ],
            childTypes: [],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        return null;
      };

      dataSource.onFetchRelatedInstances = ({
        required parentNodeId,
        required targetType,
      }) async =>
          throw Exception('Fetch error');

      await viewModel.loadForNode('root');
      expect(viewModel.columnModels, isEmpty);
    });
  });

  group('TablesViewModel headers', () {
    late _MockDataSource dataSource;
    late TablesViewModel viewModel;

    setUp(() {
      dataSource = _MockDataSource();
      viewModel = TablesViewModel(dataSource, 'test');
    });

    test('headers returns List<ColumnModel> after load', () async {
      dataSource.onTypeFor = (typeName) async {
        if (typeName == 'test-node') {
          return TypeDescriptor(
            typeName: 'test-node',
            displayName: 'Test Node',
            iconName: 'node',
            fields: [],
            childTypes: [],
            relatedTypes: [
              TypeRelationDescriptor(
                relationName: 'has',
                childTypeName: 'ChildType',
                childLabel: 'Child Label',
              ),
            ],
            parentTypes: [],
          );
        }
        if (typeName == 'ChildType') {
          return TypeDescriptor(
            typeName: 'ChildType',
            displayName: 'Child',
            iconName: 'child',
            fields: [
              FieldDescriptor(key: 'k1', label: 'Col 1', type: 'string'),
              FieldDescriptor(key: 'k2', label: 'Col 2', type: 'int'),
            ],
            childTypes: [],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        return null;
      };

      dataSource.onFetchRelatedInstances = ({
        required parentNodeId,
        required targetType,
      }) async => [
        InstanceRecord(
          id: '1',
          parentNodeId: parentNodeId,
          typeName: targetType.typeName,
          attributes: {'k1': 'a', 'k2': '1'},
        ),
      ];

      await viewModel.loadForNode('test-node');
      expect(viewModel.headers, isA<List<ColumnModel>>());
      expect(viewModel.headers.length, greaterThan(0));
      expect(viewModel.headers.first.key, isNotEmpty);
      expect(viewModel.headers.first.type, equals('string'));
    });
  });

  group('TablesViewModel visibleColumnModels', () {
    late _MockDataSource dataSource;
    late TablesViewModel viewModel;

    setUp(() {
      dataSource = _MockDataSource();
      viewModel = TablesViewModel(dataSource, 'test');
    });

    test('visibleColumnModels returns all columns when no hidden keys set',
        () async {
      dataSource.onTypeFor = (typeName) async {
        if (typeName == 'test-node') {
          return TypeDescriptor(
            typeName: 'test-node',
            displayName: 'Test Node',
            iconName: 'node',
            fields: [],
            childTypes: [],
            relatedTypes: [
              TypeRelationDescriptor(
                relationName: 'has',
                childTypeName: 'ChildType',
                childLabel: 'Child Label',
              ),
            ],
            parentTypes: [],
          );
        }
        if (typeName == 'ChildType') {
          return TypeDescriptor(
            typeName: 'ChildType',
            displayName: 'Child',
            iconName: 'child',
            fields: [
              FieldDescriptor(key: 'k1', label: 'Col 1', type: 'string'),
              FieldDescriptor(key: 'k2', label: 'Col 2', type: 'int'),
            ],
            childTypes: [],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        return null;
      };

      dataSource.onFetchRelatedInstances = ({
        required parentNodeId,
        required targetType,
      }) async => [
        InstanceRecord(
          id: '1',
          parentNodeId: parentNodeId,
          typeName: targetType.typeName,
          attributes: {'k1': 'a', 'k2': '1'},
        ),
      ];

      await viewModel.loadForNode('test-node');
      expect(viewModel.visibleColumnModels.length, equals(viewModel.headers.length));
    });

    test('visibleColumnModels filters out hidden columns by key', () async {
      dataSource.onTypeFor = (typeName) async {
        if (typeName == 'test-node') {
          return TypeDescriptor(
            typeName: 'test-node',
            displayName: 'Test Node',
            iconName: 'node',
            fields: [],
            childTypes: [],
            relatedTypes: [
              TypeRelationDescriptor(
                relationName: 'has',
                childTypeName: 'ChildType',
                childLabel: 'Child Label',
              ),
            ],
            parentTypes: [],
          );
        }
        if (typeName == 'ChildType') {
          return TypeDescriptor(
            typeName: 'ChildType',
            displayName: 'Child',
            iconName: 'child',
            fields: [
              FieldDescriptor(key: 'k1', label: 'Col 1', type: 'string'),
              FieldDescriptor(key: 'k2', label: 'Col 2', type: 'int'),
            ],
            childTypes: [],
            relatedTypes: [],
            parentTypes: [],
          );
        }
        return null;
      };

      dataSource.onFetchRelatedInstances = ({
        required parentNodeId,
        required targetType,
      }) async => [
        InstanceRecord(
          id: '1',
          parentNodeId: parentNodeId,
          typeName: targetType.typeName,
          attributes: {'k1': 'a', 'k2': '1'},
        ),
      ];

      await viewModel.loadForNode('test-node');
      final hiddenKey = viewModel.headers.first.key;
      viewModel.setHiddenColumnKeys({hiddenKey});
      expect(viewModel.visibleColumnModels.length, equals(viewModel.headers.length - 1));
      expect(viewModel.visibleColumnModels.any((c) => c.key == hiddenKey), isFalse);
    });
  });
}
