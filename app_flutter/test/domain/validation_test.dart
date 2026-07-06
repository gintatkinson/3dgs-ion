import 'package:app_flutter/domain/validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeFrameName', () {
    test('trims whitespace', () {
      expect(sanitizeFrameName('  mars  '), 'MARS');
    });

    test('uppercases the name', () {
      expect(sanitizeFrameName('mars'), 'MARS');
      expect(sanitizeFrameName('Moon'), 'MOON');
    });

    test('strips the- prefix case-insensitively', () {
      expect(sanitizeFrameName('the-mars'), 'MARS');
      expect(sanitizeFrameName('THE-MARS'), 'MARS');
      expect(sanitizeFrameName('The-Mars'), 'MARS');
    });

    test('does not strip non-prefix the-', () {
      expect(sanitizeFrameName('MARS-THE'), 'MARS-THE');
    });

    test('strips the- and then uppercases', () {
      expect(sanitizeFrameName('  the-moon  '), 'MOON');
    });

    test('handles empty string', () {
      expect(sanitizeFrameName(''), '');
    });

    test('strips ASCII control characters', () {
      expect(sanitizeFrameName('test\x00name'), 'TESTNAME');
      expect(sanitizeFrameName('test\nname'), 'TESTNAME');
      expect(sanitizeFrameName('test\tname'), 'TESTNAME');
      expect(sanitizeFrameName('test\x0bname'), 'TESTNAME');
      expect(sanitizeFrameName('test\x7fname'), 'TESTNAME');
    });
  });

  group('validateReferenceFrame', () {
    test('empty frame passes', () {
      final frame = <String, dynamic>{};
      final result = validateReferenceFrame(frame);
      expect(result.isValid, isTrue);
    });

    group('feature gate accept', () {
      test('alternateSystem set with alternateSystemEnabled true passes', () {
        final frame = <String, dynamic>{'alternateSystem': 'IAU'};
        final result = validateReferenceFrame(frame, alternateSystemEnabled: true);
        expect(result.isValid, isTrue);
      });
    });

    group('feature gate reject', () {
      test('alternateSystem set with alternateSystemEnabled false fails', () {
        final frame = <String, dynamic>{'alternateSystem': 'IAU'};
        final result = validateReferenceFrame(frame, alternateSystemEnabled: false);
        expect(result.isValid, isFalse);
      });

      test('alternateSystem set with alternateSystemEnabled default (false) fails', () {
        final frame = <String, dynamic>{'alternateSystem': 'IAU'};
        final result = validateReferenceFrame(frame);
        expect(result.isValid, isFalse);
      });
    });

    group('control characters rejected', () {
      test('null byte in frameName fails', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'test\x00name');
        expect(result.isValid, isFalse);
      });

      test('newline in frameName fails', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'test\nname');
        expect(result.isValid, isFalse);
      });

      test('tab in frameName fails', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'test\tname');
        expect(result.isValid, isFalse);
      });

      test('DEL character (0x7f) in frameName fails', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'test\x7fname');
        expect(result.isValid, isFalse);
      });

      test('control character check precedes feature gate check', () {
        final frame = <String, dynamic>{'alternateSystem': 'IAU'};
        final result = validateReferenceFrame(
          frame,
          frameName: 'test\x00name',
          alternateSystemEnabled: true,
        );
        expect(result.isValid, isFalse);
      });
    });

    group('uppercase normalized', () {
      test('frameName is uppercased in sanitizedFrameName', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'mars');
        expect(result.sanitizedFrameName, 'MARS');
      });

      test('mixed case frameName is uppercased', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'MarsMoon');
        expect(result.sanitizedFrameName, 'MARSMOON');
      });
    });

    group('the- prefix stripped', () {
      test('leading the- stripped case-insensitively', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'the-mars');
        expect(result.sanitizedFrameName, 'MARS');
      });

      test('leading THE- stripped', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: 'THE-MARS');
        expect(result.sanitizedFrameName, 'MARS');
      });

      test('the- stripping happens before uppercasing', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame, frameName: '  the-moon  ');
        expect(result.sanitizedFrameName, 'MOON');
      });
    });

    group('sanitizedFrame passed through', () {
      test('sanitizedFrame is the same reference', () {
        final frame = <String, dynamic>{'alternateSystem': 'IAU'};
        final result = validateReferenceFrame(frame);
        expect(result.sanitizedFrame, same(frame));
      });
    });

    group('edge cases', () {
      test('frameName is null, result has empty sanitizedFrameName', () {
        final frame = <String, dynamic>{};
        final result = validateReferenceFrame(frame);
        expect(result.sanitizedFrameName, '');
      });

      test('no alternateSystem passes regardless of gate', () {
        final frame = <String, dynamic>{};
        final resultEnabled = validateReferenceFrame(frame, alternateSystemEnabled: true);
        final resultDisabled = validateReferenceFrame(frame, alternateSystemEnabled: false);
        expect(resultEnabled.isValid, isTrue);
        expect(resultDisabled.isValid, isTrue);
      });
    });
  });
}
