import 'dart:convert';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:app_flutter/domain/database_initializer.dart';
import 'package:app_flutter/features/topology/scene_3d_viewport.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Visual Globe rotation: Ctrl+drag shifts visual projected points on screen', (WidgetTester tester) async {
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

    expect(find.byKey(const Key('node_Master_1')), findsOneWidget, reason: 'Sidebar tree should contain Master_1');

    // Ensure 3D globe is active
    final toggle3dButton = find.byKey(const Key('toggle_3d'));
    if (toggle3dButton.evaluate().isNotEmpty) {
      await tester.ensureVisible(toggle3dButton);
      await tester.tap(toggle3dButton);
      await settle(tester);
    }

    expect(find.byType(Scene3DViewport), findsOneWidget, reason: '3D viewport should be mounted');
    await settle(tester);

    final state = tester.state(find.byType(Scene3DViewport)) as Scene3DViewportState;

    // 3. Capture initial projected position of a reference coordinate
    final Offset initialOffset = state.getProjectedPosition(35.607400, 140.106300);
    final double initialHeading = state.cameraController.current.heading;

    // 4. Perform Ctrl + Drag to rotate heading (yaw)
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final viewport = find.byKey(const Key('scene_3d_viewport_container'));
    await tester.drag(viewport, const Offset(-150.0, 0.0));
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    // 5. Capture new projected position of same coordinate
    final Offset newOffset = state.getProjectedPosition(35.607400, 140.106300);
    final double newHeading = state.cameraController.current.heading;

    // 6. Assert camera heading parameter and visual movement have occurred
    expect(
      newHeading,
      isNot(equals(initialHeading)),
      reason: 'Camera heading did not change during rotation gesture'
    );
    expect(
      newOffset, 
      isNot(equals(initialOffset)),
      reason: 'Expected 2D projected screen coordinates to rotate when camera heading changes'
    );

    // Keep the application GUI active and pump frames to the macOS display for 1 second
    for (int i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  });
}
