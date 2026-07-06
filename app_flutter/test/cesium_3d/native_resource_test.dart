import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/domain/cesium_3d/native/native_resource.dart';

void main() {
  group('NativeResource Tests', () {
    test('release marks as released and frees only once', () {
      final resource = NativeResource.alloc(10, 1);
      expect(resource.isReleased, isFalse);

      // First release should succeed and set isReleased to true
      resource.release();
      expect(resource.isReleased, isTrue);

      // Second release should be a no-op and not throw/double free
      expect(() => resource.release(), returnsNormally);
      expect(resource.isReleased, isTrue);
    });
  });
}
