import 'package:app_flutter/domain/instance_record.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InstanceRecord validation', () {
    test('passes when all attributes conform to constraints', () {
      final fields = [
        const FieldDescriptor(key: 'name', label: 'Name', type: 'string', required: true),
        const FieldDescriptor(key: 'voltage', label: 'Voltage', type: 'double', minValue: 0.0, maxValue: 1000.0),
        const FieldDescriptor(key: 'status', label: 'Status', type: 'enum', enumOptions: ['Active', 'Inactive']),
      ];

      final record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {
          'name': 'Power Module',
          'voltage': 240.5,
          'status': 'Active',
        },
      );

      expect(() => record.validate(fields), returnsNormally);
    });

    test('throws SchemaValidationException when required attribute is missing', () {
      final fields = [
        const FieldDescriptor(key: 'name', label: 'Name', type: 'string', required: true),
      ];

      final record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {},
      );

      expect(
        () => record.validate(fields),
        throwsA(isA<SchemaValidationException>().having(
          (e) => e.message,
          'message',
          contains('required but missing'),
        )),
      );
    });

    test('throws SchemaValidationException when required attribute is empty string', () {
      final fields = [
        const FieldDescriptor(key: 'name', label: 'Name', type: 'string', required: true),
      ];

      final record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'name': '   '},
      );

      expect(
        () => record.validate(fields),
        throwsA(isA<SchemaValidationException>().having(
          (e) => e.message,
          'message',
          contains('required but missing or empty'),
        )),
      );
    });

    test('validates integer boundaries and types', () {
      final fields = [
        const FieldDescriptor(key: 'count', label: 'Count', type: 'int', minValue: 5, maxValue: 10),
      ];

      // Below min
      var record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'count': 4},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Above max
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'count': 11},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Not an integer
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'count': 'not-an-int'},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Valid
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'count': 7},
      );
      expect(() => record.validate(fields), returnsNormally);
    });

    test('validates double boundaries and types', () {
      final fields = [
        const FieldDescriptor(key: 'ratio', label: 'Ratio', type: 'double', minValue: 0.1, maxValue: 0.9),
      ];

      // Below min
      var record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'ratio': 0.05},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Above max
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'ratio': 0.95},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Not a double
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'ratio': 'invalid-double'},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Valid
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'ratio': 0.5},
      );
      expect(() => record.validate(fields), returnsNormally);
    });

    test('validates string patterns', () {
      final fields = [
        const FieldDescriptor(key: 'code', label: 'Code', type: 'string', pattern: r'^[A-Z]{3}-\d{3}$'),
      ];

      // Non-matching
      var record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'code': 'abc-123'},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Valid matching
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'code': 'ABC-123'},
      );
      expect(() => record.validate(fields), returnsNormally);
    });

    test('validates enum values', () {
      final fields = [
        const FieldDescriptor(key: 'color', label: 'Color', type: 'enum', enumOptions: ['red', 'blue', 'green']),
      ];

      // Not a valid option
      var record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'color': 'yellow'},
      );
      expect(() => record.validate(fields), throwsA(isA<SchemaValidationException>()));

      // Valid option
      record = InstanceRecord(
        id: 'inst-1',
        parentNodeId: 'root',
        typeName: 'TestType',
        attributes: const {'color': 'blue'},
      );
      expect(() => record.validate(fields), returnsNormally);
    });

    test('fromMapWithValidation factory constructs and validates', () {
      final fields = [
        const FieldDescriptor(key: 'name', label: 'Name', type: 'string', required: true),
      ];

      final map = {
        'id': 'inst-123',
        'parent_node_id': 'root',
        'data_json': '{"name":"Correct"}',
      };

      final record = InstanceRecord.fromMapWithValidation(map, 'TestType', fields);
      expect(record.id, 'inst-123');
      expect(record.attributes['name'], 'Correct');

      final invalidMap = {
        'id': 'inst-123',
        'parent_node_id': 'root',
        'data_json': '{"name":""}',
      };

      expect(
        () => InstanceRecord.fromMapWithValidation(invalidMap, 'TestType', fields),
        throwsA(isA<SchemaValidationException>()),
      );
    });
  });
}
