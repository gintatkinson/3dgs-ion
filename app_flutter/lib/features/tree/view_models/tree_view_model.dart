import 'package:flutter/material.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/tree/tree_defaults.dart';

/// View model driving the sidebar tree: data loading, navigation, focus,
/// and keyboard-driven expansion/selection.
///
/// Owns the tree data ([_treeData]), the currently-selected view
/// ([_currentView]), per-node expand/collapse state ([_expanded]), and a
/// [FocusNode] for keyboard event handling. Calls [notifyListeners] after
/// every mutation to trigger UI rebuilds via [Provider].
///
/// State changes: [loadTree] resets the entire tree; [selectView] /
/// [updateCurrentView] change the current view and expand ancestors;
/// [toggleExpand] flips a single node's collapsed state; arrow handlers
/// traverse the visible (depth-first) node list. On dispose, the focus node
/// is released.
///
/// Edge cases: empty tree data, missing node IDs in arrow navigation (index
/// -1 is handled), root nodes with no parents to expand, and views whose
/// parent chain is already visible (no-op expand).
class TreeViewModel extends ChangeNotifier {
  TreeViewModel(this._dataSource, {
    String initialView = '',
    this.onViewSelected,
  }) : _currentView = initialView;

  final DataSource _dataSource;
  final ValueChanged<String>? onViewSelected;
  List<TreeNode> _treeData = [];
  String _currentView;
  final Map<String, bool> _expanded = {};
  final Map<String, bool> _loadingNodes = {};
  final FocusNode _treeFocusNode = FocusNode();
  final Map<String, GlobalKey> _nodeKeys = {};
  bool _disposed = false;

  List<TreeNode> get treeData => _treeData;
  String get currentView => _currentView;
  Map<String, bool> get expanded => _expanded;
  Map<String, bool> get loadingNodes => _loadingNodes;
  FocusNode get focusNode => _treeFocusNode;
  GlobalKey? nodeKey(String id) => _nodeKeys[id];

  /// Loads the type hierarchy from the data source and initialises tree data,
  /// current view, expanded nodes, and node keys.
  ///
  /// Called once during startup. Sets [_currentView] to the first root node if
  /// no initial view was provided. Ensures the path to the current view is
  /// expanded. Fires [notifyListeners] when complete.
  ///
  /// Safe to call multiple times; resets all state before rebuilding.
  Future<void> loadTree() async {
    final roots = await _dataSource.fetchRootNodes();
    if (_disposed) return;
    _treeData = roots.isNotEmpty ? roots : List<TreeNode>.from(defaultTreeData);
    _sortNodesRecursively(_treeData);

    _expanded.clear();
    _loadingNodes.clear();
    _nodeKeys.clear();

    if (_currentView.isEmpty && _treeData.isNotEmpty) {
      _currentView = _treeData.first.id;
    }

    _expandParents(_currentView);

    final currentNode = _findNodeById(_treeData, _currentView);
    if (currentNode != null && currentNode.children != null) {
      await expandNode(currentNode);
    }

    _buildNodeKeys(_treeData);
    notifyListeners();
  }

  /// Selects [viewId] as the current view, expands its ancestors, scrolls it
  /// into view, and notifies listeners.
  ///
  /// Called when the user taps a tree node or navigates via arrow keys. No-op
  /// if [viewId] is already the current view. Triggers [onViewSelected]
  /// callback after state is updated.
  void selectView(String viewId) {
    if (_currentView == viewId) return;
    _currentView = viewId;
    _expandParents(viewId);
    final node = _findNodeById(_treeData, viewId);
    if (node != null && node.children != null && _expanded[viewId] != true) {
      expandNode(node);
    }
    _scrollToNode(viewId);
    notifyListeners();
    onViewSelected?.call(viewId);
  }

  /// Updates the current view (without firing [selectView]'s external callback).
  ///
  /// Used by [Layout._updateCurrentViewFromLayout] when the active view is
  /// driven externally (e.g. via widget properties). Expands ancestors and
  /// scrolls to the node, then fires [notifyListeners]. No-op if [viewId]
  /// matches the current view.
  void updateCurrentView(String viewId) {
    if (_currentView == viewId) return;
    _currentView = viewId;
    _expandParents(viewId);
    final node = _findNodeById(_treeData, viewId);
    if (node != null && node.children != null && _expanded[viewId] != true) {
      expandNode(node);
    }
    _scrollToNode(viewId);
    notifyListeners();
  }

  /// Toggles expansion state of the node with [id] and lazily loads children.
  void toggleExpand(String id) {
    final node = _findNodeById(_treeData, id);
    if (node != null) {
      expandNode(node);
    } else {
      _expanded[id] = !(_expanded[id] ?? false);
      notifyListeners();
    }
  }

  /// Recursively expands a node, loading its children if necessary.
  Future<void> expandNode(TreeNode node) async {
    if (_expanded[node.id] == true) {
      _expanded[node.id] = false;
      notifyListeners();
      return;
    }

    if (node.children != null && node.children!.isEmpty) {
      _loadingNodes[node.id] = true;
      notifyListeners();

      try {
        final children = await _dataSource.fetchChildrenForNode(node.id);
        _sortNodesRecursively(children);
        node.children = children;
        _buildNodeKeys(children);
      } catch (e) {
        debugPrint('Error loading children: $e');
      } finally {
        _loadingNodes[node.id] = false;
      }
    }

    _expanded[node.id] = true;
    notifyListeners();
  }

  TreeNode? _findNodeById(List<TreeNode> nodes, String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
      if (node.children != null) {
        final found = _findNodeById(node.children!, id);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Moves selection to the next visible node (depth-first order).
  ///
  /// Called on ArrowDown key event. No-op if the current node is the last
  /// visible node.
  void handleArrowDown() {
    final visible = _getVisibleNodes();
    final currentIndex = visible.indexWhere((n) => n.id == _currentView);
    final nextIndex = currentIndex + 1;
    if (nextIndex < visible.length) {
      selectView(visible[nextIndex].id);
    }
  }

  /// Moves selection to the previous visible node (depth-first order).
  ///
  /// Called on ArrowUp key event. No-op if the current node is the first
  /// visible node.
  void handleArrowUp() {
    final visible = _getVisibleNodes();
    final currentIndex = visible.indexWhere((n) => n.id == _currentView);
    final prevIndex = currentIndex - 1;
    if (prevIndex >= 0) {
      selectView(visible[prevIndex].id);
    }
  }

  /// Expands the current node or, if already expanded, selects its first child.
  ///
  /// Called on ArrowRight key event. If the current node has no children this
  /// is a no-op. Expands the node if collapsed; moves selection to the first
  /// child if already expanded.
  void handleArrowRight() {
    final visible = _getVisibleNodes();
    final currentIndex = visible.indexWhere((n) => n.id == _currentView);
    if (currentIndex == -1) return;
    final currentNode = visible[currentIndex];
    if (currentNode.children != null) {
      if (_expanded[currentNode.id] != true) {
        expandNode(currentNode);
      } else if (currentNode.children!.isNotEmpty) {
        final firstChild = currentNode.children![0];
        selectView(firstChild.id);
      }
    }
  }

  /// Collapses the current node or, if already collapsed or a leaf, selects
  /// its parent.
  ///
  /// Called on ArrowLeft key event. If the current node has children and is
  /// expanded, collapses it. Otherwise navigates upward to the nearest parent
  /// in the tree. No-op if the current node is a root-level node (no parent).
  void handleArrowLeft() {
    final visible = _getVisibleNodes();
    final currentIndex = visible.indexWhere((n) => n.id == _currentView);
    if (currentIndex == -1) return;
    final currentNode = visible[currentIndex];
    if (currentNode.children != null &&
        _expanded[currentNode.id] == true) {
      _expanded[currentNode.id] = false;
      notifyListeners();
    } else {
      TreeNode? findParent(List<TreeNode> nodes, String targetId, TreeNode? parent) {
        for (final node in nodes) {
          if (node.id == targetId) return parent;
          if (node.children != null) {
            final found = findParent(node.children!, targetId, node);
            if (found != null) return found;
          }
        }
        return null;
      }

      final parent = findParent(_treeData, currentNode.id, null);
      if (parent != null) {
        selectView(parent.id);
      }
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _treeFocusNode.dispose();
    super.dispose();
  }

  /// Recursively creates [GlobalKey] entries for every node in [nodes].
  ///
  /// Used by [_scrollToNode] to obtain [BuildContext] for scroll-into-view.
  /// Keys are rebuilt on every [loadTree] call, so references are not
  /// preserved across full data reloads.
  void _buildNodeKeys(List<TreeNode> nodes) {
    for (final node in nodes) {
      _nodeKeys[node.id] = GlobalKey();
      if (node.children != null) {
        _buildNodeKeys(node.children!);
      }
    }
  }

  /// Expands all ancestor nodes of [targetView] in the tree.
  ///
  /// Called when a view is selected (via tap or keyboard) to ensure the
  /// path to the selected node is visible. If [targetView] is a root node
  /// or already visible, this is a no-op. Fires [notifyListeners] only if a
  /// change was actually made.
  void _expandParents(String targetView) {
    bool changed = false;
    bool findAndExpandParents(List<TreeNode> nodes, String targetId, List<String> path) {
      for (final node in nodes) {
        if (node.id == targetId) {
          for (final id in path) {
            if (_expanded[id] != true) {
              _expanded[id] = true;
              changed = true;
            }
          }
          return true;
        }
        if (node.children != null) {
          if (findAndExpandParents(node.children!, targetId, [...path, node.id])) {
            return true;
          }
        }
      }
      return false;
    }

    findAndExpandParents(_treeData, targetView, []);
    if (changed) {
      notifyListeners();
    }
  }

  /// Returns the flat, depth-first ordered list of nodes that are currently
  /// visible (expanded parents' children are included; collapsed parents'
  /// descendants are excluded).
  ///
  /// Used by arrow-key navigation handlers to determine the next/previous
  /// selectable node. Returns an empty list when the tree is empty.
  List<TreeNode> _getVisibleNodes() {
    final List<TreeNode> result = [];
    void traverse(TreeNode node) {
      result.add(node);
      if (node.children != null && _expanded[node.id] == true) {
        node.children!.forEach(traverse);
      }
    }
    _treeData.forEach(traverse);
    return result;
  }

  /// Scrolls the node with [viewId] into the visible viewport using its
  /// [GlobalKey].
  ///
  /// Schedules a post-frame callback to ensure layout is complete before
  /// scrolling. Animated with a 200 ms ease-in-out curve. If the node's
  /// key has no current context (e.g. node is not in the tree or not visible),
  /// the scroll is silently skipped.
  void _scrollToNode(String viewId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _nodeKeys[viewId]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _sortNodesRecursively(List<TreeNode> nodes) {
    nodes.sort((a, b) => _naturalCompare(a.id, b.id));
    for (final node in nodes) {
      if (node.children != null && node.children!.isNotEmpty) {
        _sortNodesRecursively(node.children!);
      }
    }
  }

  int _naturalCompare(String a, String b) {
    final bool isChildOrGcA = a.contains('_Child_') || a.contains('_Grandchild_');
    final bool isChildOrGcB = b.contains('_Child_') || b.contains('_Grandchild_');
    
    if (isChildOrGcA != isChildOrGcB) {
      return isChildOrGcA ? 1 : -1;
    }

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
