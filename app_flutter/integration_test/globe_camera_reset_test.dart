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
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';
import 'package:app_flutter/domain/database_initializer.dart';

double _parseHudValue(String label, WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is Text && widget.data != null && widget.data!.startsWith(label),
  );
  if (finder.evaluate().isEmpty) {
    throw Exception('HUD label "$label" not found on screen');
  }
  final text = tester.widget<Text>(finder).data!;
  final parts = text.split(': ');
  if (parts.length < 2) {
    throw Exception('Could not parse "$label" value from HUD text: $text');
  }
  return double.parse(parts[1].split(' ')[0]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #50 — Camera resets on parent rebuild', () {
    testWidgets('Camera HUD values survive tree node tap (TreeViewModel notification)', (WidgetTester tester) async {
      tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() {
        tester.binding.setSurfaceSize(null);
      });

      await StringResources.load();

      final db = await DatabaseInitializer.create(dbPath: inMemoryDatabasePath, seed: true);
      addTearDown(() async {
        await db.close();
      });

      final dataSource = SqliteDataSource(db);

      final themeController = ThemeController(SharedPreferencesThemeService());
      await themeController.loadSettings();

      final textScalerController = TextScalerController();
      await textScalerController.load();

      app_main.globalThemeController = themeController;
      app_main.globalTextScalerController = textScalerController;

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

      int attempts = 0;
      while (attempts < 20 && find.byKey(const Key('node_Master_1')).evaluate().isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pump();
        attempts++;
      }

      expect(find.byKey(const Key('node_Master_1')), findsOneWidget,
          reason: 'Sidebar tree should contain Master_1');

      final toggle3dButton = find.byKey(const Key('toggle_3d'));
      if (toggle3dButton.evaluate().isNotEmpty) {
        await tester.ensureVisible(toggle3dButton);
        await tester.tap(toggle3dButton);
        await settle(tester);
      }

      expect(find.byType(Scene3DViewport), findsOneWidget,
          reason: '3D viewport should be mounted');

      await settle(tester);

      final initialLat = _parseHudValue('Latitude', tester);
      final initialLng = _parseHudValue('Longitude', tester);
      final initialAlt = _parseHudValue('Altitude', tester);

      expect(initialLat, isNotNull);
      expect(initialLng, isNotNull);
      expect(initialAlt, isNotNull);

      final master2Finder = find.byKey(const Key('node_Master_2'));
      await tester.ensureVisible(master2Finder);
      await tester.tap(master2Finder);
      await settle(tester);

      await settle(tester);

      final afterLat = _parseHudValue('Latitude', tester);
      final afterLng = _parseHudValue('Longitude', tester);
      final afterAlt = _parseHudValue('Altitude', tester);

      expect(afterLat, equals(initialLat),
          reason: 'Latitude should NOT change after tree node tap. '
              'Initial: $initialLat, After: $afterLat');
      expect(afterLng, equals(initialLng),
          reason: 'Longitude should NOT change after tree node tap. '
              'Initial: $initialLng, After: $afterLng');
      expect(afterAlt, equals(initialAlt),
          reason: 'Altitude should NOT change after tree node tap. '
              'Initial: $initialAlt, After: $afterAlt');
    });
  });
}
