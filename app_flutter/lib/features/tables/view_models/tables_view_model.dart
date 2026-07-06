import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_flutter/domain/column_model.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/instance_record.dart';
import 'package:app_flutter/domain/type_descriptor.dart';

/// Metadata for a single tab in the table view, derived from either a child
/// type or a related type of the current [TypeDescriptor].
///
/// Exists to pair a display label with the column schema ([columns]) needed to
/// render a tab's table. Created by [TablesViewModel] during discovery.
class TabDescriptor {
  final String id;
  final String label;
  final TypeDescriptor type;

  const TabDescriptor({
    required this.id,
    required this.label,
    required this.type,
  });
}

/// Drives the tabbed table view by discovering tabs from the data source and
/// fetching tabular data asynchronously.
///
/// Exists to centralise data-source interaction for the tables feature and to
/// keep the widget layer free of async orchestration. Use this view model
/// wherever a [TabbedContainer] (or similar) needs reactive tab/table state.
///
/// Edge cases:
///   - If the data source returns `null` for a type descriptor (unknown node),
///     [loadForNode] exits early leaving [tabs] empty.
///   - Stale requests are abandoned using a monotonically increasing request
///     counter ([_requestId]) — responses for superseded requests are ignored.
///   - If all types resolve but no child/related types exist, [tabs] is empty,
///     [selectedTabId] is `null`, [loading] is `false`, and no data is fetched.
///   - [selectTab] receives a [tabId] that does not match any tab — this throws
///     because [firstWhere] without `orElse` is used; callers must ensure the
///     id is valid (typically via [tabs] state).
///
/// State changes: each public method ([loadForNode], [selectTab]) sets
/// [_loading] to `true`, clears errors, calls [notifyListeners], then fetches
/// data asynchronously. On completion, [_loading] is `false`, [headers],
/// [rows] are updated, and [notifyListeners] is called again. On failure,
/// [_error] is set, [rows] and [headers] are cleared, and a stack trace is
/// logged via [debugPrint].
class TablesViewModel extends ChangeNotifier {
  final DataSource _dataSource;
  String _activeView;
  List<TabDescriptor> _tabs = [];
  String? _selectedTabId;
  List<ColumnModel> _headers = [];
  Set<String>? _hiddenColumnKeys;
  List<List<String>> _rows = [];
  List<ColumnModel> _columnModels = [];
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  bool _disposed = false;

  final Map<(String, String), List<InstanceRecord>> _cache = {};
  StreamSubscription<Map<String, dynamic>>? _propertiesSubscription;

  TablesViewModel(this._dataSource, this._activeView) {
    _setupPropertiesSubscription(_activeView);
  }

  /// All discovered tabs for the current node. Empty until [loadForNode]
  /// completes successfully and the node has child/related types.
  List<TabDescriptor> get tabs => _tabs;

  /// The currently active tab identifier. Returns the first tab's id if none
  /// is explicitly selected, or an empty string when [tabs] is empty.
  String get tabId =>
      _selectedTabId ?? (_tabs.isNotEmpty ? _tabs.first.id : '');

  /// The currently active tab identifier. `null` before [loadForNode] or when
  /// no tabs exist.
  String? get selectedTabId => _selectedTabId;

  /// Column headers for the currently selected tab.
  List<ColumnModel> get headers => _headers;

  Set<String>? get hiddenColumnKeys => _hiddenColumnKeys;

  List<ColumnModel> get visibleColumnModels =>
      (_hiddenColumnKeys == null || _hiddenColumnKeys!.isEmpty
          ? _headers
          : _headers.where((cm) => !_hiddenColumnKeys!.contains(cm.key)))
          .where((cm) => cm.visible)
          .toList();

  /// Column models for the currently selected tab.
  List<ColumnModel> get columnModels => _columnModels;

  void setHiddenColumnKeys(Set<String>? keys) {
    _hiddenColumnKeys = keys;
    notifyListeners();
  }

  /// Loaded table rows for the currently selected tab.
  List<List<String>> get rows => _rows;

  /// Whether data is currently being fetched.
  bool get loading => _loading;

  /// Error message if the last fetch failed, or null.
  String? get error => _error;

  /// Discovers tabs and loads the first tab's data for the given [nodeId].
  ///
  /// Fetches the [TypeDescriptor] for [nodeId], then iterates
  /// [childTypes] and [relatedTypes] to build [tabs]. Once built, loads data
  /// for the first tab. If the data source returns `null`, this is a no-op
  /// (tabs remain empty). Stale responses (superseded by a newer call) are
  /// silently dropped via the [_requestId] counter.
  Future<void> loadForNode(String nodeId) async {
    final requestId = ++_requestId;
    _activeView = nodeId;
    _loading = true;
    _error = null;
    notifyListeners();
    _setupPropertiesSubscription(nodeId);

    try {
      final typeDescriptor = await _dataSource.typeFor(nodeId);
      if (typeDescriptor == null || requestId != _requestId) return;

      final List<TabDescriptor> tabs = [];

      // 1. Child types (hierarchy containment)
      for (final ct in typeDescriptor.childTypes) {
        final childDesc = await _dataSource.typeFor(ct.childTypeName);
        if (childDesc == null || requestId != _requestId) return;
        tabs.add(TabDescriptor(
          id: ct.childTypeName,
          label: ct.childLabel,
          type: childDesc,
        ));
      }

      // 2. Related types (events, alarms, etc.)
      for (final rt in typeDescriptor.relatedTypes) {
        final relDesc = await _dataSource.typeFor(rt.childTypeName);
        if (relDesc == null || requestId != _requestId) return;
        tabs.add(TabDescriptor(
          id: rt.childTypeName,
          label: rt.childLabel,
          type: relDesc,
        ));
      }

      if (requestId != _requestId) return;

      _tabs = tabs;
      if (tabs.isNotEmpty) {
        _selectedTabId = tabs.first.id;
        await _loadData(tabs.first, requestId);
      } else {
        _selectedTabId = null;
        _rows = [];
        _headers = [];
        _columnModels = [];
        _loading = false;
      }
      notifyListeners();
    } catch (e, st) {
      if (requestId != _requestId) return;
      _error = 'Failed to load table data';
      _rows = [];
      _headers = [];
      _columnModels = [];
      _loading = false;
      debugPrint('TablesViewModel.loadForNode error: $e\n$st');
      notifyListeners();
    }
  }

  /// Switches to the tab identified by [tabId] and loads its data.
  ///
  /// [tabId] must match one of the [tabs] identifiers (uses [firstWhere]
  /// without `orElse` — an unknown id throws [StateError]). Sets [_loading]
  /// to `true`, clears the error state, then calls [_loadData] to fetch rows.
  /// When the node no longer has the tab referenced by [tabId], callers should
  /// guard usage or call [loadForNode] first to refresh the tab list.
  Future<void> selectTab(String tabId) async {
    if (!_tabs.any((t) => t.id == tabId)) return;
    final tab = _tabs.firstWhere((t) => t.id == tabId);
    _selectedTabId = tabId;
    final requestId = ++_requestId;
    _loading = true;
    _error = null;
    notifyListeners();
    await _loadData(tab, requestId);
  }

  Future<void> _loadData(TabDescriptor tab, int requestId) async {
    try {
      _headers = tab.type.fields.map(ColumnModel.fromFieldDescriptor).toList();
      _columnModels = tab.type.fields.map(ColumnModel.fromFieldDescriptor).toList();

      final cacheKey = (_activeView, tab.type.typeName);
      final List<InstanceRecord> records;
      if (_cache.containsKey(cacheKey)) {
        records = _cache[cacheKey]!;
      } else {
        records = await _dataSource.fetchRelatedInstances(
          parentNodeId: _activeView,
          targetType: tab.type,
        );
        if (requestId != _requestId) return;
        _cache[cacheKey] = records;
      }

      final rows = records.map((record) {
        return tab.type.fields.map((f) => record.attributes[f.key]?.toString() ?? '').toList();
      }).toList();

      if (requestId != _requestId) return;

      _rows = rows;
      _loading = false;
      notifyListeners();
    } catch (e, st) {
      if (requestId != _requestId) return;
      _error = 'Failed to load table data';
      _rows = [];
      _headers = [];
      _columnModels = [];
      _loading = false;
      debugPrint('TablesViewModel._loadData error: $e\n$st');
      notifyListeners();
    }
  }

  void _setupPropertiesSubscription(String nodeId) {
    _propertiesSubscription?.cancel();
    bool isFirst = true;
    _propertiesSubscription = _dataSource.watchProperties(nodeId).listen(
      (data) {
        if (isFirst) {
          isFirst = false;
          return;
        }
        _cache.clear();
        if (_tabs.isNotEmpty && _selectedTabId != null) {
          final tab = _tabs.firstWhere((t) => t.id == _selectedTabId);
          _loadData(tab, _requestId);
        }
      },
      onError: (Object e) {
        debugPrint('TablesViewModel properties subscription error: $e');
      },
    );
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _propertiesSubscription?.cancel();
    super.dispose();
  }
}
