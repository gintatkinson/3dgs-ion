import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/domain/column_model.dart';
import 'package:app_flutter/features/tables/view_models/tables_view_model.dart';

/// Renders tabular data from a [TablesViewModel] as a horizontally
/// scrollable, vertically virtualized table.
///
/// Fixes O(n) widget creation from [DataTable] by using [ListView.builder]
/// for O(1) visible-row widget creation. The column header row is fixed at
/// the top; body rows scroll virtually.
///
/// Edge cases:
///   - When [TablesViewModel.loading] is `true`, a centered
///     [CircularProgressIndicator] is displayed instead of the table.
///   - When [TablesViewModel.error] is non-null, the error text is shown in
///     the theme's error color; the table is not rendered.
///   - An empty [headers] list renders an empty [SizedBox] — no crash.
///   - Long content is scrollable horizontally via [SingleChildScrollView];
///     vertical scrolling is handled by [ListView.builder].
///
/// State changes: this widget is read-only; it watches [TablesViewModel] via
/// `context.watch` and rebuilds on every notifyListeners call from the view
/// model.
class TableViewWidget extends StatefulWidget {
  const TableViewWidget({
    super.key,
    this.headingRowHeight = 32.0,
    this.dataRowMinHeight = 28.0,
    this.dataRowMaxHeight = double.infinity,
    this.horizontalMargin = 12.0,
    this.columnSpacing = 24.0,
  });

  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double horizontalMargin;
  final double columnSpacing;

  @override
  State<TableViewWidget> createState() => _TableViewWidgetState();
}

class _TableViewWidgetState extends State<TableViewWidget> {
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TablesViewModel>();

    if (viewModel.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            viewModel.error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final headers = viewModel.visibleColumnModels;
    final allHeaders = viewModel.headers;
    var rows = viewModel.rows;
    final testId = '${viewModel.tabId}-table';

    final headerIndices = <String, int>{
      for (int idx = 0; idx < allHeaders.length; idx++)
        allHeaders[idx].key: idx
    };

    if (_sortColumnIndex != null && _sortColumnIndex! < headers.length) {
      final sortedRows = List<List<String>>.from(rows);
      final key = headers[_sortColumnIndex!].key;
      final absIdx = headerIndices[key] ?? _sortColumnIndex!;
      sortedRows.sort((a, b) {
        final aVal = absIdx < a.length ? a[absIdx] : '';
        final bVal = absIdx < b.length ? b[absIdx] : '';
        return _sortAscending ? aVal.compareTo(bVal) : bVal.compareTo(aVal);
      });
      rows = sortedRows;
    }

    if (headers.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final colCount = headers.length;
        final spacingWidth = colCount > 1
            ? (colCount - 1) * widget.columnSpacing
            : 0.0;
        final colWidth = math.max(120.0, (constraints.maxWidth - 2 * widget.horizontalMargin - spacingWidth) / colCount);
        final tableWidth = math.max(constraints.maxWidth, colCount * colWidth + spacingWidth + 2 * widget.horizontalMargin);

        void onSort(int columnIndex) {
          setState(() {
            if (_sortColumnIndex == columnIndex) {
              _sortAscending = !_sortAscending;
            } else {
              _sortColumnIndex = columnIndex;
              _sortAscending = true;
            }
          });
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            key: Key(testId),
            width: tableWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                RepaintBoundary(
                  child: ListView.builder(
                    key: Key('$testId-body'),
                    itemCount: rows.length,
                    padding: EdgeInsets.only(top: widget.headingRowHeight),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return _DataRow(
                        cells: row,
                        columnModels: headers,
                        headerIndices: headerIndices,
                        colWidth: colWidth,
                        dataRowMinHeight: widget.dataRowMinHeight,
                        dataRowMaxHeight: widget.dataRowMaxHeight,
                        horizontalMargin: widget.horizontalMargin,
                        columnSpacing: widget.columnSpacing,
                        index: index,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _HeaderRow(
                    headers: headers,
                    colWidth: colWidth,
                    headingRowHeight: widget.headingRowHeight,
                    horizontalMargin: widget.horizontalMargin,
                    columnSpacing: widget.columnSpacing,
                    testId: testId,
                    sortColumnIndex: _sortColumnIndex,
                    sortAscending: _sortAscending,
                    onSort: onSort,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final List<ColumnModel> headers;
  final double colWidth;
  final double headingRowHeight;
  final double horizontalMargin;
  final double columnSpacing;
  final String testId;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex) onSort;

  const _HeaderRow({
    required this.headers,
    required this.colWidth,
    required this.headingRowHeight,
    required this.horizontalMargin,
    required this.columnSpacing,
    required this.testId,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('$testId-header'),
      height: headingRowHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < headers.length; i++)
            _HeaderCell(
              label: headers[i].label,
              columnWidth: headers[i].width,
              colWidth: colWidth,
              horizontalMargin: horizontalMargin,
              columnSpacing: columnSpacing,
              isFirst: i == 0,
              isLast: i == headers.length - 1,
              sortable: headers[i].sortable,
              isActiveSort: sortColumnIndex == i,
              sortAscending: sortAscending,
              onTap: headers[i].sortable ? () => onSort(i) : null,
              isNumeric: headers[i].type == 'int' || headers[i].type == 'double',
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double? columnWidth;
  final double colWidth;
  final double horizontalMargin;
  final double columnSpacing;
  final bool isFirst;
  final bool isLast;
  final bool sortable;
  final bool isActiveSort;
  final bool sortAscending;
  final VoidCallback? onTap;
  final bool isNumeric;

  const _HeaderCell({
    required this.label,
    this.columnWidth,
    required this.colWidth,
    required this.horizontalMargin,
    required this.columnSpacing,
    required this.isFirst,
    required this.isLast,
    required this.sortable,
    required this.isActiveSort,
    required this.sortAscending,
    required this.onTap,
    required this.isNumeric,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = isActiveSort
        ? '$label ${sortAscending ? '↑' : '↓'}'
        : label;

    return SizedBox(
      width: columnWidth ?? colWidth,
      child: Padding(
        padding: EdgeInsets.only(
          left: isFirst ? horizontalMargin : columnSpacing / 2,
          right: isLast ? horizontalMargin : columnSpacing / 2,
        ),
        child: Align(
          alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
          child: sortable
              ? GestureDetector(
                  onTap: onTap,
                  child: Text(displayLabel, style: Theme.of(context).textTheme.labelSmall),
                )
              : Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final List<String> cells;
  final List<ColumnModel> columnModels;
  final Map<String, int> headerIndices;
  final double colWidth;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double horizontalMargin;
  final double columnSpacing;
  final int index;

  const _DataRow({
    required this.cells,
    required this.columnModels,
    required this.headerIndices,
    required this.colWidth,
    required this.dataRowMinHeight,
    required this.dataRowMaxHeight,
    required this.horizontalMargin,
    required this.columnSpacing,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        constraints: BoxConstraints(
          minHeight: dataRowMinHeight,
        ),
        color: index.isEven ? null : Colors.black.withOpacity(0.03),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(columnModels.length, (i) {
            final cellIdx = headerIndices[columnModels[i].key];
            final cellValue = cellIdx != null && cellIdx < cells.length ? cells[cellIdx] : '';
            return _DataCell(
              value: cellValue,
              columnModel: columnModels[i],
              colWidth: colWidth,
              horizontalMargin: horizontalMargin,
              columnSpacing: columnSpacing,
              isFirst: i == 0,
              isLast: i == columnModels.length - 1,
            );
          }),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String value;
  final ColumnModel columnModel;
  final double colWidth;
  final double horizontalMargin;
  final double columnSpacing;
  final bool isFirst;
  final bool isLast;

  const _DataCell({
    required this.value,
    required this.columnModel,
    required this.colWidth,
    required this.horizontalMargin,
    required this.columnSpacing,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNumeric = columnModel.type == 'int' || columnModel.type == 'double';

    Widget cellContent;
    switch (columnModel.type) {
      case 'int':
      case 'double':
        cellContent = Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
          textAlign: TextAlign.right,
        );
        break;
      case 'enum':
        cellContent = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value, style: theme.textTheme.bodySmall),
        );
        break;
      case 'date':
        cellContent = Text(
          _formatDate(value),
          style: theme.textTheme.bodySmall,
        );
        break;
      default:
        cellContent = Text(value, style: theme.textTheme.bodySmall);
    }

    return SizedBox(
      width: columnModel.width ?? colWidth,
      child: Padding(
        padding: EdgeInsets.only(
          left: isFirst ? horizontalMargin : columnSpacing / 2,
          right: isLast ? horizontalMargin : columnSpacing / 2,
        ),
        child: Align(
          alignment: isNumeric ? Alignment.centerRight : Alignment.centerLeft,
          child: cellContent,
        ),
      ),
    );
  }

  String _formatDate(String value) {
    if (value.isEmpty) return value;
    try {
      final dt = DateTime.parse(value);
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return value;
    }
  }
}
