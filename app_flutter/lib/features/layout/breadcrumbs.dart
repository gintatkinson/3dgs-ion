import 'package:flutter/material.dart';
import 'package:app_flutter/core/string_resources.dart';
import 'package:app_flutter/features/tree/tree_node.dart';

/// A single segment in the breadcrumbs navigation bar.
///
/// Exists to represent a node in the tree path. Use this in the
/// [NavigationBreadcrumbs.items] list to build the navigation trail.
///
/// Edge cases: [onClick] is optional — a `null` callback renders the item as
/// plain text (typically the last item); a non-null callback renders it as an
/// [ActionChip].
class BreadcrumbItem {
  /// Unique identifier for this breadcrumb segment, matched against tree node
  /// ids.
  final String id;

  /// Display label shown in the breadcrumb bar.
  final String label;

  /// Callback invoked when the breadcrumb is tapped. `null` disables
  /// interactivity (rendered as plain text).
  final VoidCallback? onClick;

  const BreadcrumbItem({
    required this.id,
    required this.label,
    this.onClick,
  });
}

/// Renders a responsive path trace of the current location/view.
///
/// Automatically collapses middle segments into a clickable ellipsis when the
/// path length exceeds [maxItems].
///
/// Exists to let users quickly navigate up the tree hierarchy without
/// returning to the root. Use this in any detail/browse view where the current
/// position in the tree should be visible.
///
/// Edge cases:
///   - An empty [items] list renders [SizedBox.shrink] (nothing visible).
///   - If [items] has exactly [maxItems] items, no truncation occurs.
///   - If [items] has fewer than [maxItems] items, all items are shown.
///   - [maxItems] of 0 or 1 disables the collapse feature (no middle segment
///     to collapse). The ellipsis state is stored locally via [_isExpanded].
///
/// State changes: when the user taps the ellipsis, [_isExpanded] toggles to
/// `true` and all items are revealed. This state is NOT reset automatically
/// when [items] changes — callers should provide a new [key] to force a fresh
/// widget if needed.
class NavigationBreadcrumbs extends StatefulWidget {
  /// Ordered list of breadcrumb segments from root to current view. When
  /// empty, nothing is rendered.
  final List<BreadcrumbItem> items;

  /// Maximum visible items before collapsing. Must be at least 2 for
  /// meaningful collapse behaviour. Defaults to 4.
  final int maxItems;

  const NavigationBreadcrumbs({
    super.key,
    required this.items,
    this.maxItems = 4,
  });

  @override
  State<NavigationBreadcrumbs> createState() => _NavigationBreadcrumbsState();
}

class _NavigationBreadcrumbsState extends State<NavigationBreadcrumbs> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool shouldCollapse = widget.items.length > widget.maxItems && !_isExpanded;

    List<BreadcrumbItem> renderedItems;
    if (shouldCollapse) {
      final BreadcrumbItem first = widget.items.first;
      final List<BreadcrumbItem> lastItems = widget.items.sublist(
        widget.items.length - (widget.maxItems - 1),
      );
      renderedItems = <BreadcrumbItem>[
        first,
        BreadcrumbItem(
          id: 'ellipsis',
          label: '...',
          onClick: () {
            setState(() {
              _isExpanded = true;
            });
          },
        ),
        ...lastItems,
      ];
    } else {
      renderedItems = widget.items;
    }



    final List<Widget> children = <Widget>[];
    for (int i = 0; i < renderedItems.length; i++) {
      final BreadcrumbItem item = renderedItems[i];
      final bool isLast = i == renderedItems.length - 1;
      final bool isEllipsis = item.id == 'ellipsis';

      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              '/',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }

      if (isEllipsis) {
        children.add(
          ActionChip(
            onPressed: item.onClick,
            label: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      } else if (isLast) {
        children.add(
          Text(
            item.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      } else {
        children.add(
          ActionChip(
            onPressed: item.onClick,
            label: Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// Returns the ID of the first leaf node reachable from [n] by depth-first
/// traversal.
///
/// Exists to map a parent node to the first selectable leaf when the user
/// clicks a breadcrumb that represents a branch (non-leaf) node.
///
/// Edge cases: if [n] has no children (or `null` children), returns [n.id]
/// directly. If [n] has children, traversal recurses into the first child;
/// assumes the tree is non-empty at that level.
String getFirstLeafId(TreeNode n) {
  if (n.children == null || n.children!.isEmpty) return n.id;
  return getFirstLeafId(n.children!.first);
}

/// Builds a list of [BreadcrumbItem] from the current [view] and the tree
/// hierarchy.
///
/// The first item is always the root (the app title from config). Subsequent
/// items represent each node on the path from the root to the node matching
/// [view].
///
/// Exists to decouple breadcrumb construction from the calling widget. Use
/// this function whenever a breadcrumb trail needs to be built from tree data.
///
/// Edge cases:
///   - If [treeData] is empty, the root click handler still attempts to
///     call `getFirstLeafId(treeData.first)` which will throw — callers must
///     ensure the tree is non-empty before invoking this function.
///   - If [view] is not found in [treeData], a fallback breadcrumb with
///     [view] as both id and label is appended.
///   - The last item in the path is rendered without an `onClick` (plain text
///     indicating the current location).
List<BreadcrumbItem> getBreadcrumbsItems(
  String view,
  List<TreeNode> treeData, {
  ValueChanged<String>? onSelectView,
}) {
  final List<BreadcrumbItem> base = [
    BreadcrumbItem(
      id: 'home',
      label: StringResources.get('breadcrumbs.home'),
      onClick: () {
        if (treeData.isNotEmpty) {
          onSelectView?.call(getFirstLeafId(treeData.first));
        }
      },
    ),
  ];

  List<TreeNode>? findPath(List<TreeNode> nodes, String targetId, List<TreeNode> currentPath) {
    for (final node in nodes) {
      if (node.id == targetId) {
        return [...currentPath, node];
      }
      if (node.children != null) {
        final found = findPath(node.children!, targetId, [...currentPath, node]);
        if (found != null) return found;
      }
    }
    return null;
  }

  final path = findPath(treeData, view, []);
  if (path == null || path.isEmpty) {
    return [...base, BreadcrumbItem(id: view, label: view)];
  }

  final List<BreadcrumbItem> items = [...base];
  for (int i = 0; i < path.length; i++) {
    final node = path[i];
    if (i == path.length - 1) {
      items.add(BreadcrumbItem(id: node.id, label: node.label));
    } else {
      items.add(
        BreadcrumbItem(
          id: node.id,
          label: node.label,
          onClick: () => onSelectView?.call(getFirstLeafId(node)),
        ),
      );
    }
  }
  return items;
}
