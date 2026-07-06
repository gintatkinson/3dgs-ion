# Code Review: Workspace Layout & Navigation Control

This review covers the following files:
1. [split_workspace.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/split_workspace.dart)
2. [layout_config_service.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/layout_config_service.dart)
3. [layout.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/layout.dart)
4. [component_factory.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/layout/component_factory.dart)
5. [app.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/app/app.dart)

---

## 1. Context & Architecture

### Synchronous Disk I/O on UI Thread
- **Tracking Issue**: [GitHub Issue #68](https://github.com/gintatkinson/3dgs-002/issues/68)
- **Severity**: 🔴 Critical
- **Location**: `app_flutter/lib/features/layout/layout.dart` (lines 146–161, 241–256)
- **Issue**: The layout engine reads configuration files synchronously using `File.readAsStringSync()` during the widget build phase (via `_getDefaultRatio()`, `_resolveCoordinateMapping()`, and `_resolveLabelsMapping()`). Synchronous disk operations block the main UI thread, resulting in frame drops (jank). Furthermore, using `dart:io` `File` with relative paths (`.pipeline/...`) is non-portable and will fail on mobile platforms (iOS/Android) where assets must be loaded via the Flutter `rootBundle`.
- **Suggestion**: Shift all external resource loading to be asynchronous during initialization, or package configurations as standard Flutter assets and read them using `rootBundle.loadString()`.
- **Example**:
  ```dart
  // In initState or didChangeDependencies, load asynchronously:
  Future<void> loadCodebaseRules() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/codebase_rules.json');
      final rules = jsonDecode(jsonStr) as Map<String, dynamic>;
      setState(() {
        _cachedRules = rules;
      });
    } catch (e) {
      debugPrint('Failed to load rules: $e');
    }
  }
  ```

### Redundant Configuration Loading
- **Tracking Issue**: [GitHub Issue #88](https://github.com/gintatkinson/3dgs-002/issues/88)
- **Severity**: 🟠 Important
- **Location**: `app_flutter/lib/app/app.dart` (lines 45–85) & `app_flutter/lib/features/layout/layout.dart` (lines 173–177, 302–315)
- **Issue**: Both `DashboardPage` (via `FutureBuilder` + `rootBundle.loadString`) and `Layout` (via its own internal fallback `_loadLayoutConfig()`) contain logic to load the same `logical-layout.json` config. If `layoutConfig` is passed down, `Layout` uses it; otherwise, `Layout` loads it itself. The duplicate logic adds unnecessary nesting and complexity to the top-level app widget.
- **Suggestion**: Remove the `FutureBuilder` from `DashboardPage` and let the `Layout` widget handle its own configuration loading.
- **Example**:
  ```dart
  // In app.dart (DashboardPage build method):
  @override
  Widget build(BuildContext context) {
    return Layout(
      activeView: _activeView,
      onViewChange: (newView) {
        setState(() {
          _activeView = newView;
        });
      },
    );
  }
  ```

---

## 2. Correctness & Reactivity

### Split Workspace Zero-Constraints Overflow
- **Tracking Issue**: [GitHub Issue #69](https://github.com/gintatkinson/3dgs-002/issues/69)
- **Severity**: 🟠 Important
- **Location**: `app_flutter/lib/features/layout/split_workspace.dart` (lines 91–100)
- **Issue**: The layout builder performs layout calculations even when constraints are zero (e.g., during the initial layout pass or inside unconstrained layouts). Although the documentation states "when constraints are zero, the splitter is not rendered", there is no guard clause. As a result, `clampedFirstPane` is clamped to `widget.minFirstPaneSize` (since `max(min, 0 - min) => min`), forcing the layout of leading/trailing panes at full minimum size within a 0-pixel space, triggering layout overflow exceptions.
- **Suggestion**: Add a guard clause returning `SizedBox.shrink()` or a placeholder when `totalSize == 0`.
- **Example**:
  ```dart
  final totalSize = widget.direction == Axis.horizontal
      ? constraints.maxWidth
      : constraints.maxHeight;

  if (totalSize <= 0) {
    return const SizedBox.shrink();
  }
  ```

### External View Updates Out of Sync with Sidebar Tree
- **Tracking Issue**: [GitHub Issue #89](https://github.com/gintatkinson/3dgs-002/issues/89)
- **Severity**: 🟠 Important
- **Location**: `app_flutter/lib/features/layout/layout.dart` (lines 212–223)
- **Issue**: In `didUpdateWidget`, when the active view is changed externally via `widget.activeView`, the local state `_currentView` is updated and properties are resubscribed, but the `_treeViewModel` is never notified. This causes the tree sidebar highlight to get out of sync with the main panel view when the change originates from outside `Layout`.
- **Suggestion**: Call `_treeViewModel?.updateCurrentView(widget.activeView)` inside the `didUpdateWidget` block.
- **Example**:
  ```dart
  @override
  void didUpdateWidget(covariant Layout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeView != null && widget.activeView != oldWidget.activeView) {
      if (_currentView != widget.activeView) {
        setState(() {
          _currentView = widget.activeView!;
        });
        _treeViewModel?.updateCurrentView(_currentView);
        _subscribeProperties(_currentView);
        _propertiesViewModel?.loadType(_currentView);
      }
    }
  }
  ```

### Fragile Map Type Casting
- **Tracking Issue**: [GitHub Issue #90](https://github.com/gintatkinson/3dgs-002/issues/90)
- **Severity**: 🟠 Important
- **Location**: `app_flutter/lib/features/layout/layout_config_service.dart` (lines 6, 21–22, 39–40)
- **Issue**: Safe casts such as `current is Map<String, dynamic>` and explicit casts like `as Map<String, dynamic>` will fail at runtime if the map has a different runtime type signature (such as `Map<dynamic, dynamic>` or `Map<String, Object?>` returned from certain custom JSON decoders or testing mocks). This will throw a `TypeError` (which gets caught and swallowed by the empty `catch (_)` blocks, returning silent fallbacks).
- **Suggestion**: Check for `Map` generally, and use `Map.from()` or cast elements safely when copying.
- **Example**:
  ```dart
  if (current is Map && current.containsKey(part)) {
    current = current[part];
  }
  // And for conversions:
  final rawMap = Map<String, dynamic>.from(
      layoutConfig['layout_mappings']['coordinate_mapping'] as Map);
  ```

---

## 3. Performance & Quality

### Hardcoded Default Ratios and Snapping during Resizing
- **Tracking Issue**: [GitHub Issue #102](docs/reviews/review_layout.md)
- **Severity**: 🟡 Suggestion
- **Location**: `app_flutter/lib/features/layout/split_workspace.dart` (lines 79–120)
- **Issue**: The split workspace keeps the first pane size as an absolute pixel count (`_firstPaneSize`). When the parent container is resized (e.g., maximizing the window), the split pane does not scale proportionally but stays at its absolute size. If the window shrinks below the absolute size, the first pane gets clamped but doesn't restore its proportion when the window is expanded again.
- **Suggestion**: Store the workspace split as a ratio (between `0.0` and `1.0`) instead of absolute logical pixels. Calculate pixel coordinates on the fly inside the `build` method using the current `totalSize`.
- **Example**:
  ```dart
  // Store _ratio in State
  double _ratio = widget.initialRatio;

  // In build:
  final totalSize = ...;
  final firstPaneSize = totalSize * _ratio;
  final clampedFirstPane = firstPaneSize.clamp(
    widget.minFirstPaneSize,
    math.max(widget.minFirstPaneSize, totalSize - widget.minFirstPaneSize),
  );
  
  // In drag update:
  onHorizontalDragUpdate: (details) {
    setState(() {
      final newSize = (totalSize * _ratio + details.delta.dx);
      _ratio = (newSize / totalSize).clamp(0.0, 1.0);
    });
  }
  ```

### Unused Tab ID in Table View Container
- **Severity**: 💡 Nitpick
- **Location**: `app_flutter/lib/features/layout/component_factory.dart` (lines 265–316)
- **Issue**: `_TableViewContainer` defines and accepts `tabId` in its constructor, but does not use it anywhere in its build method or pass it down to `TableViewWidget`.
- **Suggestion**: Verify if the `tabId` is meant to be supplied to the `TableViewWidget` or used within `TablesViewModel` to display the correct tab data. If it is redundant, remove it to prevent confusion.
- **Example**:
  ```dart
  // If TableViewWidget requires tabId:
  return ChangeNotifierProvider<TablesViewModel>.value(
    value: _viewModel!,
    child: TableViewWidget(tabId: widget.tabId),
  );
  ```

### Hardcoded Initial Active View
- **Tracking Issue**: [GitHub Issue #103](docs/reviews/review_layout.md)
- **Severity**: 💡 Nitpick
- **Location**: `app_flutter/lib/app/app.dart` (line 44)
- **Issue**: `_activeView` is hardcoded to `'Master_1'`. If the database is empty or doesn't contain a node with this ID, the UI will try to watch non-existent properties. Leaving it `null` would allow the `Layout` widget's automatic fallback (`_updateCurrentViewFromLayout()`) to resolve and highlight the first valid tree node dynamically.
- **Suggestion**: Set the initial view to `null` to leverage the layout engine's dynamic first-available node fallback.
- **Example**:
  ```dart
  String? _activeView; // Falls back to first tree node dynamically
  ```
