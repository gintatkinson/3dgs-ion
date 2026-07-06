import 'package:flutter/material.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';

/// Loads a [TypeDescriptor] from the data source and exposes its fields to the
/// property grid widget.
///
/// Exists to decouple the property grid from the data-fetching logic. Use this
/// view model whenever the property panel needs to display a node's fields.
///
/// Edge cases: if [typeName] is unknown to the data source, `loadType` sets
/// [_currentType] to `null`; [fields] then returns an empty list and [hasType]
/// returns `false`. No error is surfaced to the caller — the grid reacts by
/// showing nothing.
///
/// State changes: each call to [loadType] replaces the previous type and calls
/// [notifyListeners]; the widget layer is expected to rebuild in response.
class PropertiesViewModel extends ChangeNotifier {
  PropertiesViewModel(this._dataSource);
  final DataSource _dataSource;

  TypeDescriptor? _currentType;
  bool _disposed = false;
  String? _activeTypeName;

  /// The fields of the currently loaded type. Returns an empty list when no
  /// type has been loaded or `loadType` returned `null`.
  List<FieldDescriptor> get fields => _currentType?.fields ?? [];

  /// Whether a type has been loaded (i.e., [loadType] completed with a
  /// non-null [TypeDescriptor]).
  bool get hasType => _currentType != null;

  /// Fetches the [TypeDescriptor] for [typeName] from the data source and
  /// notifies listeners.
  ///
  /// If the data source returns `null` (unknown type), [_currentType] is set
  /// to `null`, [fields] becomes empty, and [hasType] becomes false. Does not
  /// throw — callers should check [hasType] if they need to distinguish.
  /// Replaces any previously loaded type unconditionally.
  Future<void> loadType(String typeName) async {
    _activeTypeName = typeName;
    final result = await _dataSource.typeFor(typeName);
    if (_disposed) return;
    if (_activeTypeName != typeName) return;
    _currentType = result;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
