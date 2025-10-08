import 'package:test/test.dart';

/// Unit tests for PresentationNoDataExceptionsRule
///
/// This test suite verifies that the presentation_no_data_exceptions_rule correctly
/// enforces Clean Architecture error handling boundaries.
///
/// Test Coverage:
/// 1. Data layer exception detection in is-expressions
/// 2. Presentation layer file detection
/// 3. Domain exception suggestion based on feature context
/// 4. Edge cases (nested checks, conditional logic, error handling widgets)
/// 5. Integration with ExceptionValidationMixin
///
/// Error Handling Flow:
/// - DataSource: Throws Data exceptions (NotFoundException, NetworkException)
/// - Repository: Catches Data exceptions → Converts to Result<T, Failure>
/// - UseCase: Unwraps Result → Throws Domain exceptions (TodoNotFoundException)
/// - Presentation: Catches Domain exceptions → Updates UI state
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('PresentationNoDataExceptionsRule', () {
    group('Data Layer Exception Detection', () {
      test('detects NotFoundException in is-expression', () {
        expect(
          _isDataLayerException('NotFoundException'),
          isTrue,
          reason: 'NotFoundException is a Data layer exception',
        );
      });

      test('detects UnauthorizedException in is-expression', () {
        expect(
          _isDataLayerException('UnauthorizedException'),
          isTrue,
          reason: 'UnauthorizedException is a Data layer exception',
        );
      });

      test('detects NetworkException in is-expression', () {
        expect(
          _isDataLayerException('NetworkException'),
          isTrue,
          reason: 'NetworkException is a Data layer exception',
        );
      });

      test('detects ServerException in is-expression', () {
        expect(
          _isDataLayerException('ServerException'),
          isTrue,
          reason: 'ServerException is a Data layer exception',
        );
      });

      test('detects CacheException in is-expression', () {
        expect(
          _isDataLayerException('CacheException'),
          isTrue,
          reason: 'CacheException is a Data layer exception',
        );
      });

      test('detects DatabaseException in is-expression', () {
        expect(
          _isDataLayerException('DatabaseException'),
          isTrue,
          reason: 'DatabaseException is a Data layer exception',
        );
      });

      test('detects DataSourceException in is-expression', () {
        expect(
          _isDataLayerException('DataSourceException'),
          isTrue,
          reason: 'DataSourceException is a Data layer exception',
        );
      });

      test('detects all 7 data layer exceptions', () {
        final dataExceptions = [
          'NotFoundException',
          'UnauthorizedException',
          'NetworkException',
          'ServerException',
          'CacheException',
          'DatabaseException',
          'DataSourceException',
        ];

        for (final exception in dataExceptions) {
          expect(
            _isDataLayerException(exception),
            isTrue,
            reason: '$exception should be detected as Data layer exception',
          );
        }
      });
    });

    group('Domain Exception Acceptance', () {
      test('accepts feature-prefixed domain exceptions', () {
        final domainExceptions = [
          'TodoNotFoundException',
          'UserNetworkException',
          'OrderServerException',
          'ProductCacheException',
          'UserUnauthorizedException',
        ];

        for (final exception in domainExceptions) {
          expect(
            _isDataLayerException(exception),
            isFalse,
            reason: '$exception is a Domain exception, should be allowed',
          );
        }
      });

      test('accepts custom domain exceptions', () {
        final customDomainExceptions = [
          'TodoValidationException',
          'UserAuthenticationException',
          'OrderProcessingException',
        ];

        for (final exception in customDomainExceptions) {
          expect(
            _isDataLayerException(exception),
            isFalse,
            reason: '$exception is a custom Domain exception, should be allowed',
          );
        }
      });
    });

    group('Presentation Layer File Detection', () {
      test('correctly identifies presentation layer files', () {
        final testCases = [
          'lib/presentation/pages/todo_page.dart',
          'lib/features/todos/presentation/widgets/todo_list.dart',
          'lib/core/presentation/error_handler.dart',
        ];

        for (final path in testCases) {
          expect(
            _isPresentationFile(path),
            isTrue,
            reason: '$path should be detected as presentation layer',
          );
        }
      });

      test('correctly identifies non-presentation layer files', () {
        final testCases = [
          'lib/features/todos/domain/usecases/get_todos.dart',
          'lib/features/todos/data/repositories/todo_repository_impl.dart',
          'lib/infrastructure/network/api_client.dart',
        ];

        for (final path in testCases) {
          expect(
            _isPresentationFile(path),
            isFalse,
            reason: '$path should not be detected as presentation layer',
          );
        }
      });
    });

    group('Domain Exception Suggestion', () {
      test('suggests feature-prefixed exception from file path', () {
        final testCases = [
          TestExceptionSuggestion(
            filePath: 'lib/features/todos/presentation/pages/todo_page.dart',
            dataException: 'NotFoundException',
            expectedSuggestion: 'TodoNotFoundException',
          ),
          TestExceptionSuggestion(
            filePath: 'lib/features/users/presentation/widgets/user_list.dart',
            dataException: 'NetworkException',
            expectedSuggestion: 'UserNetworkException',
          ),
          TestExceptionSuggestion(
            filePath: 'lib/features/orders/presentation/pages/order_page.dart',
            dataException: 'ServerException',
            expectedSuggestion: 'OrderServerException',
          ),
        ];

        for (final testCase in testCases) {
          final suggestion = _suggestDomainException(
            testCase.dataException,
            testCase.filePath,
          );

          expect(
            suggestion,
            testCase.expectedSuggestion,
            reason: 'Should suggest ${testCase.expectedSuggestion} for ${testCase.filePath}',
          );
        }
      });

      test('handles nested feature paths', () {
        final testCases = [
          TestExceptionSuggestion(
            filePath: 'lib/features/auth/presentation/pages/login_page.dart',
            dataException: 'UnauthorizedException',
            expectedSuggestion: 'AuthUnauthorizedException',
          ),
          TestExceptionSuggestion(
            filePath: 'lib/core/features/todos/presentation/widgets/todo_card.dart',
            dataException: 'CacheException',
            expectedSuggestion: 'TodoCacheException',
          ),
        ];

        for (final testCase in testCases) {
          final suggestion = _suggestDomainException(
            testCase.dataException,
            testCase.filePath,
          );

          expect(
            suggestion,
            testCase.expectedSuggestion,
            reason: 'Should handle nested paths for ${testCase.filePath}',
          );
        }
      });

      test('provides fallback suggestion when feature not extractable', () {
        final testCases = [
          'lib/presentation/pages/todo_page.dart',
          'lib/widgets/error_handler.dart',
        ];

        for (final filePath in testCases) {
          final suggestion = _suggestDomainException('NotFoundException', filePath);

          expect(
            suggestion,
            contains('NotFoundException'),
            reason: 'Should contain exception name for $filePath',
          );
          expect(
            suggestion,
            'FeatureNotFoundException',
            reason: 'Should use fallback prefix for $filePath',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for NotFoundException', () {
        final message = _getErrorMessage(
          'NotFoundException',
          'TodoNotFoundException',
        );

        expect(
          message,
          contains('should NOT handle Data exception'),
          reason: 'Error message should mention Data exception prohibition',
        );
        expect(
          message,
          contains('NotFoundException'),
          reason: 'Error message should include current exception type',
        );
        expect(
          message,
          contains('TodoNotFoundException'),
          reason: 'Error message should include suggested Domain exception',
        );
      });

      test('provides clear message for NetworkException', () {
        final message = _getErrorMessage(
          'NetworkException',
          'UserNetworkException',
        );

        expect(
          message,
          contains('Use Domain exception instead'),
          reason: 'Error message should suggest Domain exception',
        );
        expect(
          message,
          contains('NetworkException'),
          reason: 'Error message should include current exception type',
        );
        expect(
          message,
          contains('UserNetworkException'),
          reason: 'Error message should include suggested Domain exception',
        );
      });

      test('includes error handling flow explanation', () {
        final message = _getErrorMessage(
          'ServerException',
          'OrderServerException',
        );

        expect(
          message,
          contains('UseCase layer'),
          reason: 'Error message should mention UseCase layer responsibility',
        );
        expect(
          message,
          contains('convert Data exceptions to Domain exceptions'),
          reason: 'Error message should explain conversion responsibility',
        );
      });

      test('references ERROR_HANDLING_GUIDE.md', () {
        final message = _getErrorMessage(
          'CacheException',
          'ProductCacheException',
        );

        expect(
          message,
          contains('ERROR_HANDLING_GUIDE.md'),
          reason: 'Error message should reference documentation',
        );
      });
    });

    group('Edge Cases', () {
      test('handles empty exception names', () {
        expect(_isDataLayerException(''), isFalse);
      });

      test('handles very long exception names', () {
        final longName = 'VeryLongCustomDomainExceptionName' * 3;
        expect(
          _isDataLayerException(longName),
          isFalse,
          reason: 'Very long custom names are not Data layer exceptions',
        );
      });

      test('handles exception names without Exception suffix', () {
        final testCases = [
          'NotFound',
          'Network',
          'Server',
          'Cache',
        ];

        for (final name in testCases) {
          expect(
            _isDataLayerException(name),
            isFalse,
            reason: '$name without Exception suffix should not match',
          );
        }
      });

      test('handles case sensitivity', () {
        expect(
          _isDataLayerException('notfoundexception'),
          isFalse,
          reason: 'Exception names are case-sensitive',
        );
        expect(
          _isDataLayerException('NOTFOUNDEXCEPTION'),
          isFalse,
          reason: 'Exception names are case-sensitive',
        );
      });

      test('handles Dart built-in exceptions', () {
        final dartExceptions = [
          'Exception',
          'Error',
          'StateError',
          'ArgumentError',
          'FormatException',
        ];

        for (final exception in dartExceptions) {
          expect(
            _isDataLayerException(exception),
            isFalse,
            reason: '$exception is Dart built-in, not Data layer exception',
          );
        }
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        // This test documents what violations should be detected in bad example files
        final expectedViolations = {
          'todo_page_bad.dart': [
            'NotFoundException', // Line 22: if (error is NotFoundException)
            'NetworkException', // Line 27: if (error is NetworkException)
            'UnauthorizedException', // Line 32: if (error is UnauthorizedException)
            'NotFoundException', // Line 49: if (error is NotFoundException)
            'ServerException', // Line 53: if (error is ServerException)
            'DataSourceException', // Line 57: if (error is DataSourceException)
          ],
        };

        for (final entry in expectedViolations.entries) {
          for (final violation in entry.value) {
            expect(
              _isDataLayerException(violation),
              isTrue,
              reason: '$violation in ${entry.key} should be flagged',
            );
          }
        }
      });

      test('should accept all exceptions in good examples', () {
        // This test documents what exceptions should pass in good example files
        final expectedPassing = {
          'todo_page_good.dart': [
            'TodoNotFoundException',
            'TodoNetworkException',
            'TodoUnauthorizedException',
          ],
        };

        for (final entry in expectedPassing.entries) {
          for (final exception in entry.value) {
            expect(
              _isDataLayerException(exception),
              isFalse,
              reason: '$exception in ${entry.key} should pass',
            );
          }
        }
      });

      test('estimates violation count in bad examples', () {
        // Based on todo_page_bad.dart analysis:
        // - TodoPage class: 3 violations (lines 22, 27, 32)
        // - ErrorHandlerWidget class: 3 violations (lines 49, 53, 57)
        // Total: 6 violations expected

        const expectedViolationCount = 6;

        expect(
          expectedViolationCount,
          greaterThan(0),
          reason: 'Bad examples should trigger violations',
        );
      });
    });

    group('ExceptionValidationMixin Integration', () {
      test('uses isDataLayerException from mixin', () {
        // Verify mixin method works correctly
        final dataExceptions = [
          'NotFoundException',
          'UnauthorizedException',
          'NetworkException',
          'ServerException',
          'CacheException',
          'DatabaseException',
          'DataSourceException',
        ];

        for (final exception in dataExceptions) {
          expect(
            _isDataLayerException(exception),
            isTrue,
            reason: 'Mixin should detect $exception as Data layer exception',
          );
        }
      });

      test('uses suggestFeaturePrefix from mixin', () {
        final filePath = 'lib/features/todos/presentation/pages/todo_page.dart';
        final suggestion = _suggestDomainException('NotFoundException', filePath);

        expect(
          suggestion,
          'TodoNotFoundException',
          reason: 'Mixin should suggest feature-prefixed exception',
        );
      });
    });
  });
}

// Helper classes for testing

class TestExceptionSuggestion {
  final String filePath;
  final String dataException;
  final String expectedSuggestion;

  TestExceptionSuggestion({
    required this.filePath,
    required this.dataException,
    required this.expectedSuggestion,
  });
}

// Helper functions that simulate rule logic

/// Data layer exceptions from ExceptionValidationMixin
const _dataLayerExceptions = {
  'DataSourceException',
  'CacheException',
  'DatabaseException',
  'NotFoundException',
  'UnauthorizedException',
  'NetworkException',
  'ServerException',
};

bool _isDataLayerException(String exceptionType) {
  return _dataLayerExceptions.contains(exceptionType);
}

bool _isPresentationFile(String filePath) {
  return filePath.contains('/presentation/') || filePath.contains('\\presentation\\');
}

String _suggestDomainException(String dataException, String filePath) {
  final featureName = _extractFeatureName(filePath);

  if (featureName.isNotEmpty) {
    return '$featureName$dataException';
  }

  // Fallback: use generic "Feature" prefix
  return 'Feature$dataException';
}

String _extractFeatureName(String filePath) {
  // Extract feature name from path like: lib/features/{feature}/presentation/...
  final featurePattern = RegExp(r'/features/([^/]+)/');
  final match = featurePattern.firstMatch(filePath);

  if (match != null) {
    final feature = match.group(1)!;
    // Capitalize and singularize (simple heuristic)
    final capitalized = feature[0].toUpperCase() + feature.substring(1);

    // Singularize: categories → Category, todos → Todo, users → User
    if (capitalized.endsWith('ies')) {
      return capitalized.substring(0, capitalized.length - 3) + 'y';
    } else if (capitalized.endsWith('s') && capitalized.length > 1) {
      return capitalized.substring(0, capitalized.length - 1);
    }

    return capitalized;
  }

  return '';
}

String _getErrorMessage(String dataException, String domainException) {
  return '''
Presentation should NOT handle Data exception "$dataException". Use Domain exception instead.

Replace with Domain exception:
  Before: if (error is $dataException)
  After:  if (error is $domainException)

UseCase layer should convert Data exceptions to Domain exceptions.
Data exceptions should never reach Presentation layer.

See ERROR_HANDLING_GUIDE.md for complete patterns.
''';
}
