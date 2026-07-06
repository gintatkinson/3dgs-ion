import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/features/layout/breadcrumbs.dart';

void main() {
  testWidgets('Renders all items when total count <= maxItems', (WidgetTester tester) async {
    final List<String> clickedIds = <String>[];

    final List<BreadcrumbItem> items = <BreadcrumbItem>[
      BreadcrumbItem(id: 'root', label: 'Root', onClick: () => clickedIds.add('root')),
      BreadcrumbItem(id: 'level1', label: 'Level 1', onClick: () => clickedIds.add('level1')),
      BreadcrumbItem(id: 'level2', label: 'Level 2', onClick: () => clickedIds.add('level2')),
    ];

    await tester.pumpWidget(
      MaterialApp(
          home: Scaffold(
            body: NavigationBreadcrumbs(items: items, maxItems: 4),
          ),
      ),
    );

    // Verify all item labels and separators are shown
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('/'), findsNWidgets(2));
    expect(find.text('...'), findsNothing);

    // Tap Root and check callback
    await tester.tap(find.text('Root'));
    await tester.pumpAndSettle();
    expect(clickedIds, contains('root'));

    // Verify Level 2 (last item) uses bodyMedium style from theme
    final Text textWidget = tester.widget<Text>(find.text('Level 2'));
    expect(textWidget.style?.fontWeight, FontWeight.w400);
  });

  testWidgets('Collapses middle items when total count > maxItems and expands on ellipsis click', (WidgetTester tester) async {
    final List<String> clickedIds = <String>[];

    final List<BreadcrumbItem> items = <BreadcrumbItem>[
      BreadcrumbItem(id: 'root', label: 'Root', onClick: () => clickedIds.add('root')),
      BreadcrumbItem(id: 'level1', label: 'Level 1', onClick: () => clickedIds.add('level1')),
      BreadcrumbItem(id: 'level2', label: 'Level 2', onClick: () => clickedIds.add('level2')),
      BreadcrumbItem(id: 'level3', label: 'Level 3', onClick: () => clickedIds.add('level3')),
      BreadcrumbItem(id: 'level4', label: 'Level 4', onClick: () => clickedIds.add('level4')),
    ];

    await tester.pumpWidget(
      MaterialApp(
          home: Scaffold(
            body: NavigationBreadcrumbs(items: items, maxItems: 3),
          ),
      ),
    );

    // With maxItems = 3:
    // first item is 'Root'
    // last items (maxItems - 1 = 2 items): 'Level 3', 'Level 4'
    // rendered: Root -> ... -> Level 3 -> Level 4
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('...'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('Level 4'), findsOneWidget);

    // Collapsed items ('Level 1', 'Level 2') are hidden
    expect(find.text('Level 1'), findsNothing);
    expect(find.text('Level 2'), findsNothing);

    // Click on ellipsis to expand
    await tester.tap(find.text('...'));
    await tester.pumpAndSettle();

    // Verify all items are now visible
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('Level 2'), findsOneWidget);
    expect(find.text('Level 3'), findsOneWidget);
    expect(find.text('Level 4'), findsOneWidget);
    expect(find.text('...'), findsNothing);
  });

  testWidgets('Wraps children in a horizontal SingleChildScrollView', (WidgetTester tester) async {
    final List<BreadcrumbItem> items = <BreadcrumbItem>[
      const BreadcrumbItem(id: 'root', label: 'Root'),
      const BreadcrumbItem(id: 'sub', label: 'Sub'),
    ];

    await tester.pumpWidget(
      MaterialApp(
          home: Scaffold(
            body: NavigationBreadcrumbs(items: items),
          ),
      ),
    );

    // Verify SingleChildScrollView is present and handles horizontal scrolling
    final Finder scrollViewFinder = find.byType(SingleChildScrollView);
    expect(scrollViewFinder, findsOneWidget);
    
    final SingleChildScrollView scrollView = tester.widget<SingleChildScrollView>(scrollViewFinder);
    expect(scrollView.scrollDirection, Axis.horizontal);
  });

  test('getBreadcrumbsItems onClick handles empty treeData safely', () {
    bool selected = false;
    final items = getBreadcrumbsItems(
      'someView',
      [],
      onSelectView: (view) => selected = true,
    );
    expect(items.length, 2);
    expect(items.first.id, 'home');
    expect(items.first.onClick, isNotNull);
    
    // Invoke onClick and ensure it doesn't throw StateError
    expect(() => items.first.onClick!(), returnsNormally);
    expect(selected, isFalse);
  });
}
