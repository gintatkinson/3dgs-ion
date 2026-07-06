/// Describes a single object type discovered at runtime from the connected
/// [DataSource].
///
/// The client uses this to render tree nodes, property forms, table columns,
/// and topology graphs. The descriptor is domain-agnostic — it works for
/// telco, air-traffic, industrial IoT, or any other domain without code
/// changes. The data source drives what appears in the UI.
///
/// One [TypeDescriptor] instance exists per object type, not per instance.
/// All fields are immutable and must be provided at construction. An empty
/// [TypeDescriptor] (no fields, no relations) is valid and renders as a
/// bare label in the tree — it does not throw.
class TypeDescriptor {
  /// Internal identifier matching the data source, e.g. "device".
  ///
  /// Must be unique within the data source. Used as the key for lookups
  /// via [DataSource.typeFor]. Cannot be empty.
  final String typeName;

  /// Human-readable label for UI display, e.g. "Device".
  ///
  /// Displayed in tree nodes, tab headers, and dropdown selectors.
  /// Falls back to [typeName] if left null by the caller (handled by
  /// the widget layer, not enforced here).
  final String displayName;

  /// Material icon name string, e.g. "developer_board".
  ///
  /// Resolved to [IconData] by [IconMapper.resolve]. If the name is
  /// not in the icon map, [IconMapper] returns a fallback icon —
  /// the tree always shows something, never a blank.
  final String iconName;

  /// All editable fields/attributes of this type.
  ///
  /// Each [FieldDescriptor] specifies the field's type, label,
  /// validation constraints, and UI grouping. When this list changes
  /// (e.g. switching to a different object type), the grid rebuilds
  /// to show the new fields. An empty list renders a "No fields"
  /// message — it does not throw.
  final List<FieldDescriptor> fields;

  /// Child object types for the tree hierarchy.
  ///
  /// Each entry describes a directed parent→child relationship.
  /// An empty list makes this type a leaf node in the tree.
  /// Child types appear as expandable sub-nodes in the sidebar.
  final List<TypeRelationDescriptor> childTypes;

  /// Object types related to this one (events, alerts, logs, etc.).
  ///
  /// These appear as tabs in the detail pane but NOT as tree children.
  /// Related types are sibling or peer entities that share context
  /// with this type without owning it structurally.
  final List<TypeRelationDescriptor> relatedTypes;

  /// Parent object types for reverse tree navigation.
  ///
  /// Used for "go to parent" actions and breadcrumb trails.
  /// An empty list means this type is a root node with no parent.
  final List<TypeRelationDescriptor> parentTypes;

  const TypeDescriptor({
    required this.typeName,
    required this.displayName,
    required this.iconName,
    required this.fields,
    required this.childTypes,
    required this.relatedTypes,
    required this.parentTypes,
  });
}

/// Describes one field/attribute of a [TypeDescriptor].
///
/// Each field tells the UI how to render an editor control (text field,
/// dropdown, numeric spinner, date picker) and how to validate the input.
/// Fields are discovered at runtime — no compile-time schema is required.
/// An empty [FieldDescriptor] is invalid; at minimum [key], [label], and
/// [type] must be provided.
class FieldDescriptor {
  /// Unique key within the type, e.g. "maxVoltage".
  ///
  /// Used as the map key when reading/writing property data.
  /// Must be non-empty and unique within the parent [TypeDescriptor.fields].
  final String key;

  /// Human-readable label, e.g. "Max Voltage (V)".
  ///
  /// Displayed above or beside the editor control in the property form.
  final String label;

  /// Data type: "string", "int", "double", "enum", "date".
  ///
  /// Determines which editor widget to render and which validation rules
  /// to apply. Unknown types fall back to a plain text field. The value
  /// is case-sensitive.
  final String type;

  /// UI section grouping label, e.g. "Alternate Structural Grid Frame".
  ///
  /// If null, the field belongs to a default "Other" section rendered
  /// at the bottom. Section labels match against the UI's section header
  /// map; unknown sections are displayed as-is.
  final String? sectionLabel;

  /// Display order within the section (lower = first).
  ///
  /// Fields with equal [sectionOrder] appear in insertion order.
  /// Negative values are allowed and sort before zero.
  final int sectionOrder;

  /// Whether this field must have a non-null value.
  ///
  /// When true, the UI marks the field as required with an indicator and
  /// prevents saving if the value is null or empty. Validation is the
  /// caller's responsibility — this field is a hint, not a constraint.
  final bool required;

  /// Minimum numeric value for int/double types.
  ///
  /// Applied as an inclusive lower bound during validation.
  /// Ignored for non-numeric types. Null means no minimum.
  final num? minValue;

  /// Maximum numeric value for int/double types.
  ///
  /// Applied as an inclusive upper bound during validation.
  /// Ignored for non-numeric types. Null means no maximum.
  final num? maxValue;

  /// Regex pattern for string validation.
  ///
  /// Applied via [RegExp.hasMatch]. If [pattern] is null or empty
  /// the string passes without check. The pattern is not anchored
  /// by default — callers should wrap in ^...$ if a full match is needed.
  final String? pattern;

  /// Allowed enum values for enum types.
  ///
  /// Populates a dropdown with these options. Must be non-empty when
  /// [type] is "enum". Null or empty renders a text field instead.
  final List<String>? enumOptions;

  /// Display names for each enum option (same index as [enumOptions]).
  ///
  /// If null or shorter than [enumOptions], the option value itself is
  /// used as the display label. Useful for showing "Active States"
  /// when the stored value is "active".
  final List<String>? enumDisplayNames;

  /// Default value when creating a new instance.
  ///
  /// Populated into the form when adding a new node of this type.
  /// Can be any JSON-serialisable type. Null means no default.
  final dynamic defaultValue;

  /// Input formatter names, e.g. ["uppercase", "maxLength:2"].
  ///
  /// Applied by the widget layer to constrain user input.
  /// Unknown formatter names are silently ignored.
  final List<String>? inputFormatters;

  const FieldDescriptor({
    required this.key,
    required this.label,
    required this.type,
    this.sectionLabel,
    this.sectionOrder = 0,
    this.required = false,
    this.minValue,
    this.maxValue,
    this.pattern,
    this.enumOptions,
    this.enumDisplayNames,
    this.defaultValue,
    this.inputFormatters,
  });
}

/// Describes a directed relationship between two [TypeDescriptor]s.
///
/// Used by the tree view, tab bar, and navigation breadcrumbs to
/// determine which types are connected and how to label the connection.
/// Relationships are directional: parent→child defines hierarchy,
/// while related→current defines peer associations.
class TypeRelationDescriptor {
  /// Semantic name of the relation, e.g. "contains", "belongs_to".
  ///
  /// Determines the arrow label in topology views and the tooltip in
  /// tree nodes. An empty string renders a generic "Related" label.
  final String relationName;

  /// The [TypeDescriptor.typeName] of the related (target) type.
  ///
  /// Must match a [TypeDescriptor.typeName] returned by the data source.
  /// A mismatch results in a dangling reference — the UI skips it
  /// gracefully with a warning log.
  final String childTypeName;

  /// Human-readable plural label for UI tab headers, e.g. "Sensors".
  ///
  /// Displayed as the tab title and as a section header in the
  /// related-items panel. Falls back to [childTypeName] if empty.
  final String childLabel;

  const TypeRelationDescriptor({
    required this.relationName,
    required this.childTypeName,
    required this.childLabel,
  });
}
