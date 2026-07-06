# Code Review: Tree, Tables, Properties & Grid UI Controls

This artifact contains a thorough code review of the Tree, Tables, Properties, and Grid UI Controls in the `app_flutter` codebase.
The review is structured according to the categories: **Correctness**, **Performance**, **Quality (UX/Accessibility)**, and **Architecture**.

---

## 1. Correctness

### 🔴 Broken Sorting when Columns are Hidden in `TableViewWidget`
*   **Tracking Issue**: [GitHub Issue #61](https://github.com/gintatkinson/3dgs-002/issues/61)
*   **Severity**: 🔴 Critical
*   **Location**: [table_view_widget.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/table_view_widget.dart#L78-L86)
*   **Issue**: `_sortColumnIndex` represents the index in the *visible* column list (`headers`), but the sorting function reads the row cells using `a[_sortColumnIndex!]` directly. The cells list in a row corresponds to the *full* column list (`allHeaders`). When some columns are hidden, the visible index will point to incorrect data cells, sorting by the wrong column or throwing an index out of bounds exception.
*   **Suggestion**: Map the sorted column key from the visible list to the absolute index in the full header list using a key-to-index map.
*   **Example**:
    ```dart
    // Fix: Map visible column index to absolute row data index
    if (_sortColumnIndex != null && _sortColumnIndex! < headers.length) {
      final sortKey = headers[_sortColumnIndex!].key;
      final absoluteIndex = allHeaders.indexWhere((h) => h.key == sortKey);
      if (absoluteIndex != -1) {
        final sortedRows = List<List<String>>.from(rows);
        sortedRows.sort((a, b) {
          final aVal = absoluteIndex < a.length ? a[absoluteIndex] : '';
          final bVal = absoluteIndex < b.length ? b[absoluteIndex] : '';
          return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
        });
        rows = sortedRows;
      }
    }
    ```

### 🔴 Layout Alignment Bug between Header and Data Cells in `TableViewWidget`
*   **Tracking Issue**: [GitHub Issue #61](https://github.com/gintatkinson/3dgs-002/issues/61)
*   **Severity**: 🔴 Critical
*   **Location**: [table_view_widget.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/table_view_widget.dart#L388-L389)
*   **Issue**: The header cell width checks and respects `columnWidth ?? colWidth`, but the data cell width is hardcoded to `colWidth`. If any column specifies a custom width via its model, the headers and data columns will misalign visually.
*   **Suggestion**: Use `columnModel.width ?? colWidth` for the data cell's `SizedBox` width.
*   **Example**:
    ```dart
    return SizedBox(
      width: columnModel.width ?? colWidth, // Fix: respect custom column widths
      child: Padding( ... ),
    );
    ```

### 🔴 State Rebuilding Crash on Dispose in `PropertyGrid` Focus Node Listener
*   **Tracking Issue**: [GitHub Issue #61](https://github.com/gintatkinson/3dgs-002/issues/61)
*   **Severity**: 🔴 Critical
*   **Location**: [property_grid.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/properties/property_grid.dart#L182-L193)
*   **Issue**: During widget didUpdateWidget or disposal, calling `focusNode.dispose()` on a currently focused text field causes it to lose focus. This triggers its focus change listener synchronously. The listener then calls `_triggerBlurSave`, which performs a `setState` or triggers a callback that triggers parent widget updates. Calling `setState` inside the build or update phase triggers the Flutter framework crash: `setState() or markNeedsBuild() called during build`.
*   **Suggestion**: Detach or remove focus listeners before disposing the focus nodes in `_disposeAllFields`.
*   **Example**:
    ```dart
    void _disposeAllFields() {
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      // Note: Since we use anonymous listeners, we should clean up focus manually or clear listeners
      // before disposal. An easy way is to request unfocus first, or store the listener references,
      // or set a flag `_isDisposing = true` to ignore callbacks during disposal.
      _isDisposing = true;
      for (final focusNode in _focusNodes.values) {
        focusNode.dispose();
      }
      _controllers.clear();
      _focusNodes.clear();
      _hadFocus.clear();
      _errors = const {};
    }
    ```

### 🔴 Dropdown Value Sync Bug in `PropertyGrid`
*   **Tracking Issue**: [GitHub Issue #61](https://github.com/gintatkinson/3dgs-002/issues/61)
*   **Severity**: 🔴 Critical
*   **Location**: [property_grid.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/properties/property_grid.dart#L718)
*   **Issue**: `DropdownButtonFormField` is built with `initialValue: value` instead of `value: value`. `initialValue` is only applied once during initialization. If the parent updates `initialValues` or `committedData` externally after initialization, the dropdown selection will not update, leaving the UI state out of sync.
*   **Suggestion**: Use the `value` property of `DropdownButtonFormField` instead of `initialValue`.
*   **Example**:
    ```dart
    DropdownButtonFormField<String>(
      isExpanded: true,
      value: value, // Fix: use value instead of initialValue
      dropdownColor: ...
    ```

### 🟠 Global Fallback State Mutation in `TreeViewModel`
- **Tracking Issue**: [GitHub Issue #104](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟠 Important
*   **Location**: [tree_view_model.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tree/view_models/tree_view_model.dart#L58)
*   **Issue**: If `roots` is empty, the view model calls `_treeData = List<TreeNode>.from(defaultTreeData);`. This is a shallow copy of the list. The elements inside the list are still the exact same shared `TreeNode` references from the global `defaultTreeData` array. Sorting the list or dynamically adding child nodes will mutate the global `defaultTreeData` array elements, leaking state changes across different model instances.
*   **Suggestion**: Deep clone the default nodes or instantiate a new list from a generator function rather than referencing a mutable shared global array.
*   **Example**:
    ```dart
    // In tree_node.dart, add a copy/clone method:
    TreeNode clone() => TreeNode(
      id: id,
      label: label,
      children: children?.map((c) => c.clone()).toList(),
    );

    // In tree_view_model.dart:
    _treeData = roots.isNotEmpty 
        ? roots 
        : defaultTreeData.map((node) => node.clone()).toList();
    ```

### 🟠 StateError on Watch Subscription in `TablesViewModel`
- **Tracking Issue**: [GitHub Issue #105](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟠 Important
*   **Location**: [tables_view_model.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/view_models/tables_view_model.dart#L249)
*   **Issue**: The properties change listener does a `_tabs.firstWhere((t) => t.id == _selectedTabId)`. If `_selectedTabId` is null or does not match any tab in `_tabs`, this throws a `StateError` inside the stream listener and stops execution.
*   **Suggestion**: Use a safe lookup or `firstWhere` with `orElse` or check if the list contains the element first.
*   **Example**:
    ```dart
    final tabIndex = _tabs.indexWhere((t) => t.id == _selectedTabId);
    if (tabIndex != -1) {
      _loadData(_tabs[tabIndex], _requestId);
    }
    ```

### 🟠 Multi-Tab Rendering and Keeping Alive Bug in `TabbedContainer`
- **Tracking Issue**: [GitHub Issue #106](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟠 Important
*   **Location**: [tabbed_container.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/tabbed_container.dart#L130-L137)
*   **Issue**: `TabBarView` keeps all tabs alive in the widget tree using `LazyTab` and `wantKeepAlive => true`. However, `TablesViewModel` only holds a single active table dataset (`rows` and `headers`) for the active tab. Consequently, every tab kept alive in the tree will render the exact same active tab's data. During transitions, the user will see wrong data in the adjacent tab until the swipe finishes and `selectTab` updates the view model.
*   **Suggestion**: Either disable keeping tabs alive, or pass the selected data explicitly to each table view widget instead of sharing a single active table state.

---

## 2. Performance

### 🟠 GlobalKey Allocation Performance Issue in `TreeViewModel`
- **Tracking Issue**: [GitHub Issue #107](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟠 Important
*   **Location**: [tree_view_model.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tree/view_models/tree_view_model.dart#L267)
*   **Issue**: On every `loadTree` or child node expansion, `_buildNodeKeys` is called and executes `_nodeKeys[node.id] = GlobalKey();`. Creating brand new `GlobalKey` instances on every update forces Flutter to tear down the entire widget tree for the nodes (breaking animations, focus states, and causing jank).
*   **Suggestion**: Reuse the existing `GlobalKey` if it has already been created for that node ID.
*   **Example**:
    ```dart
    void _buildNodeKeys(List<TreeNode> nodes) {
      for (final node in nodes) {
        _nodeKeys[node.id] ??= GlobalKey(); // Fix: Reuse key to preserve state
        if (node.children != null) {
          _buildNodeKeys(node.children!);
        }
      }
    }
    ```

### 🟡 Date Parsing inside Cell Build Method
- **Tracking Issue**: [GitHub Issue #108](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟡 Suggestion
*   **Location**: [table_view_widget.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/table_view_widget.dart#L406)
*   **Issue**: `_formatDate` runs `DateTime.parse` during widget build for every cell of type 'date'. Since date parsing is relatively heavy, executing this during scroll in the `itemBuilder` can cause frame drops (jank).
*   **Suggestion**: Pre-format dates in the view model or data parser, or cache formatted dates.

### 💡 Redundant Repaint Boundaries in `TableViewWidget`
- **Tracking Issue**: [GitHub Issue #109](docs/reviews/review_theme_panels.md)
*   **Severity**: 💡 Nitpick
*   **Location**: [table_view_widget.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/table_view_widget.dart#L124) and [line 305](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/table_view_widget.dart#L305)
*   **Issue**: Nesting `RepaintBoundary` nodes (one around the scrollable `ListView.builder` and another around every row item `_DataRow`) is redundant. This creates unnecessary engine layers and increases memory consumption.
*   **Suggestion**: Keep a single `RepaintBoundary` on the `ListView` scroll viewport and remove it from individual rows.

---

## 3. Quality (Aesthetics, Accessibility, and UX)

### 🟠 Accessible Tap Target Size violation on Tree Node Toggle
- **Tracking Issue**: [GitHub Issue #110](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟠 Important
*   **Location**: [tree_node_widget.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tree/tree_node_widget.dart#L104-L116)
*   **Issue**: The expand/collapse text button (`+`/`−`) has a tiny hit target (`Padding(all: 2.0)` around a single character). According to Material Design guidelines, interactive elements must have a minimum size of 48x48 logical pixels to ensure ease of tapping.
*   **Suggestion**: Increase the toggle padding or use a standard icon button (e.g., `IconButton` with a chevron) to ensure an accessible tap target.
*   **Example**:
    ```dart
    IconButton(
      key: Key('toggle_${node.id}'),
      icon: Icon(isExpanded ? Icons.expand_more : Icons.navigate_next, size: 18),
      onPressed: () {
        context.read<TreeViewModel>().toggleExpand(node.id);
      },
    )
    ```

### 🟠 Broken Swipe Animation in `TabbedContainer`
- **Tracking Issue**: [GitHub Issue #111](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟠 Important
*   **Location**: [tabbed_container.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tables/tabbed_container.dart#L169)
*   **Issue**: `LazyTab` wraps the tab child in `Offstage(offstage: !widget.isSelected)`. Since `TabBarView` performs smooth scroll translation transitions between adjacent tabs, hiding the adjacent tab during transition renders it blank/invisible. This breaks the premium visual swipe transition entirely.
*   **Suggestion**: Remove `Offstage` and allow `TabBarView` to handle transition rendering naturally.
*   **Example**:
    ```dart
    @override
    Widget build(BuildContext context) {
      super.build(context);
      return widget.child; // Let TabBarView do transition rendering
    }
    ```

### 🟡 Keyboard Holding (Key Repeat) Ignored in `SidebarTree`
- **Tracking Issue**: [GitHub Issue #112](docs/reviews/review_theme_panels.md)
*   **Severity**: 🟡 Suggestion
*   **Location**: [sidebar_tree.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tree/sidebar_tree.dart#L87)
*   **Issue**: Tree navigation only responds to `KeyDownEvent`. If the user holds down the Up or Down arrow key, the tree will not scroll continuously because `KeyRepeatEvent` is ignored.
*   **Suggestion**: Handle both `KeyDownEvent` and `KeyRepeatEvent` to support continuous keyboard navigation.
*   **Example**:
    ```dart
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Navigation logic
    }
    ```

---

## 4. Architecture

### 💡 Duplicate Natural Sorting Implementation
*   **Severity**: 💡 Nitpick
*   **Location**: [tree_view_model.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/tree/view_models/tree_view_model.dart#L355) and [property_grid.dart](file:///Users/perkunas/jail/3dgs-002/app_flutter/lib/features/properties/property_grid.dart#L807)
*   **Issue**: Natural sorting logic using regular expressions and chunk parsing is duplicated across two files. This violates the DRY (Don't Repeat Yourself) principle.
*   **Suggestion**: Extract natural comparison logic into a shared utility function.
*   **Example**: Move `_naturalCompare` to a helper class under `core/utils/string_utils.dart`.
