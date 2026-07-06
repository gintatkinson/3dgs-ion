import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';
import 'package:app_flutter/features/tables/table_view_widget.dart';

/// Renders a tabbed view whose labels, columns, and data are driven by a
/// [TablesViewModel].
///
/// Exists to display child/related types of the currently selected tree node in
/// separate tabs, removing the need for hardcoded tab definitions. Use this
/// widget anywhere the UI needs data-source-driven tab navigation.
///
/// Edge cases:
///   - If [TablesViewModel.tabs] is empty and [loading] is `true`, a centered
///     [CircularProgressIndicator] is shown.
///   - If [TablesViewModel.tabs] is empty and [loading] is `false`, nothing is
///     rendered ([SizedBox.shrink]).
///   - When tabs change (e.g. navigating to a different node), the
///     [TabController] is disposed and re-created to match the new tab count.
///   - The initial tab index is determined by [TablesViewModel.selectedTabId];
///     if no match is found, index 0 is used.
///
/// State changes: this widget creates a [TabController] with
/// [SingleTickerProviderStateMixin] and disposes it on teardown. Tab selection
/// is forwarded to [TablesViewModel.selectTab] which triggers async data
/// loading.
class TabbedContainer extends StatefulWidget {
  const TabbedContainer({super.key});

  @override
  State<TabbedContainer> createState() => _TabbedContainerState();
}

class _TabbedContainerState extends State<TabbedContainer>
    with TickerProviderStateMixin {
  TabController? _tabController;
  TablesViewModel? _viewModel;
  int? _lastIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newViewModel = Provider.of<TablesViewModel>(context);
    if (newViewModel != _viewModel) {
      _viewModel?.removeListener(_onViewModelChanged);
      _viewModel = newViewModel;
      _viewModel?.addListener(_onViewModelChanged);
      _updateController();
    }
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {
        _updateController();
      });
    }
  }

  void _updateController() {
    final tabs = _viewModel?.tabs ?? [];
    if (tabs.isEmpty) {
      _tabController?.removeListener(_onTabTick);
      _tabController?.dispose();
      _tabController = null;
      return;
    }
    if (_tabController == null || _tabController!.length != tabs.length) {
      final oldController = _tabController;
      if (oldController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldController.dispose();
        });
      }
      _tabController = TabController(length: tabs.length, vsync: this);
      final initialIndex =
          tabs.indexWhere((t) => t.id == _viewModel?.selectedTabId);
      if (initialIndex > 0) _tabController!.index = initialIndex;
      _tabController!.addListener(_onTabTick);
      _lastIndex = _tabController!.index;
    }
  }

  void _onTabTick() {
    if (_tabController != null) {
      if (_tabController!.index != _lastIndex) {
        _lastIndex = _tabController!.index;
        setState(() {});
      }
      if (!_tabController!.indexIsChanging) {
        final tabs = _viewModel?.tabs ?? [];
        if (_tabController!.index < tabs.length) {
          final tab = tabs[_tabController!.index];
          _viewModel?.selectTab(tab.id);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewModel == null) return const SizedBox.shrink();
    final tabs = _viewModel!.tabs;

    if (tabs.isEmpty) {
      if (_viewModel!.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const SizedBox.shrink();
    }

    if (_tabController == null) {
      return const SizedBox.shrink();
    }

    final panelOpacity = context.watch<ThemeController>().panelOpacity;
    return Container(
      color: Theme.of(context).cardColor.withOpacity(panelOpacity),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController!,
              tabs: tabs.map((t) => Tab(text: t.label)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: List.generate(tabs.length, (idx) {
                return LazyTab(
                  isSelected: _tabController!.index == idx,
                  child: const TableViewWidget(),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onViewModelChanged);
    _tabController?.removeListener(_onTabTick);
    _tabController?.dispose();
    super.dispose();
  }
}

class LazyTab extends StatefulWidget {
  const LazyTab({super.key, required this.child, required this.isSelected});
  final Widget child;
  final bool isSelected;
  @override
  State<LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<LazyTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Offstage(offstage: !widget.isSelected, child: widget.child);
  }
}
