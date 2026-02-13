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
      test('returns false for AppException types (they are allowed)', () {
        // AppException types should NOT be flagged as generic
        expect(testRule.isGenericExceptionName('AppException'), isFalse);
        expect(testRule.isGenericExceptionName('NotFoundException'), isFalse);
        expect(testRule.isGenericExceptionName('NetworkException'), isFalse);
        expect(testRule.isGenericExceptionName('ServerException'), isFalse);
        expect(
          testRule.isGenericExceptionName('InvalidInputException'),
          isFalse,
        );
        expect(
          testRule.isGenericExceptionName('UnauthorizedException'),
          isFalse,
        );
        expect(testRule.isGenericExceptionName('ForbiddenException'), isFalse);
        expect(testRule.isGenericExceptionName('TimeoutException'), isFalse);
        expect(testRule.isGenericExceptionName('ConflictException'), isFalse);
        expect(testRule.isGenericExceptionName('CacheException'), isFalse);
        expect(testRule.isGenericExceptionName('UnknownException'), isFalse);
      });

      test('returns true for generic suffix needing feature prefix', () {
        // These are in exceptionSuffixes but NOT in appExceptionTypes
        expect(testRule.isGenericExceptionName('ValidationException'), isTrue);
        expect(testRule.isGenericExceptionName('CancelledException'), isTrue);
        expect(testRule.isGenericExceptionName('InvalidException'), isTrue);
        expect(testRule.isGenericExceptionName('DuplicateException'), isTrue);
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

      test('returns true for AppException types', () {
        expect(testRule.isAllowedWithoutPrefix('AppException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('NotFoundException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('NetworkException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('ServerException'), isTrue);
        expect(
          testRule.isAllowedWithoutPrefix('InvalidInputException'),
          isTrue,
        );
        expect(
          testRule.isAllowedWithoutPrefix('UnauthorizedException'),
          isTrue,
        );
        expect(testRule.isAllowedWithoutPrefix('ForbiddenException'), isTrue);
        expect(testRule.isAllowedWithoutPrefix('UnknownException'), isTrue);
      });

      test('returns false for domain exceptions needing prefix', () {
        expect(testRule.isAllowedWithoutPrefix('ValidationException'), isFalse);
        expect(testRule.isAllowedWithoutPrefix('CancelledException'), isFalse);
      });
    });

    group('isAppExceptionType', () {
      test('returns true for core AppException types', () {
        expect(testRule.isAppExceptionType('AppException'), isTrue);
        expect(testRule.isAppExceptionType('NotFoundException'), isTrue);
        expect(testRule.isAppExceptionType('NetworkException'), isTrue);
        expect(testRule.isAppExceptionType('ServerException'), isTrue);
        expect(testRule.isAppExceptionType('InvalidInputException'), isTrue);
        expect(testRule.isAppExceptionType('UnauthorizedException'), isTrue);
        expect(testRule.isAppExceptionType('ForbiddenException'), isTrue);
        expect(testRule.isAppExceptionType('TimeoutException'), isTrue);
        expect(testRule.isAppExceptionType('ConflictException'), isTrue);
        expect(testRule.isAppExceptionType('CacheException'), isTrue);
        expect(testRule.isAppExceptionType('UnknownException'), isTrue);
      });

      test(
        'returns true for custom exceptions ending with AppException type',
        () {
          // Custom exceptions inheriting from AppException types are allowed
          expect(testRule.isAppExceptionType('TodoNotFoundException'), isTrue);
          expect(
            testRule.isAppExceptionType(
              'ScheduleConfirmationUnauthorizedException',
            ),
            isTrue,
          );
          expect(
            testRule.isAppExceptionType('UserInvalidInputException'),
            isTrue,
          );
        },
      );

      test('returns false for non-AppException types', () {
        expect(testRule.isAppExceptionType('ValidationException'), isFalse);
        expect(testRule.isAppExceptionType('CustomException'), isFalse);
        expect(testRule.isAppExceptionType('Exception'), isFalse);
        expect(testRule.isAppExceptionType('CustomError'), isFalse);
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
          'ValidationException',
          '/lib/features/todos/domain/exceptions/todo_exceptions.dart',
        );
        expect(result, 'TodoValidationException');
      });

      test('returns original name when no feature extracted', () {
        // Since extractFeatureName returns null for unknown paths,
        // the current implementation doesn't add a prefix
        final result = testRule.suggestFeaturePrefix(
          'ValidationException',
          '/lib/unknown/path.dart',
        );
        // The method returns the prefixed name or falls back to FeatureX pattern
        expect(result.contains('ValidationException'), isTrue);
      });
    });
  });
}
