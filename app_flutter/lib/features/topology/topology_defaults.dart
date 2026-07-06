import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:app_flutter/features/topology/topology_map.dart';

// TODO(#79): Replace mock topology data with dynamic DB-backed data.
// Currently used as fallback when widget.data is null.
// The data is loaded from assets/topology_data.json via loadTopologyData().

/// Empty topology data fallback used when real data is unavailable.
const emptyTopologyData = TopologyData(
  coordinateMapping: {},
  nodes: [],
  links: [],
);

/// Loads topology data from the external JSON asset.
Future<TopologyData> loadTopologyData() async {
  final jsonStr = await rootBundle.loadString('assets/topology_data.json');
  final data = jsonDecode(jsonStr) as Map<String, dynamic>;
  return TopologyData.fromJson(data);
}
