import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, dynamic>? args]) async {
      final String screenshotDir = Platform.environment['SCREENSHOT_DIR'] ?? Directory.current.path;
      final file = File('$screenshotDir/\$name.png');
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
