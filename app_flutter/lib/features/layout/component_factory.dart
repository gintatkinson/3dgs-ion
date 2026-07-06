import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/features/tree/view_models/tree_view_model.dart';
import 'package:app_flutter/features/tree/sidebar_tree.dart';
import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';

import 'package:app_flutter/features/layout/split_workspace.dart';
import 'package:app_flutter/features/tables/tabbed_container.dart';
import 'package:app_flutter/features/tables/table_view_widget.dart';
import 'package:app_flutter/features/topology/topographical_view.dart';
import 'package:app_flutter/features/topology/topology_map.dart';
/// Interprets a parsed logical-layout JSON tree and builds the corresponding
/// Flutter widget hierarchy: sidebar, split workspace, topology map,
/// tabbed containers, table views, and property grids.
///
/// Each layout node with a known `type` string (e.g. `"SidebarLayout"`,
/// `"HierarchyTreeSelector"`, `"SplitWorkspace"`, `"TopographicalView"`,
/// `"TabbedContainer"`, `"TableView"`) dispatches to a dedicated builder
/// method. Unknown types produce [SizedBox.shrink].
///
/// Dependencies (current view, topology data, tab labels, etc.) are provided
/// as callbacks rather than hard-coded so the same factory can be reused
/// across different layout configurations.
class ComponentFactory {
  /// The identifier of the currently selected view, used to select tabs,
  /// reload topology data, and highlight the active node in the sidebar.
  final String currentView;

  /// The last result emitted by the worker isolate, passed through so that
  /// [SidebarTree] can display progress or error states without re-linking
  /// the worker itself. `null` when no result has been produced yet.
  final int? workerResult;

  /// Callback invoked when the user selects a different view from the sidebar
  /// or the topology map. The receiver is expected to update [currentView].
  final void Function(String) onViewSelected;

  /// The minimum size (in logical pixels) for the first pane in a split
  /// layout ([SplitWorkspace], [TopographicalView]). Read from the layout
  /// configuration so that panes cannot be resized below a usable threshold.
  final double minPaneSize;

  /// Returns the default split ratio used when a [SplitWorkspace] or
  /// [TopographicalView] is first rendered. The value is resolved from the
  /// `codebase_rules.json` config token so it can be tuned without code
  /// changes.
  final double Function() defaultRatio;

  /// Resolves the [TopologyData] for the current view. Called lazily during
  /// build so that the topology provider can be fetched from the widget tree
  /// rather than passed at construction time.
  final TopologyData Function() resolveTopologyData;

  /// Resolves a human-readable label for the tab identified by the given
  /// string key. Used by [TabbedContainer] to render tab headers.
  final String Function(String) resolveTabLabel;

  /// Builds an arbitrary child widget inside a [TopographicalView]. The
  /// returned widget is inserted below the topology map and above the
  /// selection controls.
  final Widget Function(BuildContext) buildChildWidget;

  /// The [TreeViewModel] for the hierarchy tree sidebar. `null` when the
  /// current layout does not include a sidebar, in which case
  /// [HierarchyTreeSelector] is skipped entirely.
  final TreeViewModel? treeViewModel;

  /// The preferred split axis orientation for resizable workspaces.
  /// Overrides the configured axis when non-null.
  final Axis? preferredSplitAxis;

  /// Creates a [ComponentFactory] with the required dependency resolvers.
  ///
  /// All parameters are required except [treeViewModel] which may be null when
  /// the sidebar is not part of the current layout.
  ComponentFactory({
    required this.currentView,
    required this.workerResult,
    required this.onViewSelected,
    required this.minPaneSize,
    required this.defaultRatio,
    required this.resolveTopologyData,
    required this.resolveTabLabel,
    required this.buildChildWidget,
    this.treeViewModel,
    this.preferredSplitAxis,
  });

  /// Builds a widget subtree from a layout [node] with the given constraints.
  ///
  /// Recursively processes child nodes for container types (`SidebarLayout`,
  /// `SplitWorkspace`). Unknown node types render [SizedBox.shrink] instead
  /// of throwing, allowing graceful handling of future or optional layout
  /// entries.
  Widget build(
    Map<String, dynamic> node,
    double parentWidth,
    double parentHeight,
    BuildContext context,
  ) {
    final type = node['type'] as String?;
    switch (type) {
      case 'SidebarLayout':
        final childrenList = node['children'] as List<dynamic>? ?? [];
        final sidebarChild = childrenList.firstWhere(
          (c) => c['type'] == 'HierarchyTreeSelector',
          orElse: () => null,
        );
        final splitWorkspaceChild = childrenList.firstWhere(
          (c) => c['type'] == 'SplitWorkspace',
          orElse: () => null,
        );
            return SplitWorkspace(
              leading: sidebarChild != null
                  ? build(sidebarChild as Map<String, dynamic>, parentWidth, parentHeight, context)
                  : const SizedBox.shrink(),
              trailing: splitWorkspaceChild != null
                  ? build(splitWorkspaceChild as Map<String, dynamic>, parentWidth, parentHeight, context)
                  : const SizedBox.shrink(),
              direction: Axis.horizontal,
              minFirstPaneSize: minPaneSize,
              initialRatio: 0.25,
              splitterKey: const Key('vertical_splitter'),
              paintLeadingOnTop: true,
            );
      case 'HierarchyTreeSelector':
        final tree = SidebarTree(
          workerResult: workerResult,
          onViewSelected: onViewSelected,
        );
        if (treeViewModel != null) {
          return ChangeNotifierProvider<TreeViewModel>.value(
            value: treeViewModel!,
            child: tree,
          );
        }
        return tree;
      case 'SplitWorkspace':
        final childrenList = node['children'] as List<dynamic>? ?? [];
        final topoChild = childrenList.firstWhere(
          (c) => c['type'] == 'TopographicalView',
          orElse: () => null,
        );
        final tabbedChild = childrenList.firstWhere(
          (c) => c['type'] == 'TabbedContainer',
          orElse: () => null,
        );
        return SplitWorkspace(
          leading: topoChild != null
              ? build(topoChild as Map<String, dynamic>, parentWidth, parentHeight, context)
              : const SizedBox.shrink(),
          trailing: tabbedChild != null
              ? build(tabbedChild as Map<String, dynamic>, parentWidth, parentHeight, context)
              : const SizedBox.shrink(),
          direction: preferredSplitAxis ?? _parseAxis(node),
          minFirstPaneSize: minPaneSize,
          initialRatio: defaultRatio(),
          splitterKey: const Key('horizontal_splitter'),
        );
      case 'TopographicalView':
        final treeData = treeViewModel?.treeData ?? [];
        final panelOpacity = context.watch<ThemeController>().panelOpacity;
        return TopographicalView(
          currentView: currentView,
          onViewSelected: onViewSelected,
          child: Container(
            color: Theme.of(context).cardColor.withOpacity(panelOpacity),
            child: buildChildWidget(context),
          ),
          topologyData: resolveTopologyData(),
          treeData: treeData,
          splitMinFirstPaneSize: minPaneSize,
          splitInitialRatio: defaultRatio(),
          splitDirection: preferredSplitAxis ?? _parseAxis(node),
        );
      case 'TabbedContainer':
        return _TabbedContainerHost(currentView: currentView);
      case 'TableView':
        final id = node['id'] as String? ?? '';
        return _TableViewContainer(
          tabId: id,
          currentView: currentView,
        );
      case 'PropertiesPanel':
        final panelOpacity = context.watch<ThemeController>().panelOpacity;
        return Container(
          color: Theme.of(context).cardColor.withOpacity(panelOpacity),
          child: buildChildWidget(context),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  /// Reads the `axis` prop from a layout [node] and returns the corresponding
  /// [Axis] value. Defaults to [Axis.vertical] when the prop is absent.
  Axis _parseAxis(Map<String, dynamic> node) {
    final axis = node['props']?['axis'] as String?;
    if (axis == 'horizontal') return Axis.horizontal;
    return Axis.vertical;
  }
}

/// Host widget that creates a [TablesViewModel] from the [DataSource] and
/// provides it to [TabbedContainer].
///
/// Initialises the view model lazily in [didChangeDependencies] so that
/// [Provider] is available. Reloads tabs when [currentView] changes.
/// Disposes the view model on unmount to prevent memory leaks.
class _TabbedContainerHost extends StatefulWidget {
  final String currentView;

  const _TabbedContainerHost({required this.currentView});

  @override
  State<_TabbedContainerHost> createState() => _TabbedContainerHostState();
}

class _TabbedContainerHostState extends State<_TabbedContainerHost> {
  TablesViewModel? _viewModel;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final ds = context.read<DataSource>();
      _viewModel = TablesViewModel(ds, widget.currentView)
        ..loadForNode(widget.currentView);
    }
  }

  @override
  void didUpdateWidget(_TabbedContainerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentView != oldWidget.currentView) {
      _viewModel?.loadForNode(widget.currentView);
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) return const SizedBox.shrink();
    return ChangeNotifierProvider<TablesViewModel>.value(
      value: _viewModel!,
      child: const TabbedContainer(),
    );
  }
}

/// Host widget that creates a [TablesViewModel] for a single table tab and
/// provides it to [TableViewWidget].
///
/// Same lifecycle pattern as [_TabbedContainerHost] — lazy initialisation,
/// reload on view change, dispose on unmount.
class _TableViewContainer extends StatefulWidget {
  final String tabId;
  final String currentView;

  const _TableViewContainer({
    required this.tabId,
    required this.currentView,
  });

  @override
  State<_TableViewContainer> createState() => _TableViewContainerState();
}

class _TableViewContainerState extends State<_TableViewContainer> {
  TablesViewModel? _viewModel;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final ds = context.read<DataSource>();
      _viewModel = TablesViewModel(ds, widget.currentView)
        ..loadForNode(widget.currentView);
    }
  }

  @override
  void didUpdateWidget(_TableViewContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabId != oldWidget.tabId ||
        widget.currentView != oldWidget.currentView) {
      _viewModel?.loadForNode(widget.currentView);
    }
  }

  @override
  void dispose() {
    _viewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) return const SizedBox.shrink();
    return ChangeNotifierProvider<TablesViewModel>.value(
      value: _viewModel!,
      child: const TableViewWidget(),
    );
  }
}
