import 'dart:convert';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_flutter/main.dart' as app_main;
import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart';
import 'package:app_flutter/core/theme/text_scaler.dart';
import 'package:app_flutter/core/string_resources.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/data_sources/sqlite_data_source.dart';
import 'package:app_flutter/domain/type_descriptor.dart';
import 'package:app_flutter/features/tree/tree_node.dart';
import 'package:app_flutter/features/tree/sidebar_tree.dart';
import 'package:app_flutter/features/tree/view_models/tree_view_model.dart';
import 'package:app_flutter/features/properties/view_models/properties_view_model.dart';
import 'package:app_flutter/features/properties/property_grid.dart';

import 'package:app_flutter/domain/database_initializer.dart';

int _naturalCompare(String a, String b) {
  final RegExp regExp = RegExp(r'(\d+)|(\D+)');
  final Iterable<Match> matchesA = regExp.allMatches(a);
  final Iterable<Match> matchesB = regExp.allMatches(b);
  
  final List<String> chunksA = matchesA.map((m) => m.group(0)!).toList();
  final List<String> chunksB = matchesB.map((m) => m.group(0)!).toList();
  
  final int minLen = chunksA.length < chunksB.length ? chunksA.length : chunksB.length;
  for (int i = 0; i < minLen; i++) {
    final String chunkA = chunksA[i];
    final String chunkB = chunksB[i];
    
    final bool isDigitA = RegExp(r'^\d+$').hasMatch(chunkA);
    final bool isDigitB = RegExp(r'^\d+$').hasMatch(chunkB);
    
    if (isDigitA && isDigitB) {
      final int valA = int.parse(chunkA);
      final int valB = int.parse(chunkB);
      final int cmp = valA.compareTo(valB);
      if (cmp != 0) return cmp;
    } else {
      final int cmp = chunkA.compareTo(chunkB);
      if (cmp != 0) return cmp;
    }
  }
  return chunksA.length.compareTo(chunksB.length);
}

// Helper to sort fields in the same way as PropertyGrid
List<FieldDescriptor> getSortedFields(List<FieldDescriptor> fields) {
  final groups = fields.map((f) => f.sectionLabel ?? 'Other').toSet().toList()..sort();
  final List<FieldDescriptor> sortedFields = [];
  for (final group in groups) {
    final groupFields = fields.where((f) => (f.sectionLabel ?? 'Other') == group).toList()
      ..sort((a, b) {
        final int cmp = a.sectionOrder.compareTo(b.sectionOrder);
        if (cmp != 0) return cmp;
        return _naturalCompare(a.key, b.key);
      });
    sortedFields.addAll(groupFields);
  }
  return sortedFields;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E integration test: SQLite, properties edits, tabs toggle, settings mode cycles', (WidgetTester tester) async {
    // Set up standard desktop window sizing for macOS (1280x800, pixel ratio 2.0)
    const double width = 1280;
    const double height = 800;
    const double pixelRatio = 2.0;
    tester.view.physicalSize = const Size(width * pixelRatio, height * pixelRatio);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Load strings
    await StringResources.load();

    // Create and seed test database
    final db = await DatabaseInitializer.create(dbPath: inMemoryDatabasePath, seed: true);
    addTearDown(() async {
      await db.close();
    });

    final dataSource = SqliteDataSource(db);

    final themeController = ThemeController(SharedPreferencesThemeService());
    await themeController.loadSettings();

    final textScalerController = TextScalerController();
    await textScalerController.load();

    // Hooks
    app_main.globalThemeController = themeController;
    app_main.globalTextScalerController = textScalerController;

    // Helper to settle frames without looping indefinitely on background animations
    Future<void> settle(WidgetTester t) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await t.pump();
      for (int i = 0; i < 50; i++) {
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    }

    // Boot application
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DataSource>.value(value: dataSource),
          ChangeNotifierProvider<ThemeController>.value(value: themeController),
          ChangeNotifierProvider<TextScalerController>.value(value: textScalerController),
        ],
        child: const MyApp(),
      ),
    );

    await settle(tester);

    // Wait for the tree view model to load
    int attempts = 0;
    while (attempts < 20 && find.byKey(const Key('node_Master_1')).evaluate().isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
      attempts++;
    }

    final treeViewModel = tester.element(find.byType(SidebarTree)).read<TreeViewModel>();

    // Define traversal function
    Future<void> traverseTreeAndProcess(TreeNode node, int loopIndex) async {
      final nodeId = node.id;
      final nodeTileFinder = find.byKey(Key('node_$nodeId'));

      await tester.ensureVisible(nodeTileFinder);
      await tester.tap(nodeTileFinder);
      await settle(tester);

      // Enter mock values in every text field
      final propertyGridWidget = tester.widget<PropertyGrid>(find.byType(PropertyGrid));
      final sortedFields = getSortedFields(propertyGridWidget.fields);
      final textFieldsList = sortedFields.where((f) => f.type != 'enum').take(3).toList();

      final Map<String, String> expectedValues = {};
      final textFieldsFinder = find.byType(TextField);

      for (int i = 0; i < textFieldsList.length; i++) {
        final field = textFieldsList[i];
        final newValue = 'New-${field.key}-$nodeId-loop$loopIndex';
        expectedValues[field.key] = newValue;

        await tester.enterText(textFieldsFinder.at(i), newValue);
        await tester.pump();
      }

      // Click the "Save" button
      final saveButtonFinder = find.byKey(const Key('save_properties_button'));
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await settle(tester);

      // Verify direct SQLite DB save mapping
      final dbResult = await db.query(
        'properties',
        where: 'node_id = ?',
        whereArgs: [nodeId],
      );
      expect(dbResult.isNotEmpty, isTrue, reason: 'Properties row for node $nodeId should exist in DB');
      final dataJson = dbResult.first['data_json'] as String;
      final dbData = jsonDecode(dataJson) as Map<String, dynamic>;

      for (final entry in expectedValues.entries) {
        expect(dbData[entry.key], equals(entry.value), reason: 'DB properties mapping mismatch for field ${entry.key}');
      }

      // Assert rendered correctly in the UI grid
      for (final val in expectedValues.values) {
        expect(find.text(val), findsAtLeast(1), reason: 'UI grid should display entered value: $val');
      }

      // Toggle relation tabs to ensure data is displayed
      final tabLabels = ['Detail A', 'Detail B', 'Detail C'];
      for (final label in tabLabels) {
        final tabFinder = find.descendant(
          of: find.byType(TabBar),
          matching: find.text(label),
        );
        if (tabFinder.evaluate().isNotEmpty) {
          await tester.tap(tabFinder);
          await tester.pumpAndSettle();

          // Verify that at least one row's cell value is rendered in the detail pane
          final cleanLabel = label.replaceAll(' ', '_');
          final expectedCellText = 'val_inst_${nodeId}_${cleanLabel}_1_field_1';
          expect(find.text(expectedCellText), findsOneWidget, 
                 reason: 'Detail table for $label should render seeded instance row containing: $expectedCellText');
        }
      }

      // Expand the node if it has children (is a parent) and is collapsed to reveal them
      if (node.children != null && treeViewModel.expanded[nodeId] != true) {
        treeViewModel.toggleExpand(nodeId);
        await settle(tester);
      }

      // Recurse children (limit to first child to avoid massive recursion)
      if (node.children != null) {
        int waitAttempts = 0;
        while (waitAttempts < 20 && (node.children == null || node.children!.isEmpty)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
          waitAttempts++;
        }

        if (node.children!.isNotEmpty) {
          final child = node.children!.first;
          final childKey = Key('node_${child.id}');
          
          waitAttempts = 0;
          while (waitAttempts < 20 && find.byKey(childKey).evaluate().isEmpty) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            await tester.pump();
            waitAttempts++;
          }
          
          await traverseTreeAndProcess(child, loopIndex);
        }
      }
    }

    // Repeat traversal 3 times
    for (int loopIndex = 0; loopIndex < 3; loopIndex++) {
      final rootNodes = treeViewModel.treeData.take(1).toList();
      for (final rootNode in rootNodes) {
        await traverseTreeAndProcess(rootNode, loopIndex);
      }

      // Once the last node is reached, change theme (light, dark, system) and layout density (text scale)
      if (loopIndex == 0) {
        await themeController.updateThemeMode(ThemeMode.light);
        textScalerController.setScale(1.2);
      } else if (loopIndex == 1) {
        await themeController.updateThemeMode(ThemeMode.dark);
        textScalerController.setScale(0.8);
      } else if (loopIndex == 2) {
        await themeController.updateThemeMode(ThemeMode.system);
        textScalerController.setScale(1.0);
      }
      await settle(tester);
    }
  });
}
