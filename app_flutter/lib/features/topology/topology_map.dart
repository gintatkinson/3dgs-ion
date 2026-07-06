import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:app_flutter/features/topology/topology_defaults.dart' show emptyTopologyData;

dynamic _resolvePath(Map<String, dynamic> map, String path) {
  final List<String> parts = path.split('/');
  dynamic current = map;
  for (final String part in parts) {
    if (current is Map<String, dynamic>) {
      current = current[part];
    } else {
      return null;
    }
  }
  return current;
}

/// 3-D position + time-index + trajectory vector for a topology node.
///
/// Parsed from JSON via [TopologyNodePosition.fromJson]. Coordinates are
/// resolved lazily through [resolveCoordinate] which checks an optional
/// [coordinateMapping] before falling back to the baked-in dim fields.
/// Raw properties are preserved for arbitrary downstream lookups.
///
/// Edge cases: missing dimensions default to 0.0; empty vector yields zero
/// velocity in [TopologyNode.computePosition].
class TopologyNodePosition {
  /// First spatial coordinate (x-axis). Parsed from JSON key `dim_0`.
  /// Defaults to 0.0 when missing. Used as the primary x-position on canvas.
  final double dim0;

  /// Second spatial coordinate (y-axis). Parsed from JSON key `dim_1`.
  /// Defaults to 0.0 when missing. Used as the primary y-position on canvas.
  final double dim1;

  /// Third spatial coordinate (z-axis). Parsed from JSON key `dim_2`.
  /// Defaults to 0.0 when missing. Not directly rendered; available for
  /// downstream consumers.
  final double dim2;

  /// Timestamp index for this node position. Parsed from JSON key
  /// `time_index`. Used by [TopologyNode.computePosition] to calculate
  /// displacement from the trajectory vector.
  final double timeIndex;

  /// Velocity / trajectory vector for this position. The first two elements
  /// are interpreted as (vx, vy) and scaled by
  /// [TopologyPainter.velocityScale] during rendering. An empty list is
  /// treated as zero velocity.
  final List<double> vector;

  /// Unprocessed JSON payload for this node. Preserved for arbitrary
  /// downstream lookups and coordinate resolution via
  /// [resolveCoordinate] / [resolveVector].
  final Map<String, dynamic> rawProperties;

  const TopologyNodePosition({
    required this.dim0,
    required this.dim1,
    required this.dim2,
    required this.timeIndex,
    required this.vector,
    this.rawProperties = const <String, dynamic>{},
  });

  factory TopologyNodePosition.fromJson(Map<String, dynamic> json) {
    return TopologyNodePosition(
      dim0: (json['dim_0'] as num?)?.toDouble() ?? 0.0,
      dim1: (json['dim_1'] as num?)?.toDouble() ?? 0.0,
      dim2: (json['dim_2'] as num?)?.toDouble() ?? 0.0,
      timeIndex: (json['time_index'] as num?)?.toDouble() ?? 0.0,
      vector: json['vector'] is List<dynamic>
          ? (json['vector'] as List<dynamic>)
              .map((dynamic e) => (e as num).toDouble())
              .toList()
          : <double>[],
      rawProperties: json,
    );
  }

  String? _resolvePathWithMapping(String key, Map<String, String>? coordinateMapping) {
    final String? path = coordinateMapping?[key];
    if (path == null) return null;
    return path.startsWith('position/') ? path.substring(9) : path;
  }

  double resolveCoordinate(String key, Map<String, String>? coordinateMapping) {
    final String? resolvedPath = _resolvePathWithMapping(key, coordinateMapping);
    if (resolvedPath != null) {
      final dynamic val = _resolvePath(rawProperties, resolvedPath);
      if (val is num) {
        return val.toDouble();
      }
    }
    switch (key) {
      case 'x':
        return dim0;
      case 'y':
        return dim1;
      case 'z':
        return dim2;
      case 't':
        return timeIndex;
      default:
        return 0.0;
    }
  }

  List<double> resolveVector(String key, Map<String, String>? coordinateMapping) {
    final String? resolvedPath = _resolvePathWithMapping(key, coordinateMapping);
    if (resolvedPath != null) {
      final dynamic val = _resolvePath(rawProperties, resolvedPath);
      if (val is List) {
        return val.map((dynamic e) => (e as num).toDouble()).toList();
      }
    }
    if (key == 'trajectory') {
      return vector;
    }
    return const <double>[];
  }
}

/// A node in the topology visualisation with position, status, and arbitrary
/// raw properties.
///
/// Created from JSON via [TopologyNode.fromJson]. The [computePosition] method
/// projects the node's position at a given [timeIndex] by applying its
/// trajectory vector. Status is used solely for colour selection in
/// [TopologyPainter] ("Active" gets the active colour; everything else gets
/// the warning colour).
///
/// Edge cases: missing id/label default to empty string; an empty trajectory
/// vector is treated as zero velocity (static position).
class TopologyNode {
  /// Unique identifier for this node. Used as a key for link source/target
  /// references and for focus tracking via [TopologyMap.activeFocusedNode].
  final String id;

  /// Human-readable label rendered below the node circle on canvas.
  final String label;

  /// Encapsulated position data including coordinates, time index, and
  /// trajectory vector. See [TopologyNodePosition] for details.
  final TopologyNodePosition position;

  /// Status string used for colour selection. "Active" receives the
  /// [TopologyPainterColors.activeStatusColor]; all other values receive
  /// the [TopologyPainterColors.warningStatusColor].
  final String status;

  /// Unprocessed JSON payload for this node. Preserved for arbitrary
  /// downstream lookups and coordinate resolution via
  /// [resolveCoordinate] / [resolveVector].
  final Map<String, dynamic> rawProperties;

  const TopologyNode({
    required this.id,
    required this.label,
    required this.position,
    required this.status,
    this.rawProperties = const <String, dynamic>{},
  });

  factory TopologyNode.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> posJson = json['position'] is Map<String, dynamic>
        ? json['position'] as Map<String, dynamic>
        : <String, dynamic>{};
    return TopologyNode(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      position: TopologyNodePosition.fromJson(posJson),
      status: json['status'] as String? ?? '',
      rawProperties: json,
    );
  }

  double resolveCoordinate(String key, Map<String, String>? coordinateMapping) {
    final String? path = coordinateMapping?[key];
    if (path != null && rawProperties.isNotEmpty) {
      final dynamic val = _resolvePath(rawProperties, path);
      if (val is num) {
        return val.toDouble();
      }
    }
    return position.resolveCoordinate(key, coordinateMapping);
  }

  List<double> resolveVector(String key, Map<String, String>? coordinateMapping) {
    final String? path = coordinateMapping?[key];
    if (path != null && rawProperties.isNotEmpty) {
      final dynamic val = _resolvePath(rawProperties, path);
      if (val is List) {
        return val.map((dynamic e) => (e as num).toDouble()).toList();
      }
    }
    return position.resolveVector(key, coordinateMapping);
  }

  Offset computePosition(TopologyData data, double timeIndex) {
    final double nodeT = resolveCoordinate('t', data.coordinateMapping);
    final double dt = timeIndex - nodeT;
    final List<double> vector = resolveVector('trajectory', data.coordinateMapping);
    final double vx = vector.isNotEmpty ? vector[0] : 0.0;
    final double vy = vector.length > 1 ? vector[1] : 0.0;
    final double nodeX = resolveCoordinate('x', data.coordinateMapping);
    final double nodeY = resolveCoordinate('y', data.coordinateMapping);
    return Offset(nodeX + dt * vx, nodeY + dt * vy);
  }
}

/// A directed connection between two topology nodes identified by [source]
/// and [target] IDs with a semantic [type] label.
///
/// Links are purely structural — they are rendered as lines in
/// [TopologyPainter.paint] and carry no runtime state. Invalid source/target
/// references result in a silent no-op during rendering (no line drawn).
class TopologyLink {
  /// ID of the source node for this directed link.
  /// Must match a [TopologyNode.id] in the parent [TopologyData]; otherwise
  /// the link is silently skipped during rendering.
  final String source;

  /// ID of the target node for this directed link.
  /// Must match a [TopologyNode.id] in the parent [TopologyData]; otherwise
  /// the link is silently skipped during rendering.
  final String target;

  /// Semantic label describing the link type (e.g. "depends_on", "connects").
  /// Used solely as a data attribute; not rendered on canvas.
  final String type;

  const TopologyLink({
    required this.source,
    required this.target,
    required this.type,
  });

  factory TopologyLink.fromJson(Map<String, dynamic> json) {
    return TopologyLink(
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }
}

/// The full topology descriptor: coordinate mapping, node list, and link list.
///
/// Deserialised from JSON via [TopologyData.fromJson]. The [coordinateMapping]
/// maps logical axes ("x", "y", "z", "t", "trajectory") to paths in the node's
/// raw properties, allowing flexible schema evolution without code changes.
///
/// Edge cases: empty nodes/links lists are valid and produce a blank canvas;
/// a missing mapping key falls back to the baked-in position fields.
class TopologyData {
  /// Maps logical axis names ("x", "y", "z", "t", "trajectory") to
  /// dot-separated paths in each node's [TopologyNode.rawProperties].
  /// When a key is absent, the corresponding baked-in field
  /// ([TopologyNodePosition.dim0] etc.) is used as fallback.
  final Map<String, String> coordinateMapping;

  /// All nodes in the topology. Each node is projected to canvas space
  /// by [TopologyNode.computePosition] before rendering.
  final List<TopologyNode> nodes;

  /// Directed connections between nodes. Each link references nodes by
  /// their [TopologyNode.id]; invalid references produce a silent no-op.
  final List<TopologyLink> links;

  const TopologyData({
    required this.coordinateMapping,
    required this.nodes,
    required this.links,
  });

  factory TopologyData.fromJson(Map<String, dynamic> json) {
    return TopologyData(
      coordinateMapping: Map<String, String>.from(
        json['coordinate_mapping'] as Map,
      ),
      nodes: (json['nodes'] as List<dynamic>)
          .map((n) => TopologyNode.fromJson(n as Map<String, dynamic>))
          .toList(),
      links: (json['links'] as List<dynamic>)
          .map((l) => TopologyLink.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Interactive topology map with animated playback, node selection, and
/// scrollable canvas.
///
/// Realises UML::TopologyMap and UML::PlaybackController. Renders nodes at
/// their (x, y) positions with trajectory velocity vectors, links with
/// animated data-packet dots, a pulsing halo on the focused node, and labels.
/// A playback panel at the bottom provides play/pause, time slider, and speed
/// control.
///
/// Tap detection uses [tapProximity] (default 20 px). If no node is close
/// enough the tap is silently ignored. When [data] is null, falls back to
/// [emptyTopologyData] (empty nodes/links). On data change, the playhead
/// is clamped to the new [minTime]–[maxTime] range.
///
/// Many visual and behavioural parameters — node radii, grid spacing,
/// animation speed, viewport constraints, and layout sizes — are exposed as
/// constructor parameters with sensible defaults, allowing callers to tune
/// the appearance without subclassing.
class TopologyMap extends StatefulWidget {
  /// Identifier of the node that should be visually focused (halo + larger
  /// radius). Pass `null` to clear focus. Controlled externally by the parent
  /// widget.
  final String? activeFocusedNode;

  /// Callback invoked when the user taps a node within [tapProximity].
  /// Receives the tapped node's [TopologyNode.id]. Not called for taps on
  /// empty canvas space.
  final ValueChanged<String>? onNodeSelect;

  /// The topology data to render. When `null`, a default empty
  /// [emptyTopologyData] is used, producing a blank canvas with grid.
  final TopologyData? data;

  // -- Rendering constants --

  /// Maximum distance (in logical pixels) from a node's centre for a tap to
  /// register as a selection. Larger values make nodes easier to hit on
  /// touch screens; smaller values reduce false positives on dense maps.
  /// Default: 20.0.
  final double tapProximity;

  /// Spacing (in logical pixels) between consecutive background grid lines.
  /// Used both horizontally and vertically. Smaller values produce a denser
  /// grid; larger values reduce visual clutter. Default: 40.0.
  final double gridSpacing;

  /// Radius (in logical pixels) of the animated data-packet dot travelling
  /// along each link. Default: 4.0.
  final double packetRadius;

  /// Duration (in seconds) of one full packet animation cycle along a link.
  /// The packet dot completes one source-to-target traversal every
  /// [packetAnimationPeriod] seconds. Default: 2.0.
  final double packetAnimationPeriod;

  /// Radius (in logical pixels) of non-focused node circles. Default: 9.0.
  final double nodeRadiusDefault;

  /// Radius (in logical pixels) of the currently focused node circle.
  /// Should be larger than [nodeRadiusDefault] for visual emphasis.
  /// Default: 12.0.
  final double nodeRadiusFocused;

  /// Multiplier applied to trajectory velocity vectors when rendering the
  /// velocity indicator line. A value of 1.0 draws the line at true vector
  /// length; 2.0 doubles the visual length for readability on sparse maps.
  /// Default: 2.0.
  final double velocityScale;

  /// Radius (in logical pixels) of the pulsing halo ring drawn around the
  /// focused node. Default: 20.0.
  final double haloRadius;

  /// Font size (in logical pixels) for node labels rendered below each node
  /// circle. Default: 12.0.
  final double labelFontSize;

  // -- Playback constants --

  /// Fallback minimum time index used when the topology data is empty or no
  /// node has a valid time coordinate. Inferred from data when possible.
  /// Default: 1.0.
  final double defaultMinTime;

  /// Fallback maximum time index used when the topology data is empty or no
  /// node has a valid time coordinate. Inferred from data when possible.
  /// If all nodes share the same time, [maxTime] is widened to
  /// [defaultMinTime] + ([defaultMaxTime] - [defaultMinTime]).
  /// Default: 10.0.
  final double defaultMaxTime;

  /// The number of discrete steps in the playback time slider. Higher values
  /// provide finer granularity for scrubbing. Applied via `Slider.divisions`.
  /// Default: 90.
  final int sliderDivisions;

  // -- Layout constants --

  /// Minimum viewport width (in logical pixels) for the scrollable canvas.
  /// When the available width from [LayoutBuilder] exceeds this value the
  /// actual available width is used; otherwise this value becomes the canvas
  /// width. Default: 800.0.
  final double minViewportWidth;

  /// Minimum viewport height (in logical pixels) for the scrollable canvas.
  /// When the available height from [LayoutBuilder] exceeds this value the
  /// actual available height is used; otherwise this value becomes the canvas
  /// height. Default: 500.0.
  final double minViewportHeight;

  /// Width (in logical pixels) allocated to the numeric time display in the
  /// playback panel. Default: 32.0.
  final double timeDisplayWidth;

  const TopologyMap({
    super.key,
    this.activeFocusedNode,
    this.onNodeSelect,
    this.data,
    this.tapProximity = 20.0,
    this.gridSpacing = 40.0,
    this.packetRadius = 4.0,
    this.packetAnimationPeriod = 2.0,
    this.nodeRadiusDefault = 9.0,
    this.nodeRadiusFocused = 12.0,
    this.velocityScale = 2.0,
    this.defaultMinTime = 1.0,
    this.defaultMaxTime = 10.0,
    this.minViewportWidth = 800.0,
    this.minViewportHeight = 500.0,
    this.timeDisplayWidth = 32.0,
    this.haloRadius = 20.0,
    this.sliderDivisions = 90,
    this.labelFontSize = 12.0,
  });

  @override
  State<TopologyMap> createState() => _TopologyMapState();
}

class _TopologyMapState extends State<TopologyMap>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double currentTimeIndex = 1.0;
  double playbackSpeedMultiplier = 1.0;
  bool isPlaying = false;
  Duration _lastElapsed = Duration.zero;

  double get minTime {
    final TopologyData activeData = widget.data ?? emptyTopologyData;
    if (activeData.nodes.isEmpty) return widget.defaultMinTime;
    double minT = double.infinity;
    for (final TopologyNode node in activeData.nodes) {
      final double t = node.resolveCoordinate('t', activeData.coordinateMapping);
      if (t < minT) minT = t;
    }
    return minT == double.infinity ? widget.defaultMinTime : minT;
  }

  double get maxTime {
    final TopologyData activeData = widget.data ?? emptyTopologyData;
    if (activeData.nodes.isEmpty) return widget.defaultMaxTime;
    double maxT = -double.infinity;
    for (final TopologyNode node in activeData.nodes) {
      final double t = node.resolveCoordinate('t', activeData.coordinateMapping);
      if (t > maxT) maxT = t;
    }
    if (maxT == -double.infinity) return widget.defaultMaxTime;
    final double minT = minTime;
    if (maxT == minT) {
      return minT + widget.defaultMaxTime - widget.defaultMinTime;
    }
    return maxT;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    currentTimeIndex = minTime;
  }

  @override
  void didUpdateWidget(covariant TopologyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      final double minT = minTime;
      final double maxT = maxTime;
      if (currentTimeIndex < minT || currentTimeIndex > maxT) {
        currentTimeIndex = minT;
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final double deltaSeconds =
        (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    if (isPlaying) {
      final double minT = minTime;
      final double maxT = maxTime;
      setState(() {
        currentTimeIndex += deltaSeconds * playbackSpeedMultiplier;
        if (currentTimeIndex > maxT) {
          currentTimeIndex = minT; // Loop back
        }
      });
    }
  }

  void togglePlayback() {
    setState(() {
      isPlaying = !isPlaying;
      if (isPlaying) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      } else {
        _ticker.stop();
      }
    });
  }

  void setPlayhead(double timeIndex) {
    final double minT = minTime;
    final double maxT = maxTime;
    setState(() {
      currentTimeIndex = timeIndex.clamp(minT, maxT);
    });
  }

  void _handleTap(TapUpDetails details) {
    final TopologyData activeData = widget.data ?? emptyTopologyData;
    final double clickX = details.localPosition.dx;
    final double clickY = details.localPosition.dy;

    for (final TopologyNode node in activeData.nodes) {
      final Offset pos = node.computePosition(activeData, currentTimeIndex);
      final double dist = math.sqrt(
          (clickX - pos.dx) * (clickX - pos.dx) +
              (clickY - pos.dy) * (clickY - pos.dy));

      if (dist <= widget.tapProximity) {
        widget.onNodeSelect?.call(node.id);
        break;
      }
    }
  }

  Widget _buildPlaybackPanel(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            ElevatedButton(
              key: const ValueKey<String>('playPauseButton'),
              onPressed: togglePlayback,
              style: ElevatedButton.styleFrom(
                backgroundColor: isPlaying ? colors.error : colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 6.0),
                minimumSize: const Size(70, 32),
              ),
              child: Text(
                isPlaying ? 'Pause' : 'Play',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('t:', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 8),
                SizedBox(
                  width: widget.timeDisplayWidth,
                  child: Text(
                    currentTimeIndex.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 200,
              child: Slider(
                key: const ValueKey<String>('timeSlider'),
                min: minTime,
                max: maxTime,
                divisions: widget.sliderDivisions,
                value: currentTimeIndex.clamp(minTime, maxTime),
                onChanged: (double value) {
                  setPlayhead(value);
                },
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Speed:', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                DropdownButton<double>(
                  key: const ValueKey<String>('speedDropdown'),
                  value: playbackSpeedMultiplier,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.arrow_drop_down),
                  style: Theme.of(context).textTheme.bodySmall,
                  items: const <DropdownMenuItem<double>>[
                    DropdownMenuItem<double>(value: 0.5, child: Text('0.5x')),
                    DropdownMenuItem<double>(value: 1.0, child: Text('1.0x')),
                    DropdownMenuItem<double>(value: 2.0, child: Text('2.0x')),
                    DropdownMenuItem<double>(value: 5.0, child: Text('5.0x')),
                  ],
                  onChanged: (double? value) {
                    if (value != null) {
                      setState(() {
                        playbackSpeedMultiplier = value;
                      });
                    }
                  },
                ),
              ],
            ),
        ],
      ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TopologyData activeData = widget.data ?? emptyTopologyData;

    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : widget.minViewportWidth;
        final double viewportHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : widget.minViewportHeight;
        final double width = viewportWidth > widget.minViewportWidth ? viewportWidth : widget.minViewportWidth;
        final double height = viewportHeight > widget.minViewportHeight ? viewportHeight : widget.minViewportHeight;

        return Container(
          color: colors.surfaceContainerHighest,
          child: Column(
            children: <Widget>[
              // Scrollable Canvas Viewport
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (TapUpDetails details) =>
                            _handleTap(details),
                        child: CustomPaint(
                          size: Size(width, height),
                          painter: TopologyPainter(
                            activeFocusedNode: widget.activeFocusedNode,
                            activeData: activeData,
                            currentTimeIndex: currentTimeIndex,
                            gridSpacing: widget.gridSpacing,
                            packetRadius: widget.packetRadius,
                            packetAnimationPeriod: widget.packetAnimationPeriod,
                            nodeRadiusDefault: widget.nodeRadiusDefault,
                            nodeRadiusFocused: widget.nodeRadiusFocused,
                            velocityScale: widget.velocityScale,
                            haloRadius: widget.haloRadius,
                            labelFontSize: widget.labelFontSize,
                            colors: TopologyPainterColors(
                              bgColor: colors.surfaceContainerHighest,
                              gridColor: colors.outlineVariant,
                              linkColor: colors.primary.withValues(alpha: 0.35),
                              packetColor: colors.primary,
                              velocityColor: colors.error.withValues(alpha: 0.4),
                              nodeFillColor: colors.primary,
                              nodeStrokeColor: colors.onPrimary,
                              activeStatusColor: colors.tertiary,
                              warningStatusColor: colors.error,
                              haloColor: colors.primary.withValues(alpha: 0.3),
                              labelColor: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildPlaybackPanel(colors),
            ],
          ),
        );
      },
    );
  }
}

/// Colour palette consumed by [TopologyPainter] for all rendered elements.
///
/// Immutable; should be constructed once per paint cycle from the current
/// [ColorScheme] to stay in sync with theme changes.
class TopologyPainterColors {
  /// Canvas background colour. Fills the entire paint area before any other
  /// element is drawn.
  final Color bgColor;

  /// Colour for the background grid lines.
  final Color gridColor;

  /// Colour for link lines connecting nodes.
  final Color linkColor;

  /// Colour for the animated data-packet dot that travels along each link.
  final Color packetColor;

  /// Colour for the velocity / trajectory vector line emanating from each
  /// node.
  final Color velocityColor;

  /// Fill colour for the focused node circle.
  final Color nodeFillColor;

  /// Stroke (outline) colour for the focused node circle.
  final Color nodeStrokeColor;

  /// Fill colour for nodes whose [TopologyNode.status] equals "Active".
  final Color activeStatusColor;

  /// Fill colour for nodes whose [TopologyNode.status] is anything other
  /// than "Active".
  final Color warningStatusColor;

  /// Colour for the pulsing halo ring drawn around the focused node.
  final Color haloColor;

  /// Colour for node labels rendered below each node circle.
  final Color labelColor;

  const TopologyPainterColors({
    required this.bgColor,
    required this.gridColor,
    required this.linkColor,
    required this.packetColor,
    required this.velocityColor,
    required this.nodeFillColor,
    required this.nodeStrokeColor,
    required this.activeStatusColor,
    required this.warningStatusColor,
    required this.haloColor,
    required this.labelColor,
  });
}

/// Custom canvas painter for the topology map: grid, nodes, links, velocity
/// vectors, animated packets, halos, and labels.
///
/// Paint order: background → grid → node positions → links → packets →
/// nodes (fill + stroke) → halo (focused only) → labels. Redraws when
/// [currentTimeIndex], [activeFocusedNode], [activeData], or [colors] change.
///
/// Visual parameters such as [gridSpacing], [nodeRadiusDefault],
/// [velocityScale], and others are configurable via constructor fields with
/// sensible defaults, allowing callers to tune rendering without subclassing.
class TopologyPainter extends CustomPainter {
  /// Identifier of the node that should receive visual focus (larger radius,
  /// halo ring). Pass `null` to clear focus.
  final String? activeFocusedNode;

  /// The topology data rendered in the current paint cycle. Must be non-null;
  /// use [emptyTopologyData] for a blank canvas.
  final TopologyData activeData;

  /// Current playback time index. Used to compute node positions via
  /// [TopologyNode.computePosition] and to animate packet dots along links.
  final double currentTimeIndex;

  /// Colour palette for all painted elements. Should be reconstructed each
  /// paint cycle from the current [ColorScheme] to reflect theme changes.
  final TopologyPainterColors colors;

  // -- Geometry & layout --

  /// Horizontal and vertical spacing (in logical pixels) between consecutive
  /// background grid lines. Default: 40.0.
  final double gridSpacing;

  /// Radius (in logical pixels) of the animated data-packet dot that travels
  /// along each link. Default: 4.0.
  final double packetRadius;

  /// Duration (in seconds) of one full packet animation cycle along a link.
  /// The packet dot completes one source-to-target traversal every
  /// [packetAnimationPeriod] seconds. Default: 2.0.
  final double packetAnimationPeriod;

  /// Radius (in logical pixels) of non-focused node circles. Default: 9.0.
  final double nodeRadiusDefault;

  /// Radius (in logical pixels) of the currently focused node circle.
  /// Should be larger than [nodeRadiusDefault] for visual distinction.
  /// Default: 12.0.
  final double nodeRadiusFocused;

  /// Multiplier applied to trajectory velocity vectors when drawing the
  /// velocity indicator line. Higher values exaggerate direction for
  /// readability. Default: 2.0.
  final double velocityScale;

  /// Radius (in logical pixels) of the pulsing halo ring drawn around the
  /// focused node. Default: 20.0.
  final double haloRadius;

  /// Font size (in logical pixels) for node labels rendered below each node
  /// circle. Default: 12.0.
  final double labelFontSize;

  TopologyPainter({
    required this.activeFocusedNode,
    required this.activeData,
    required this.currentTimeIndex,
    required this.colors,
    this.gridSpacing = 40.0,
    this.packetRadius = 4.0,
    this.packetAnimationPeriod = 2.0,
    this.nodeRadiusDefault = 9.0,
    this.nodeRadiusFocused = 12.0,
    this.velocityScale = 2.0,
    this.haloRadius = 20.0,
    this.labelFontSize = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw background
    final Paint bgPaint = Paint()..color = colors.bgColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Draw grid lines every 40px
    final Paint gridPaint = Paint()
      ..color = colors.gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Compute projected positions
    final Map<String, Offset> projectedPositions = <String, Offset>{};
    for (final TopologyNode node in activeData.nodes) {
      projectedPositions[node.id] = node.computePosition(activeData, currentTimeIndex);
    }

    // 4. Draw links
    for (final TopologyLink link in activeData.links) {
      final Offset? sourceOffset = projectedPositions[link.source];
      final Offset? targetOffset = projectedPositions[link.target];

      if (sourceOffset != null && targetOffset != null) {
        // Connector link line
        final Paint linkPaint = Paint()
          ..color = colors.linkColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(sourceOffset, targetOffset, linkPaint);

        // Animated data packet along link path
        final double packetRatio = (currentTimeIndex % packetAnimationPeriod) / packetAnimationPeriod;
        final double px =
            sourceOffset.dx + (targetOffset.dx - sourceOffset.dx) * packetRatio;
        final double py =
            sourceOffset.dy + (targetOffset.dy - sourceOffset.dy) * packetRatio;

        final Paint packetPaint = Paint()
          ..color = colors.packetColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), packetRadius, packetPaint);
      }
    }

    // 5. Draw nodes
    for (final TopologyNode node in activeData.nodes) {
      final Offset? pos = projectedPositions[node.id];
      if (pos == null) continue;

      final bool isFocused = activeFocusedNode == node.id;
      final List<double> vector = node.resolveVector('trajectory', activeData.coordinateMapping);
      final double vx = vector.isNotEmpty ? vector[0] : 0.0;
      final double vy = vector.length > 1 ? vector[1] : 0.0;

      // Velocity vector line
      final Paint vectorPaint = Paint()
        ..color = colors.velocityColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
          pos, Offset(pos.dx + vx * velocityScale, pos.dy + vy * velocityScale), vectorPaint);

      // Node base circle representation
      final Paint fillPaint = Paint()..style = PaintingStyle.fill;
      final Paint strokePaint = Paint()..style = PaintingStyle.stroke;
      final double radius = isFocused ? nodeRadiusFocused : nodeRadiusDefault;

      if (isFocused) {
        fillPaint.color = colors.nodeFillColor;
        strokePaint
          ..color = colors.nodeStrokeColor
          ..strokeWidth = 2.5;
      } else {
        fillPaint.color = node.status == 'Active'
            ? colors.activeStatusColor
            : colors.warningStatusColor;
        strokePaint
          ..color = colors.gridColor
          ..strokeWidth = 2.0;
      }

      canvas.drawCircle(pos, radius, fillPaint);
      canvas.drawCircle(pos, radius, strokePaint);

      // Pulsing halo ring around focused node
      if (isFocused) {
        final Paint haloPaint = Paint()
          ..color = colors.haloColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pos, haloRadius, haloPaint);
      }

      // Draw node label below
      final TextPainter textPainter = _TextPainterCache.getOrCreate(
        node.label,
        colors.labelColor,
        labelFontSize,
      );
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2.0, pos.dy + 14.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) {
    return oldDelegate.currentTimeIndex != currentTimeIndex ||
        oldDelegate.activeFocusedNode != activeFocusedNode ||
        oldDelegate.activeData != activeData ||
        oldDelegate.colors != colors;
  }
}

class _TextPainterKey {
  final String text;
  final Color color;
  final double fontSize;
  _TextPainterKey(this.text, this.color, this.fontSize);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TextPainterKey &&
          text == other.text &&
          color == other.color &&
          fontSize == other.fontSize;

  @override
  int get hashCode => Object.hash(text, color, fontSize);
}

class _TextPainterCache {
  static final Map<_TextPainterKey, TextPainter> _cache = {};
  static const int _maxEntries = 256;

  static TextPainter getOrCreate(String text, Color color, double fontSize) {
    final key = _TextPainterKey(text, color, fontSize);
    final existing = _cache[key];
    if (existing != null) return existing;

    if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    _cache[key] = painter;
    return painter;
  }
}
