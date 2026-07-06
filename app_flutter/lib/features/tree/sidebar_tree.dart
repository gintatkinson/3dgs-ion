import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/widgets/settings_panel.dart';
import 'package:app_flutter/core/string_resources.dart';
import 'package:app_flutter/features/tree/tree_node_widget.dart';
import 'package:app_flutter/features/tree/view_models/tree_view_model.dart';

/// The sidebar panel displaying a hierarchical tree of discoverable views.
///
/// Uses [TreeViewModel] (provided via [Provider]) for data and focus management.
/// Supports keyboard navigation (arrow keys) via a [Focus] wrapper. The tree
/// is scrollable vertically. A footer shows the current worker state and a
/// settings button that opens [SettingsPanel] in a modal bottom sheet.
///
/// [contentPadding] controls the padding around the scrollable tree content area.
///
/// Edge cases: when [workerResult] is null, displays "Idle"; when the tree
/// data is empty the panel renders an empty column. The settings icon is
/// always visible regardless of worker state.
class SidebarTree extends StatelessWidget {
  final int? workerResult;
  final ValueChanged<String> onViewSelected;
  /// The padding around the scrollable tree content area.
  ///
  /// Applied to the [SingleChildScrollView] that wraps the tree nodes.
  /// Defaults to `EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0)`.
  final EdgeInsetsGeometry contentPadding;

  const SidebarTree({
    super.key,
    this.workerResult,
    required this.onViewSelected,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
  });

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TreeViewModel>();
    final treeData = viewModel.treeData;
    final brandPrimary = Theme.of(context).colorScheme.primary;
    final panelOpacity = context.watch<ThemeController>().panelOpacity;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(panelOpacity),
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.developer_board,
                  color: brandPrimary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    StringResources.get('sidebar.header'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
          // Focusable Tree Navigation
          Expanded(
            child: Focus(
              focusNode: viewModel.focusNode,
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is KeyDownEvent) {
                  final key = event.logicalKey;
                  if (key == LogicalKeyboardKey.arrowDown) {
                    viewModel.handleArrowDown();
                    return KeyEventResult.handled;
                  } else if (key == LogicalKeyboardKey.arrowUp) {
                    viewModel.handleArrowUp();
                    return KeyEventResult.handled;
                  } else if (key == LogicalKeyboardKey.arrowLeft) {
                    viewModel.handleArrowLeft();
                    return KeyEventResult.handled;
                  } else if (key == LogicalKeyboardKey.arrowRight) {
                    viewModel.handleArrowRight();
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
                child: SingleChildScrollView(
                padding: contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: treeData.map((node) => TreeNodeWidget(
                    node: node,
                  )).toList(),
                ),
              ),
            ),
          ),
          // Sidebar Footer
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Worker: ${workerResult ?? "Idle"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: const Key('sidebar_settings_button'),
                  icon: const Icon(Icons.settings, size: 18),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const SettingsPanel(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
