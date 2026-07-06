import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/core/app_config.dart';
import 'package:app_flutter/core/string_resources.dart';
import 'package:app_flutter/core/theme/theme_controller.dart';
import 'package:app_flutter/core/theme/theme_service.dart' show SharedPreferencesThemeService;
import 'package:app_flutter/core/theme/text_scaler.dart';
import 'package:app_flutter/domain/data_source.dart';
import 'package:app_flutter/domain/data_sources/sqlite_data_source.dart';
import 'package:app_flutter/domain/database_initializer.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  testWidgets('Dashboard console boots and renders main widgets successfully',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    StringResources.loadFromJson('{"sidebar.header": "Platform Console"}');
    await tester.runAsync(() async {
      final db = await DatabaseInitializer.create(
        dbPath: inMemoryDatabasePath,
        seed: true,
      );
      try {
        final themeController = ThemeController(SharedPreferencesThemeService());

        final textScaler = TextScalerController();
        await textScaler.load();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<DataSource>.value(value: SqliteDataSource(db)),
              ChangeNotifierProvider<ThemeController>.value(value: themeController),
              ChangeNotifierProvider<TextScalerController>.value(value: textScaler),
            ],
            child: MyApp(),
          ),
        );

        await tester.pump();
        for (int i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }

        expect(find.byType(MyApp), findsOneWidget);
        expect(find.byType(DashboardPage), findsOneWidget);
        expect(find.text(AppConfig.title), findsAtLeast(1));

        await tester.pumpWidget(Container());
        for (int i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      } finally {
        await db.close();
      }
    });
  });
}
