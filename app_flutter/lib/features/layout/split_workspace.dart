import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';

/// A resizable split pane that lays out [leading] and [trailing] widgets
/// along [direction] with a draggable divider.
///
/// The initial split ratio is set from [initialRatio] once the available size
/// is known. The first pane is clamped between [minFirstPaneSize] and
/// (`totalSize - minFirstPaneSize`). The divider shows a resize cursor and
/// fires [onDrag] with the current first-pane size during drag.
///
/// Edge cases: when constraints are zero (e.g. not yet laid out), the splitter
/// is not rendered. When total size is insufficient for both minimums, the
/// first pane takes its minimum and the trailing pane fills the remainder
/// (may be smaller than [minFirstPaneSize]).
///
/// The visual appearance of the divider can be tuned via [dividerSize],
/// [gripWidth], and [gripHeight]. [dividerSize] determines the thickness of
/// the splitter strip, while [gripWidth] and [gripHeight] control the inner
/// drag handle dimensions. When [direction] is [Axis.horizontal], the
/// divider's width equals [dividerSize] and the grip handle is centered inside
/// it; the axes are swapped for [Axis.vertical].
class SplitWorkspace extends StatefulWidget {
  final Widget leading;
  final Widget trailing;
  final Axis direction;
  final double minFirstPaneSize;
  final double initialRatio;
  /// Thickness of the draggable divider strip in logical pixels.
  ///
  /// When [direction] is [Axis.horizontal] this is the divider's width; when
  /// [direction] is [Axis.vertical] this is its height. The divider
  /// background uses [Theme.dividerColor] and is inset by 1 px borders on
  /// both sides. Defaults to 8.0.
  final double dividerSize;

  /// Width of the inner drag-grip rectangle in logical pixels.
  ///
  /// The grip is centered inside the divider strip and rendered with the
  /// theme's icon color at 30% opacity. When [direction] is [Axis.horizontal]
  /// this value is used as the grip's width; for [Axis.vertical] it becomes
  /// the grip's height (the orientation is swapped). Defaults to 2.0.
  final double gripWidth;

  /// Height of the inner drag-grip rectangle in logical pixels.
  ///
  /// The grip is centered inside the divider strip and rendered with the
  /// theme's icon color at 30% opacity. When [direction] is [Axis.horizontal]
  /// this value is used as the grip's height; for [Axis.vertical] it becomes
  /// the grip's width (the orientation is swapped). Defaults to 40.0.
  final double gripHeight;
  final Key? splitterKey;
  final ValueChanged<double>? onDrag;

  final bool paintLeadingOnTop;

  const SplitWorkspace({
    super.key,
    required this.leading,
    required this.trailing,
    required this.direction,
    required this.minFirstPaneSize,
    required this.initialRatio,
    this.dividerSize = 8.0,
    this.gripWidth = 2.0,
    this.gripHeight = 40.0,
    this.splitterKey,
    this.onDrag,
    this.paintLeadingOnTop = false,
  });

  @override
  State<SplitWorkspace> createState() => _SplitWorkspaceState();
}

class _SplitWorkspaceState extends State<SplitWorkspace> {
  double _firstPaneSize = 0;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final panelOpacity = context.watch<ThemeController>().panelOpacity;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSize = widget.direction == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;

        if (!_initialized && totalSize > 0) {
          _firstPaneSize = totalSize * widget.initialRatio;
          _initialized = true;
        }

        final clampedFirstPane = _firstPaneSize.clamp(
          widget.minFirstPaneSize,
          math.max(widget.minFirstPaneSize, totalSize - widget.minFirstPaneSize),
        ).toDouble();

        final isHorizontal = widget.direction == Axis.horizontal;

        final splitter = GestureDetector(
          key: widget.splitterKey,
          onHorizontalDragUpdate: isHorizontal
              ? (details) {
                  setState(() {
                    _firstPaneSize = (_firstPaneSize + details.delta.dx)
                        .clamp(widget.minFirstPaneSize, math.max(widget.minFirstPaneSize, totalSize - widget.minFirstPaneSize)).toDouble();
                  });
                  widget.onDrag?.call(_firstPaneSize);
                }
              : null,
          onVerticalDragUpdate: !isHorizontal
              ? (details) {
                  setState(() {
                    _firstPaneSize = (_firstPaneSize + details.delta.dy)
                        .clamp(widget.minFirstPaneSize, math.max(widget.minFirstPaneSize, totalSize - widget.minFirstPaneSize)).toDouble();
                  });
                  widget.onDrag?.call(_firstPaneSize);
                }
              : null,
          child: MouseRegion(
            cursor: isHorizontal
                ? SystemMouseCursors.resizeLeftRight
                : SystemMouseCursors.resizeUpDown,
            child: Container(
              width: isHorizontal ? widget.dividerSize : double.infinity,
              height: isHorizontal ? double.infinity : widget.dividerSize,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(panelOpacity),
                border: isHorizontal
                    ? Border(
                        left: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      )
                    : Border(
                        top: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
              ),
              child: Center(
                child: Container(
                  width: isHorizontal ? widget.gripWidth : widget.gripHeight,
                  height: isHorizontal ? widget.gripHeight : widget.gripWidth,
                  color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.3) ??
                      Theme.of(context).dividerColor,
                ),
              ),
            ),
          ),
        );

        final leadingPane = isHorizontal
            ? SizedBox(width: clampedFirstPane, child: RepaintBoundary(child: widget.leading))
            : SizedBox(height: clampedFirstPane, child: RepaintBoundary(child: widget.leading));

        final trailingPane = RepaintBoundary(child: widget.trailing);

        final splitterWidget = Positioned(
          left: isHorizontal ? clampedFirstPane : 0,
          right: isHorizontal ? null : 0,
          top: isHorizontal ? 0 : clampedFirstPane,
          bottom: isHorizontal ? 0 : null,
          width: isHorizontal ? widget.dividerSize : null,
          height: isHorizontal ? null : widget.dividerSize,
          child: RepaintBoundary(child: splitter),
        );

        final leadingWidget = Positioned(
          left: 0,
          right: isHorizontal ? null : 0,
          top: 0,
          bottom: isHorizontal ? 0 : null,
          width: isHorizontal ? clampedFirstPane : null,
          height: isHorizontal ? null : clampedFirstPane,
          child: leadingPane,
        );

        final trailingWidget = Positioned(
          left: isHorizontal ? clampedFirstPane + widget.dividerSize : 0,
          right: 0,
          top: isHorizontal ? 0 : clampedFirstPane + widget.dividerSize,
          bottom: 0,
          child: trailingPane,
        );

        final List<Widget> children = widget.paintLeadingOnTop
            ? [trailingWidget, splitterWidget, leadingWidget]
            : [leadingWidget, splitterWidget, trailingWidget];

        return Stack(
          children: children,
        );
      },
    );
  }
}
