import 'dart:convert';
import 'package:app_flutter/domain/type_descriptor.dart';

/// Exception thrown when schema validation of an [InstanceRecord] fails.
class SchemaValidationException implements Exception {
  /// The validation error message.
  final String message;

  /// Creates a new [SchemaValidationException] with the given message.
  const SchemaValidationException(this.message);

  @override
  String toString() => 'SchemaValidationException: $message';
}

/// Represents an instance record of a specific type.
class InstanceRecord {
  /// Unique identifier of the instance.
  final String id;

  /// Identifier of the parent node.
  final String parentNodeId;

  /// The name of the type of this instance.
  final String typeName;

  /// Attributes of the instance represented as key-value pairs.
  final Map<String, dynamic> attributes;

  /// Creates a new [InstanceRecord] instance.
  const InstanceRecord({
    required this.id,
    required this.parentNodeId,
    required this.typeName,
    required this.attributes,
  });

  /// Creates an [InstanceRecord] from a raw map database entry.
  factory InstanceRecord.fromMap(Map<String, dynamic> map, String typeName) {
    Map<String, dynamic> attrs = {};
    if (map['data_json'] != null) {
      try {
        final decoded = jsonDecode(map['data_json'] as String);
        if (decoded is Map<String, dynamic>) {
          attrs = decoded;
        }
      } catch (_) {}
    } else {
      attrs = Map<String, dynamic>.from(map);
    }
    return InstanceRecord(
      id: map['id']?.toString() ?? attrs['id']?.toString() ?? '',
      parentNodeId: map['parent_node_id']?.toString() ?? attrs['parent_node_id']?.toString() ?? '',
      typeName: map['type_name']?.toString() ?? typeName,
      attributes: attrs,
    );
  }

  /// Creates an [InstanceRecord] from a raw map database entry and validates it.
  ///
  /// Throws [SchemaValidationException] if validation fails.
  factory InstanceRecord.fromMapWithValidation(
    Map<String, dynamic> map,
    String typeName,
    List<FieldDescriptor> fields,
  ) {
    final record = InstanceRecord.fromMap(map, typeName);
    record.validate(fields);
    return record;
  }

  /// Validates all attributes against the provided [fields] descriptors constraints.
  ///
  /// Checks for required fields, value ranges, pattern matches, and enum options.
  /// Throws [SchemaValidationException] and logs a warning on failure.
  void validate(List<FieldDescriptor> fields) {
    for (final fd in fields) {
      final value = attributes[fd.key];

      // Required check
      if (fd.required) {
        if (value == null || (value is String && value.trim().isEmpty)) {
          final msg = 'Attribute "${fd.key}" is required but missing or empty for instance "$id".';
          print('WARNING: $msg');
          throw SchemaValidationException(msg);
        }
      }

      if (value != null) {
        final strVal = value.toString();
        // Type validation and constraints check
        if (fd.type == 'int') {
          final parsed = int.tryParse(strVal);
          if (parsed == null) {
            final msg = 'Attribute "${fd.key}" expects an integer, got "$value" for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
          if (fd.minValue != null && parsed < fd.minValue!) {
            final msg = 'Attribute "${fd.key}" value $parsed is below minimum limit ${fd.minValue} for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
          if (fd.maxValue != null && parsed > fd.maxValue!) {
            final msg = 'Attribute "${fd.key}" value $parsed exceeds maximum limit ${fd.maxValue} for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
        } else if (fd.type == 'double' || fd.type == 'real') {
          final parsed = double.tryParse(strVal);
          if (parsed == null) {
            final msg = 'Attribute "${fd.key}" expects a double/real, got "$value" for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
          if (fd.minValue != null && parsed < fd.minValue!) {
            final msg = 'Attribute "${fd.key}" value $parsed is below minimum limit ${fd.minValue} for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
          if (fd.maxValue != null && parsed > fd.maxValue!) {
            final msg = 'Attribute "${fd.key}" value $parsed exceeds maximum limit ${fd.maxValue} for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
        } else if (fd.type == 'string') {
          if (fd.pattern != null && fd.pattern!.isNotEmpty) {
            final regex = RegExp(fd.pattern!);
            if (!regex.hasMatch(strVal)) {
              final msg = 'Attribute "${fd.key}" value "$strVal" does not match pattern "${fd.pattern}" for instance "$id".';
              print('WARNING: $msg');
              throw SchemaValidationException(msg);
            }
          }
        } else if (fd.type == 'enum') {
          if (fd.enumOptions != null && !fd.enumOptions!.contains(strVal)) {
            final msg = 'Attribute "${fd.key}" value "$strVal" is not a valid option (expected one of ${fd.enumOptions}) for instance "$id".';
            print('WARNING: $msg');
            throw SchemaValidationException(msg);
          }
        }
      }
    }
  }
}
