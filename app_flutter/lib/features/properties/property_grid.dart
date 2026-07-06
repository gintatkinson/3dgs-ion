import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';

/// Converts all input characters to uppercase in a text field.
///
/// Exists to enforce a consistent uppercase display format for fields whose
/// [FieldDescriptor.inputFormatters] contains the `"uppercase"` literal. Use
/// this when the data source expects uppercase identifiers (e.g., asset codes,
/// serial numbers).
///
/// Edge cases: operates on every keystroke via [TextEditingValue]; an empty
/// string remains empty. Non-letter characters are unaffected.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Editable property grid that displays [FieldDescriptor] fields grouped by
/// section and emits validated data on blur.
///
/// Exists to provide a generic, schema-driven form for editing typed objects
/// whose structure is not known at compile time (e.g., nodes from an external
/// data source). Use this widget whenever you need inline editing of structured
/// properties with validation, enum dropdowns, and blur-based commit.
///
/// Configuration options:
///   - [wideLayoutBreakpoint] controls the responsive breakpoint at which the
///     grid switches from single-column to two-column layout.
///   - [sectionPadding], [gapSize], [cardBorderRadius], and
///     [inputBorderRadius] let you tune the visual appearance of section cards
///     and input fields without rebuilding the widget tree.
///
/// Edge cases:
///   - An empty [fields] list renders a no-op grid with nothing to edit.
///   - [initialValues] may omit keys present in [fields]; those fields start
///     with an empty string.
///   - Validation errors for each field are displayed inline below the input;
///     they are cleared when the field passes validation on blur.
///
/// State changes: committed data is accumulated in `committedData` and emitted
/// via [onSave] on each successful blur. This widget does NOT start any
/// long-lived streams or timers. All controllers and focus nodes are disposed
/// in [dispose].
class PropertyGrid extends StatefulWidget {
  /// The list of field descriptors to display. When empty the grid renders
  /// nothing editable.
  final List<FieldDescriptor> fields;

  /// Initial values keyed by [FieldDescriptor.key]. Keys present in
  /// [initialValues] but absent from [fields] are silently ignored. Missing
  /// keys render as empty strings.
  final Map<String, dynamic> initialValues;

  /// Called with the current committed data after a field passes validation on
  /// blur. Not called if validation fails. The callback receives a fresh
  /// `Map<String, dynamic>` of the entire committed state, not just the edited
  /// field. Can be null to opt out of save notifications.
  final void Function(Map<String, dynamic>)? onSave;

  /// The currently active view name used to highlight the matching section.
  /// When set to `'root'`, the first section (alphabetically) is highlighted.
  /// Sections whose [FieldDescriptor.sectionLabel] does not match are dimmed.
  final String activeView;

  /// Responsive breakpoint at which the layout switches from single-column to
  /// two-column grid. Defaults to 700.0.
  final double wideLayoutBreakpoint;

  /// Padding applied inside each section card. Defaults to
  /// `EdgeInsets.all(20.0)`.
  final EdgeInsetsGeometry sectionPadding;

  /// Uniform gap used between fields and sections. Defaults to 8.0.
  final double gapSize;

  /// Border radius used for section cards. Defaults to
  /// `BorderRadius.circular(12.0)`.
  final BorderRadiusGeometry cardBorderRadius;

  /// Border radius used for text field and dropdown input borders. Defaults to
  /// `BorderRadius.circular(6.0)`.
  final BorderRadius inputBorderRadius;

  /// Creates a [PropertyGrid] with the given field descriptors, initial values,
  /// and visual configuration.
  ///
  /// All visual parameters have sensible defaults so that a basic grid works
  /// out of the box. Override them to match a specific design system:
  ///
  ///   - [wideLayoutBreakpoint] — when the available width exceeds this value,
  ///     the first two sections render side-by-side; below it they stack.
  ///   - [sectionPadding] — whitespace inside each section's card container.
  ///   - [gapSize] — vertical spacing between fields and sections.
  ///   - [cardBorderRadius] — corner rounding for section cards.
  ///   - [inputBorderRadius] — corner rounding for text field and dropdown
  ///     input borders.
  const PropertyGrid({
    super.key,
    this.fields = const [],
    this.initialValues = const {},
    this.onSave,
    this.activeView = 'root',
    this.wideLayoutBreakpoint = 700.0,
    this.sectionPadding = const EdgeInsets.all(20.0),
    this.gapSize = 8.0,
    this.cardBorderRadius = const BorderRadius.all(Radius.circular(12.0)),
    this.inputBorderRadius = const BorderRadius.all(Radius.circular(6.0)),
  });

  @override
  State<PropertyGrid> createState() => _PropertyGridState();
}

const _inactiveSectionOpacity = 0.65;
const _activeShadowOpacity = 0.1;
const _inactiveShadowOpacity = 0.05;
const _activeBadgeBgOpacity = 0.15;
const _activeBadgeBorderOpacity = 0.3;

class _PropertyGridState extends State<PropertyGrid> {
  late List<FieldDescriptor> _fields;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  Map<String, String> _errors = const {};
  final Map<String, bool> _hadFocus = {};
  bool _isDisposingFields = false;

  late Map<String, dynamic> committedData;

  @override
  void initState() {
    super.initState();
    _fields = widget.fields;
    committedData = Map<String, dynamic>.from(widget.initialValues);
    _initializeFields(_fields, committedData);
  }

  /// Creates a [TextEditingController] and [FocusNode] for every field in
  /// [fields], seeding each controller with the value from [nodeData].
  ///
  /// Enum fields do not receive a focus listener because their value is
  /// committed immediately on selection change rather than on blur.
  void _initializeFields(List<FieldDescriptor> fields, Map<String, dynamic> nodeData) {
    for (final field in fields) {
      final val = nodeData[field.key];
      final text = val != null ? val.toString() : '';
      final controller = TextEditingController(text: text);
      final focusNode = FocusNode();

      _controllers[field.key] = controller;
      _focusNodes[field.key] = focusNode;
      _hadFocus[field.key] = false;

      if (field.type != 'enum') {
        focusNode.addListener(() {
          if (_isDisposingFields) return;
          final bool currentlyHasFocus = focusNode.hasFocus;
          final bool previouslyHadFocus = _hadFocus[field.key] ?? false;
          _hadFocus[field.key] = currentlyHasFocus;

          if (previouslyHadFocus && !currentlyHasFocus) {
            _triggerBlurSave(field.key, field);
          }
        });
      }
    }
  }

  /// Disposes all [TextEditingController] and [FocusNode] instances, then
  /// clears internal maps and resets the error state.
  ///
  /// Called from [dispose] and from [didUpdateWidget] when the field list
  /// changes. After this method returns the widget is left in a clean state
  /// ready for [_initializeFields] to re-create everything.
  void _disposeAllFields() {
    _isDisposingFields = true;
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _hadFocus.clear();
    _errors = const {};
    _isDisposingFields = false;
  }

  @override
  void didUpdateWidget(PropertyGrid oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldFields = oldWidget.fields;
    final newFields = widget.fields;

    bool fieldsChanged = oldFields.length != newFields.length;
    if (!fieldsChanged) {
      for (int i = 0; i < newFields.length; i++) {
        if (oldFields[i].key != newFields[i].key ||
            oldFields[i].type != newFields[i].type ||
            oldFields[i].sectionLabel != newFields[i].sectionLabel) {
          fieldsChanged = true;
          break;
        }
      }
    }

    if (fieldsChanged) {
      setState(() {
        _disposeAllFields();
        _fields = newFields;
        committedData = Map<String, dynamic>.from(widget.initialValues);
        _initializeFields(_fields, committedData);
      });
    } else {
      setState(() {
        committedData = Map<String, dynamic>.from(widget.initialValues);
        _errors = const {};
        for (final field in _fields) {
          final focusNode = _focusNodes[field.key];
          if (focusNode != null && !focusNode.hasFocus) {
            final newVal = widget.initialValues[field.key] ?? committedData[field.key];
            final text = newVal != null ? newVal.toString() : '';
            _controllers[field.key]?.text = text;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _disposeAllFields();
    super.dispose();
  }

  /// Validates a field's string value according to the rules declared on
  /// [field].
  ///
  /// Returns a tuple of (isValid, parsedValue, errorMessage):
  ///   - [isValid] is true when all checks pass.
  ///   - [parsedValue] is the value coerced to `double`, `int`, or kept as
  ///     `String` depending on [field.type].
  ///   - [error] is a human-readable message when validation fails, or null
  ///     on success.
  ///
  /// Checks performed in order: required (non-empty), numeric parse,
  /// regex pattern, numeric bounds. Validation is skipped entirely when
  /// [valueString] is empty and the field is not required, allowing optional
  /// fields to remain blank.
  (bool isValid, dynamic parsedValue, String? error) _validateField(
    String key, FieldDescriptor field, String valueString,
  ) {
    dynamic parsedValue;

    if (field.required && valueString.trim().isEmpty) {
      return (false, null, '${field.label} is required');
    }

    if (field.type == 'double') {
      final val = double.tryParse(valueString);
      if (val == null && valueString.isNotEmpty) {
        return (false, null, 'Must be a valid double');
      }
      parsedValue = val;
    } else if (field.type == 'int') {
      final val = int.tryParse(valueString);
      if (val == null && valueString.isNotEmpty) {
        return (false, null, 'Must be a valid integer');
      }
      parsedValue = val;
    } else {
      parsedValue = valueString;
    }

    if (field.pattern != null && valueString.isNotEmpty) {
      final reg = RegExp(field.pattern!);
      if (!reg.hasMatch(valueString)) {
        return (false, parsedValue, 'Invalid format');
      }
    }

    if (parsedValue is num) {
      if (field.minValue != null && parsedValue < field.minValue!) {
        return (false, parsedValue, 'Value cannot be less than ${field.minValue}');
      }
      if (field.maxValue != null && parsedValue > field.maxValue!) {
        return (false, parsedValue, 'Value cannot be greater than ${field.maxValue}');
      }
    }

    return (true, parsedValue, null);
  }

  /// Validates the current value of [field] on blur and, if valid, commits it
  /// to [committedData] and fires [widget.onSave].
  ///
  /// For enum fields the value is read from [committedData] (already updated
  /// by the dropdown's onChanged); for all other types it is read from the
  /// associated [TextEditingController].
  ///
  /// On validation failure the error message is stored in [_errors] and
  /// displayed inline below the input. The callback is NOT fired on failure so
  /// that callers only see consistent, valid state snapshots.
  void _triggerBlurSave(String key, FieldDescriptor field) {
    if (!mounted) return;
    final valueString = field.type == 'enum'
        ? (committedData[key]?.toString() ?? '')
        : (_controllers[key]?.text ?? '');
    final Map<String, String> newErrors = Map<String, String>.from(_errors);

    final (bool isValid, dynamic parsedValue, String? error) = _validateField(key, field, valueString);

    setState(() {
      if (isValid) {
        newErrors.remove(key);
      } else {
        newErrors[key] = error ?? 'Invalid value';
      }
      _errors = newErrors;
    });

    if (isValid) {
      setState(() {
        committedData[key] = parsedValue;
      });

      widget.onSave?.call(Map<String, dynamic>.from(committedData));
    }
  }

  /// Resolves the list of [TextInputFormatter]s declared on [field].
  ///
  /// Supported [FieldDescriptor.inputFormatters] directives:
  ///   - `"uppercase"` — applies [UpperCaseTextFormatter].
  ///   - `"maxLength:N"` — applies [LengthLimitingTextInputFormatter] with
  ///     limit N.
  ///
  /// Returns null when no formatters are configured, which allows callers to
  /// pass null directly to the [TextField.inputFormatters] parameter.
  List<TextInputFormatter>? _resolveInputFormatters(FieldDescriptor field) {
    if (field.inputFormatters == null || field.inputFormatters!.isEmpty) return null;
    final List<TextInputFormatter> formatters = [];
    for (final fmt in field.inputFormatters!) {
      if (fmt == 'uppercase') {
        formatters.add(UpperCaseTextFormatter());
      } else if (fmt.startsWith('maxLength:')) {
        final parts = fmt.split(':');
        if (parts.length == 2) {
          final len = int.tryParse(parts[1]);
          if (len != null) {
            formatters.add(LengthLimitingTextInputFormatter(len));
          }
        }
      }
    }
    return formatters.isNotEmpty ? formatters : null;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final panelOpacity = context.watch<ThemeController>().panelOpacity;

    final groups = <String>{};
    for (final field in _fields) {
      groups.add(field.sectionLabel ?? 'Other');
    }

    final List<String> sortedGroups = groups.toList();
    sortedGroups.sort();

    final List<Widget> sections = sortedGroups.map((group) {
      final bool isActive = group == widget.activeView ||
          (widget.activeView == 'root' && group == sortedGroups.first);

      return _buildSystemSection(
        title: group,
        isActive: isActive,
        isDark: isDark,
        child: _buildGroupFields(group, isDark, panelOpacity),
        panelOpacity: panelOpacity,
      );
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth.isFinite ? constraints.maxWidth : 350.0;
              final int columnCount = (width / 350.0).floor().clamp(1, 4);
              final double cardWidth = (width - (columnCount - 1) * widget.gapSize) / columnCount - 0.01;

              return Wrap(
                spacing: widget.gapSize,
                runSpacing: widget.gapSize,
                children: sections.map((sec) => SizedBox(width: cardWidth, child: sec)).toList(),
              );
            },
          ),
          SizedBox(height: widget.gapSize),
          ElevatedButton(
            key: const Key('save_properties_button'),
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: const Text('Save'),
          ),
          SizedBox(height: widget.gapSize),
          _buildCommittedStatePanel(isDark, panelOpacity),
        ],
      ),
    );
  }

  /// Builds a single section card with a title header, an optional "Active
  /// Reference" badge, and the field content.
  ///
  /// The [isActive] flag controls opacity, border width, border color, and
  /// shadow intensity. Active sections use [widget.cardBorderRadius] and the
  /// primary brand color for their border and shadow; inactive sections are
  /// dimmed with a subtler shadow and a neutral border.
  ///
  /// The [width] parameter is applied to the outer container so that sections
  /// can be laid out side-by-side by the caller.
  Widget _buildSystemSection({
    required String title,
    required bool isActive,
    required bool isDark,
    required Widget child,
    required double panelOpacity,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color brandPrimary = cs.primary;
    final Color borderColor = Theme.of(context).dividerColor;
    final Color surfaceFill = cs.surfaceContainerHighest.withOpacity(panelOpacity);
    final Color borderActive = brandPrimary;

    return Opacity(
      opacity: isActive ? 1.0 : _inactiveSectionOpacity,
      child: Container(
        padding: widget.sectionPadding,
        decoration: BoxDecoration(
          color: surfaceFill,
          borderRadius: widget.cardBorderRadius,
          border: Border.all(
            color: isActive ? borderActive : borderColor,
            width: isActive ? 2.0 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: brandPrimary.withValues(alpha: _activeShadowOpacity),
                    blurRadius: 24.0,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withValues(alpha: _inactiveShadowOpacity),
                    blurRadius: 20.0,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: _activeBadgeBgOpacity),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: _activeBadgeBorderOpacity),
                        ),
                      ),
                      child: Text(
                        'Active Reference',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
              ],
            ),
            SizedBox(height: widget.gapSize),
            child,
          ],
        ),
      ),
    );
  }

  /// Builds all fields belonging to [group], sorted by [FieldDescriptor.sectionOrder].
  ///
  /// Each field is separated by [widget.gapSize] of vertical space. An empty
  /// group renders an empty [Column] with no visible output.
  Widget _buildGroupFields(String group, bool isDark, double panelOpacity) {
    final groupFields = _fields
        .where((field) => (field.sectionLabel ?? 'Other') == group)
        .toList()
      ..sort((a, b) {
        final int cmp = a.sectionOrder.compareTo(b.sectionOrder);
        if (cmp != 0) return cmp;
        return _naturalCompare(a.key, b.key);
      });

    final List<Widget> fields = [];
    for (final field in groupFields) {
      fields.add(_buildAttrField(field, isDark, panelOpacity));
      fields.add(SizedBox(height: widget.gapSize));
    }

    if (fields.isNotEmpty) {
      fields.removeLast();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fields,
    );
  }

  /// Builds the input widget for a single [field], dispatching to either a
  /// dropdown (for `enum` fields) or a text field (for all other types).
  ///
  /// The dispatched type is determined by [FieldDescriptor.type]. Numeric
  /// fields (`double`, `int`) receive the appropriate keyboard type.
  /// The current error state, if any, is passed down from [_errors].
  ///
  /// Edge cases: enum fields with no options render an empty dropdown with
  /// the first available option implicitly selected; missing enum options or
  /// missing display names are handled gracefully (falling back to the raw
  /// value or index).
  Widget _buildAttrField(FieldDescriptor field, bool isDark, double panelOpacity) {
    final cs = Theme.of(context).colorScheme;
    final Color brandPrimary = cs.primary;

    if (field.type == 'enum') {
      final options = field.enumOptions ?? const [];
      final currentValue = committedData[field.key] ?? (options.isNotEmpty ? options.first : '');

      return _buildDropdownField(
        label: field.label,
        focusNode: _focusNodes[field.key]!,
        value: currentValue as String,
        errorText: _errors[field.key],
        isDark: isDark,
        brandPrimary: brandPrimary,
        panelOpacity: panelOpacity,
        items: options.asMap().entries.map((entry) {
          final int idx = entry.key;
          final String opt = entry.value;
          String displayName = opt;
          if (field.enumDisplayNames != null && idx < field.enumDisplayNames!.length) {
            displayName = field.enumDisplayNames![idx];
          }
          return DropdownMenuItem<String>(
            value: opt,
            child: Text(displayName),
          );
        }).toList(),
        onChanged: (String? val) {
          if (val != null) {
            setState(() {
              committedData[field.key] = val;
            });
            _triggerBlurSave(field.key, field);
          }
        },
      );
    } else {
      TextInputType keyboardType = TextInputType.text;
      List<TextInputFormatter>? inputFormatters;

      if (field.type == 'double') {
        keyboardType = const TextInputType.numberWithOptions(decimal: true);
      } else if (field.type == 'int') {
        keyboardType = TextInputType.number;
      }

      inputFormatters = _resolveInputFormatters(field);

      return _buildTextField(
        label: field.label,
        controller: _controllers[field.key]!,
        focusNode: _focusNodes[field.key]!,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        errorText: _errors[field.key],
        brandPrimary: brandPrimary,
        panelOpacity: panelOpacity,
      );
    }
  }

  /// Builds a labelled [TextField] bound to [controller] and [focusNode].
  ///
  /// The text field uses [widget.inputBorderRadius] for its [OutlineInputBorder]
  /// and displays [errorText] below the field when validation fails. The
  /// border color switches to the theme error color when an error is present
  /// and to [brandPrimary] when focused.
  ///
  /// The label is rendered above the field using the theme's `labelSmall` text
  /// style. Keyboard type and input formatters are forwarded to the
  /// [TextField] unchanged; pass null for [inputFormatters] when no
  /// formatting is required.
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    required Color brandPrimary,
    required double panelOpacity,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        SizedBox(height: widget.gapSize),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            filled: true,
            fillColor: cs.surface.withOpacity(panelOpacity),
            enabledBorder: OutlineInputBorder(
              borderRadius: widget.inputBorderRadius,
              borderSide: BorderSide(
                color: errorText != null
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).dividerColor,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: widget.inputBorderRadius,
              borderSide: BorderSide(
                color: errorText != null ? Theme.of(context).colorScheme.error : brandPrimary,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  /// Builds a labelled [DropdownButtonFormField] bound to [focusNode].
  ///
  /// The dropdown uses [widget.inputBorderRadius] for its [OutlineInputBorder]
  /// and displays [errorText] below the field when validation fails. Its
  /// background adjusts to the current brightness via [isDark] to remain
  /// legible in both light and dark themes.
  ///
  /// The label is rendered above the dropdown using the theme's `labelSmall`
  /// text style. The [onChanged] callback is typically wired to
  /// [_triggerBlurSave] so that enum value changes are committed immediately.
  Widget _buildDropdownField({
    required String label,
    required FocusNode focusNode,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? errorText,
    required bool isDark,
    required Color brandPrimary,
    required double panelOpacity,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        SizedBox(height: widget.gapSize),
          Focus(
            focusNode: focusNode,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              value: value,
            dropdownColor: (isDark ? cs.surfaceContainerHighest : cs.surface).withOpacity(panelOpacity),
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              filled: true,
              fillColor: cs.surface.withOpacity(panelOpacity),
              enabledBorder: OutlineInputBorder(
                borderRadius: widget.inputBorderRadius,
                borderSide: BorderSide(
                  color: errorText != null
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).dividerColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: widget.inputBorderRadius,
                borderSide: BorderSide(
                  color: errorText != null ? Theme.of(context).colorScheme.error : brandPrimary,
                  width: 1.5,
                ),
              ),
            ),
            items: items,
            onChanged: onChanged,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              errorText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  /// Builds a read-only panel showing the current [committedData] as
  /// pretty-printed JSON.
  ///
  /// Exists primarily for development and debugging workflows where operators
  /// need to inspect the accumulated committed values at a glance. The panel
  /// scrolls horizontally to accommodate wide payloads without wrapping.
  Widget _buildCommittedStatePanel(bool isDark, double panelOpacity) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(panelOpacity),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Committed Data (verified on blur)',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          SizedBox(height: widget.gapSize),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(panelOpacity),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                const JsonEncoder.withIndent('  ').convert(committedData),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _naturalCompare(String a, String b) {
    final RegExp regExp = RegExp(r'(\d+)|(\D+)');
    final Iterable<Match> matchesA = regExp.allMatches(a);
    final Iterable<Match> matchesB = regExp.allMatches(b);
    
    final List<String> chunksA = matchesA.map((m) => m.group(0)!).toList();
    final List<String> chunksB = matchesB.map((m) => m.group(0)!).toList();
    
    final int minLen = chunksA.length < chunksB.length ? chunksA.length : chunksB.length;
    for (int i = 0; i < minLen; i++) {
      final String chunkA = chunksA[i];
      final String chunkB = chunksB[i];
      
      final bool isDigitA = RegExp(r'^\d+$').hasMatch(chunkA);
      final bool isDigitB = RegExp(r'^\d+$').hasMatch(chunkB);
      
      if (isDigitA && isDigitB) {
        final int valA = int.parse(chunkA);
        final int valB = int.parse(chunkB);
        final int cmp = valA.compareTo(valB);
        if (cmp != 0) return cmp;
      } else {
        final int cmp = chunkA.compareTo(chunkB);
        if (cmp != 0) return cmp;
      }
    }
    return chunksA.length.compareTo(chunksB.length);
  }
}
