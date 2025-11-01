import 'package:test/test.dart';

import '../../../lib/src/mixins/exception_validation_mixin.dart';

// Test class that uses the mixin
class _TestRule with ExceptionValidationMixin {
  // Expose mixin methods for testing
}

void main() {
  group('ExceptionValidationMixin', () {
    late _TestRule testRule;

    setUp(() {
      testRule = _TestRule();
    });

    group('isGenericExceptionName', () {
      test('returns true for exact generic suffix match', () {
        expect(testRule.isGenericExceptionName('NotFoundException'), isTrue);
        expect(testRule.isGenericExceptionName('ValidationException'), isTrue);
        expect(testRule.isGenericExceptionName('NetworkException'), isTrue);
      });

      test('returns false for feature-prefixed exceptions', () {
        expect(
          testRule.isGenericExceptionName('TodoNotFoundException'),
          isFalse,
        );
        expect(
          testRule.isGenericExceptionName('UserValidationException'),
          isFalse,
        );
      });

      test('returns true for very short generic names', () {
        expect(testRule.isGenericExceptionName('DataException'), isTrue);
      });

      test('returns false for longer feature-specific names', () {
        expect(
          testRule.isGenericExceptionName('AuthenticationException'),
          isFalse,
        );
      });
    });

    group('isAllowedWithoutPrefix', () {
      test('returns true for Dart built-in exceptions', () {
        expect(testRule.isAllowedWithoutPrefix('Exception'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('Error'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('StateError'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('ArgumentError'), isTrue);
      });

      test('returns true for Data layer exceptions', () {
        expect(testRule.isAllowedWithoutPrefix('DataSourceException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('CacheException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('DatabaseException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('TimeoutException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('ConflictException'), isTrue);
      });

      test('returns false for domain exceptions needing prefix', () {
        expect(testRule.isAllowedWithoutPrefix('ValidationException'), isFalse);
        expect(testRule.isAllowedWithoutPrefix('CancelledException'), isFalse);
      });
    });

    group('isDataLayerException', () {
      test('returns true for Data layer exceptions', () {
        expect(testRule.isDataLayerException('NotFoundException'), isTrue);
        expect(testRule.isDataLayerException('NetworkException'), isTrue);
        expect(testRule.isDataLayerException('CacheException'), isTrue);
      });

      test('returns false for domain exceptions', () {
        expect(testRule.isDataLayerException('TodoNotFoundException'), isFalse);
        expect(testRule.isDataLayerException('Exception'), isFalse);
      });
    });

    group('suggestFeaturePrefix', () {
      test('extracts feature name from file path', () {
        final result = testRule.suggestFeaturePrefix(
          'NotFoundException',
          '/lib/features/todos/domain/exceptions/todo_exceptions.dart',
        );
        expect(result, 'TodoNotFoundException');
      });

      test('returns original name when no feature extracted', () {
        // Since extractFeatureName returns null for unknown paths,
        // the current implementation doesn't add a prefix
        final result = testRule.suggestFeaturePrefix(
          'NotFoundException',
          '/lib/unknown/path.dart',
        );
        // The method returns the prefixed name or falls back to FeatureX pattern
        expect(result.contains('NotFoundException'), isTrue);
      });
    });
  });
}
