import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/features/properties/property_grid.dart';
import 'package:app_flutter/features/tree/view_models/tree_view_model.dart';
import 'package:app_flutter/features/layout/layout_config_service.dart';
import 'package:app_flutter/features/topology/topology_map.dart';
import 'package:app_flutter/features/topology/topology_defaults.dart' show emptyTopologyData, loadTopologyData;
import 'package:app_flutter/features/layout/component_factory.dart';
import 'package:app_flutter/features/properties/view_models/properties_view_model.dart';
import 'package:app_flutter/core/background_worker.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';

/// Root layout widget that parses a logical-layout JSON and builds the full
/// Flutter widget hierarchy (sidebar, split panes, topology, tabs, property
/// grid).
///
/// Realises UML::Layout. Initialises [TreeViewModel], [PropertiesViewModel],
/// a [BackgroundWorker], and topology data on first build. Coordinates view
/// selection across all child components: when a view is selected,
/// [_selectView] updates the current view, subscribes to properties, and
/// notifies the tree view model.
///
/// Edge cases: if [layoutConfig] is null, loads from the bundled
/// `assets/logical-layout.json` asset. If the active view changes via widget
/// properties, properties subscription and view model are re-synced. Missing
/// JSON files in [_loadJsonOnce] return empty maps (no crash). Layout config
/// loading failures are logged and the UI shows a [CircularProgressIndicator]
/// until [parsedLayout] is ready.
class Layout extends StatefulWidget {
  final String? activeView;
  final ValueChanged<String>? onViewChange;
  final String? layoutConfig;

  Layout({
    super.key,
    this.activeView,
    this.onViewChange,
    this.layoutConfig,
  });

  @override
  State<Layout> createState() => _LayoutState();
}

class _LayoutState extends State<Layout> {
  // Navigation & Tree Selection
  late String _currentView;

  // Data Source
  DataSource? _dataSource;
  StreamSubscription<Map<String, dynamic>>? _propertiesSubscription;
  Map<String, dynamic> _nodeData = const {};

  // Tree ViewModel
  TreeViewModel? _treeViewModel;

  // Properties ViewModel
  PropertiesViewModel? _propertiesViewModel;

  static const double _minPaneSize = 150.0;

  bool _layoutInitialized = false;

  /// Subscribes to property changes for the given [nodeId].
  ///
  /// Cancels any previous subscription before creating a new one. Updates
  /// [_nodeData] on each data event and triggers a rebuild. Errors are logged
  /// via [debugPrint].
  void _subscribeProperties(String nodeId) {
    _propertiesSubscription?.cancel();
    _nodeData = const {};
    _propertiesSubscription = _dataSource!.watchProperties(nodeId).listen(
      (data) {
        if (mounted) {
          setState(() {
            _nodeData = data;
          });
        }
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('watchProperties error: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dataSource == null) {
      _dataSource = context.read<DataSource>();
      _subscribeProperties(_currentView);
    }
    if (_treeViewModel == null) {
      final dataSource = context.read<DataSource>();
      _treeViewModel = TreeViewModel(
        dataSource,
        initialView: _currentView,
        onViewSelected: _selectView,
      )
        ..addListener(_onTreeViewModelChanged)
        ..loadTree();
    }
    if (_propertiesViewModel == null) {
      final dataSource = context.read<DataSource>();
      _propertiesViewModel = PropertiesViewModel(dataSource)
        ..addListener(_onPropertiesViewModelChanged)
        ..loadType(_currentView);
    }
  }

  /// Triggers a rebuild when the properties view model notifies listeners.
  void _onPropertiesViewModelChanged() {
    if (mounted) setState(() {});
  }

  /// Rebuilds the UI and syncs the current view from the tree when the tree
  /// view model notifies listeners.
  void _onTreeViewModelChanged() {
    if (mounted) {
      _updateCurrentViewFromLayout();
      setState(() {});
    }
  }

  // Background Worker
  BackgroundWorker? _worker;
  StreamSubscription<int>? _workerSubscription;

  // Parsed configuration map
  Map<String, dynamic>? _parsedLayout;

  // Cached JSON files
  Map<String, dynamic>? _cachedRules;
  Map<String, dynamic>? _cachedLabels;

  /// Loads a JSON file from disk, caching results by type.
  ///
  /// Checks [path] and `../$path` for the file; returns an empty map if
  /// neither exists or parsing fails. Caches `codebase_rules` and `labels`
  /// files separately so repeated calls avoid I/O.
  Map<String, dynamic> _loadJsonOnce(String path) {
    if (_cachedRules != null && path.contains('codebase_rules')) return _cachedRules!;
    if (_cachedLabels != null && path.contains('labels')) return _cachedLabels!;
    try {
      for (final candidate in [path, '../$path']) {
        final file = File(candidate);
        if (file.existsSync()) {
          final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
          if (path.contains('codebase_rules')) _cachedRules = data;
          if (path.contains('labels')) _cachedLabels = data;
          return data;
        }
      }
    } catch (_) {}
    return {};
  }

  // Properties Reactive State

  /// Preloaded topology data from external JSON asset; null until loaded.
  TopologyData? _topologyData;
  TopologyData? _cachedTopologyData;

  @override
  void initState() {
    super.initState();

    if (widget.layoutConfig != null) {
      _parsedLayout = jsonDecode(widget.layoutConfig!) as Map<String, dynamic>;
    } else {
      _loadLayoutConfig();
    }

    _currentView = widget.activeView ?? 'root';

    _worker = BackgroundWorker()..start();
    _workerSubscription = _worker!.results.listen((_) {
      if (mounted) setState(() {});
    });

    _preloadTopologyData();
  }

  /// Preloads topology data from an external JSON asset for later use.
  ///
  /// Called once during init. Stores the result in [_topologyData]; errors are
  /// logged and do not crash the widget.
  Future<void> _preloadTopologyData() async {
    try {
      final dataSource = context.read<DataSource>();
      var data = await dataSource.fetchTopologyData();
      if (data.nodes.isEmpty) {
        data = await loadTopologyData();
      }
      if (mounted) {
        setState(() {
          _topologyData = data;
          _cachedTopologyData = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading topology data: $e');
    }
  }

  @override
  void didUpdateWidget(covariant Layout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeView != null && widget.activeView != oldWidget.activeView) {
      if (_currentView != widget.activeView) {
        setState(() {
          _currentView = widget.activeView!;
        });
        _subscribeProperties(_currentView);
        _propertiesViewModel?.loadType(_currentView);
      }
    }
  }

  @override
  void dispose() {
    _propertiesSubscription?.cancel();
    _workerSubscription?.cancel();
    _worker?.dispose();
    _treeViewModel?.removeListener(_onTreeViewModelChanged);
    _treeViewModel?.dispose();
    _propertiesViewModel?.removeListener(_onPropertiesViewModelChanged);
    _propertiesViewModel?.dispose();
    super.dispose();
  }

  /// Returns the default split ratio for the properties panel.
  ///
  /// Reads from the codebase rules JSON; falls back to 0.5 if the rule is
  /// missing.
  double _getDefaultRatio() {
    final rules = _loadJsonOnce('.pipeline/logical-ui/codebase_rules.json');
    return getDefaultRatio(rules, 'layout_properties.default_ratio', 0.5);
  }

  /// Resolves the coordinate-to-location mapping from codebase rules.
  Map<String, String> _resolveCoordinateMapping() {
    final rules = _loadJsonOnce('.pipeline/logical-ui/codebase_rules.json');
    return resolveCoordinateMapping(rules);
  }

  /// Resolves the label mapping from codebase rules.
  Map<String, String> _resolveLabelsMapping() {
    final rules = _loadJsonOnce('.pipeline/logical-ui/codebase_rules.json');
    return resolveLabelsMapping(rules);
  }

  /// Returns a human-readable label for the given [tabId].
  ///
  /// Uses the resolved label mapping first; falls back to hardcoded defaults
  /// for known tab IDs (Items, Status, Activity). Returns the raw [tabId] as a
  /// last resort.
  String _resolveTabLabel(String tabId) {
    final mapping = _resolveLabelsMapping();
    for (final entry in mapping.entries) {
      if (tabId.contains(entry.key)) {
        return entry.value;
      }
    }
    final words = tabId.split('_');
    final capitalized = words.map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
    return capitalized;
  }

  // TODO(#79): Replace mock topology nodes/links with DB-backed data.
  /// Builds a [TopologyData] with the coordinate mapping applied.
  ///
  /// Uses preloaded [_topologyData] if available, otherwise falls back to
  /// [emptyTopologyData].
  TopologyData _resolveTopologyData() {
    if (_cachedTopologyData != null) {
      return _cachedTopologyData!;
    }
    final mapping = _resolveCoordinateMapping();
    final data = _topologyData ?? emptyTopologyData;
    _cachedTopologyData = TopologyData(
      coordinateMapping: mapping,
      nodes: data.nodes,
      links: data.links,
    );
    return _cachedTopologyData!;
  }


  /// Loads the logical layout configuration from the bundled assets.
  ///
  /// Reads `assets/logical-layout.json` and updates the parsed layout and
  /// current view on success. Errors are logged via [debugPrint].
  Future<void> _loadLayoutConfig() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/logical-layout.json');
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _parsedLayout = parsed;
          _updateCurrentViewFromLayout();
        });
      }
    } catch (e) {
      debugPrint('Error loading layout configuration: $e');
    }
  }

  /// Updates [_currentView] to the root of the tree data when no explicit
  /// active view is set externally.
  ///
  /// Called after the tree view model loads or changes. If
  /// [widget.activeView] is null and tree data is available, sets the current
  /// view to the first tree node and resubscribes properties.
  void _updateCurrentViewFromLayout() {
    if (_layoutInitialized) return;
    if (_treeViewModel == null || _treeViewModel!.treeData.isEmpty) return;
    if (widget.activeView == null && _currentView == 'root') {
      _currentView = _treeViewModel!.treeData.first.id;
      _subscribeProperties(_currentView);
      _propertiesViewModel?.loadType(_currentView);
    }
    _layoutInitialized = true;
  }

  /// Selects a view by [viewId], updating state, tree model, properties, and
  /// notifying the parent widget.
  ///
  /// No-op if [viewId] equals [_currentView]. Resubscribes to properties for
  /// the new view and reloads the properties view model type.
  void _selectView(String viewId) {
    if (_currentView == viewId) return;
    setState(() {
      _currentView = viewId;
    });
    _treeViewModel?.updateCurrentView(viewId);
    _subscribeProperties(viewId);
    _propertiesViewModel?.loadType(viewId);
    widget.onViewChange?.call(viewId);
  }

  /// Builds the full widget tree from the parsed layout configuration.
  ///
  /// Delegates to [ComponentFactory] with the current view, callbacks, and
  /// resolvers. Constrained by [constraints] from the parent [LayoutBuilder].
  Widget _buildFromLayout(BuildContext context, BoxConstraints constraints) {
    final preferredSplitAxis = context.watch<ThemeController>().layoutSplitAxis;
    final factory = ComponentFactory(
      currentView: _currentView,
      workerResult: _worker?.lastResult,
      onViewSelected: _selectView,
      minPaneSize: _minPaneSize,
      defaultRatio: _getDefaultRatio,
      resolveTopologyData: _resolveTopologyData,
      resolveTabLabel: _resolveTabLabel,
      buildChildWidget: _buildChildWidget,
      treeViewModel: _treeViewModel,
      preferredSplitAxis: preferredSplitAxis,
    );
    final rootNode = _parsedLayout!['layout']['root_container']
        as Map<String, dynamic>;
    return factory.build(rootNode, constraints.maxWidth, constraints.maxHeight, context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _parsedLayout == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) =>
                  _buildFromLayout(context, constraints),
            ),
    );
  }

  /// Builds the child widget displayed in the properties panel.
  ///
  /// Creates a [PropertyGrid] with the current fields, values, and a save
  /// callback. Used as a builder callback by [ComponentFactory].
  Widget _buildChildWidget(BuildContext context) {
    final fields = _propertiesViewModel?.fields ?? [];

    return PropertyGrid(
      activeView: _currentView,
      fields: fields,
      initialValues: _nodeData,
      onSave: (Map<String, dynamic> data) async {
        await _dataSource!.saveProperties(_currentView, data);
      },
    );
  }
}
