import 'package:app_flutter/features/tree/tree_node.dart';
import 'instance_record.dart';
import 'type_descriptor.dart';
import 'package:app_flutter/features/topology/topology_map.dart' show TopologyData;

/// Abstract interface for a swappable data backend.
///
/// Implementations: [SqliteDataSource], [FirebaseDataSource], [GrpcDataSource].
/// The app selects one at startup and discovers all type schemas from it.
/// Define a new implementation to integrate a new persistence or API layer
/// without modifying any UI code — the widget layer consumes this interface only.
abstract class DataSource {
  /// Human-readable name, e.g. "sqlite", "firebase", "grpc".
  ///
  /// Used for logging, debugging, and UI badges that identify the active backend.
  /// Returns the same value for the lifetime of the instance.
  String get name;

  /// Discover all object types known to this data source.
  ///
  /// Returns one [TypeDescriptor] per type. The client uses these to
  /// render the sidebar tree, property forms, and tab tables. Adding
  /// a new type to the data source automatically makes it appear in
  /// the UI — no code change required.
  ///
  /// Returns an empty list when no types exist — callers must handle
  /// the empty state (e.g. show a "No data sources connected" view).
  Future<List<TypeDescriptor>> discoverTypes();

  /// Get the [TypeDescriptor] for a specific type by its [typeName].
  ///
  /// Returns null if the type is not known to this data source.
  /// Throws no exception for unknown types; callers should null-check
  /// and show a fallback UI or skip the type gracefully.
  Future<TypeDescriptor?> typeFor(String typeName);

  /// Discover the tree hierarchy: parent-child relationships.
  ///
  /// Returns a list of (parentTypeName, childTypeName) pairs.
  /// Returns an empty list for flat (non-hierarchical) schemas.
  /// A missing or malformed hierarchy signal is treated as "no relations"
  /// and must not throw.
  Future<List<(String, String)>> discoverHierarchy();

  /// Fetches the property map for the node identified by [nodeId].
  ///
  /// Returns an empty map when [nodeId] does not exist or when the node
  /// has no stored properties — it does not throw. The caller should
  /// treat an empty map the same as "no properties".
  Future<Map<String, dynamic>> fetchProperties(String nodeId);

  /// Persists [data] as the properties for [nodeId].
  ///
  /// Replaces the entire property set for [nodeId] (not a merge). Callers
  /// must pass the full property map. After a successful save, consumers
  /// subscribed via [watchProperties] receive the update automatically.
  Future<void> saveProperties(String nodeId, Map<String, dynamic> data);

  /// Returns a broadcast stream that yields the current properties and
  /// then emits updates whenever properties change for [nodeId].
  ///
  /// The stream never closes unless the data source itself shuts down.
  /// The initial emission is the result of [fetchProperties] so callers
  /// do not need a separate fetch call. If [nodeId] does not exist, the
  /// stream emits an empty map and continues watching for future saves.
  Stream<Map<String, dynamic>> watchProperties(String nodeId);

  /// Fetches related instances of [targetType] under [parentNodeId].
  ///
  /// Returns an empty list when no instances exist. Never throws.
  Future<List<InstanceRecord>> fetchRelatedInstances({
    required String parentNodeId,
    required TypeDescriptor targetType,
  });

  /// Fetches root nodes from SQLite properties table.
  Future<List<TreeNode>> fetchRootNodes();

  /// Fetches child nodes for a parent from SQLite properties table.
  Future<List<TreeNode>> fetchChildrenForNode(String parentId);

  /// Fetches all active nodes and links for topology mapping.
  Future<TopologyData> fetchTopologyData();
}

