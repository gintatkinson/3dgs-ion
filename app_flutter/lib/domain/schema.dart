class AttributeDefinition {
  final String key;
  final String label;
  final String type; // 'double' | 'int' | 'string' | 'enum'
  final String sectionGroup;
  final List<String>? options;
  final bool isRequired;
  final String? regexPattern;
  final num? minValue;
  final num? maxValue;

  const AttributeDefinition({
    required this.key,
    required this.label,
    required this.type,
    required this.sectionGroup,
    this.options,
    this.isRequired = false,
    this.regexPattern,
    this.minValue,
    this.maxValue,
  });

  factory AttributeDefinition.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    return AttributeDefinition(
      key: json['key'] as String,
      label: json['label'] as String,
      type: typeStr == 'enumeration' ? 'enum' : typeStr,
      sectionGroup: json['sectionGroup'] as String,
      options: (json['options'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isRequired: json['isRequired'] as bool? ?? false,
      regexPattern: json['regexPattern'] as String?,
      minValue: json['minValue'] as num?,
      maxValue: json['maxValue'] as num?,
    );
  }

  dynamic get defaultValue {
    if (type == 'int') {
      return minValue?.toInt() ?? 0;
    } else if (type == 'double') {
      return minValue?.toDouble() ?? 0.0;
    } else if (type == 'enum') {
      if (options != null && options!.isNotEmpty) {
        return options!.first;
      }
      return '';
    } else {
      return '';
    }
  }
}


