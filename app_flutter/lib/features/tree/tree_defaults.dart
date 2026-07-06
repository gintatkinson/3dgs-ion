import 'package:app_flutter/features/tree/tree_node.dart';

/// Fallback tree data used when DataSource returns no hierarchy.
/// Replace with your domain's actual tree structure.
List<TreeNode> get defaultTreeData => [
  const TreeNode(id: 'Master_1', label: 'Master 1'),
  const TreeNode(id: 'Master_2', label: 'Master 2'),
  const TreeNode(id: 'Master_3', label: 'Master 3'),
];
