/// A node in the sidebar hierarchy tree representing a selectable view type.
///
/// Each node carries an [id] (unique view identifier), a human-readable
/// [label], and optional [children] for nested sub-types. Leaf nodes have
/// `null` children. The tree structure mirrors the type hierarchy discovered
/// from the data source. Equality is identity-based; no value equality override
/// is provided since nodes are rebuilt on each tree refresh.
class TreeNode {
  final String id;
  final String label;
  List<TreeNode>? children;

  TreeNode({
    required this.id,
    required this.label,
    this.children,
  });
}
