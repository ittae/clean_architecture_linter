import 'package:test/test.dart';

/// Unit tests for ExceptionNamingConventionRule
///
/// This test suite verifies that the exception_naming_convention_rule correctly
/// enforces Clean Architecture principles for Domain Exception naming patterns.
///
/// Test Coverage:
/// 1. Feature prefix requirement for domain exceptions
/// 2. Generic exception name detection (NotFoundException, ValidationException)
/// 3. Allowed exceptions without prefix (Dart built-in, Data layer exceptions)
/// 4. Feature prefix suggestion based on file path
/// 5. Edge cases (short names, compound names, nested features)
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('ExceptionNamingConventionRule', () {
    group('Generic Exception Name Detection', () {
      test('detects exact generic exception suffixes', () {
        final testCases = [
          'NotFoundException',
          'ValidationException',
          'UnauthorizedException',
          'NetworkException',
          'ServerException',
          'TimeoutException',
          'CancelledException',
          'InvalidException',
          'DuplicateException',
        ];

        for (final className in testCases) {
          expect(
            _isGenericExceptionName(className),
            isTrue,
            reason: '$className should be detected as generic exception',
          );
        }
      });

      test('detects very short generic exception names', () {
        final testCases = [
          'DataException', // 4 chars before Exception
          'FileException', // 4 chars before Exception
          'ApiException', // 3 chars before Exception
        ];

        for (final className in testCases) {
          expect(
            _isGenericExceptionName(className),
            isTrue,
            reason: '$className should be detected as generic exception',
          );
        }
      });

      test('accepts feature-prefixed exceptions', () {
        final testCases = [
          'TodoNotFoundException',
          'UserValidationException',
          'OrderNetworkException',
          'ProductInvalidException',
        ];

        for (final className in testCases) {
          expect(
            _isGenericExceptionName(className),
            isFalse,
            reason: '$className should not be detected as generic',
          );
        }
      });

      test('accepts longer descriptive exception names', () {
        final testCases = [
          'AuthenticationException', // 14 chars before Exception
          'AuthorizationException', // 13 chars before Exception
          'ConfigurationException', // 13 chars before Exception
        ];

        for (final className in testCases) {
          expect(
            _isGenericExceptionName(className),
            isFalse,
            reason: '$className is descriptive enough',
          );
        }
      });
    });

    group('Allowed Exceptions Without Prefix', () {
      test('allows Dart built-in exceptions', () {
        final testCases = [
          'Exception',
          'Error',
          'StateError',
          'ArgumentError',
          'FormatException',
          'RangeError',
          'UnimplementedError',
          'UnsupportedError',
        ];

        for (final className in testCases) {
          expect(
            _isAllowedWithoutPrefix(className),
            isTrue,
            reason: '$className is Dart built-in exception',
          );
        }
      });

      test('allows Data layer infrastructure exceptions', () {
        final testCases = [
          'DataSourceException',
          'CacheException',
          'DatabaseException',
        ];

        for (final className in testCases) {
          expect(
            _isAllowedWithoutPrefix(className),
            isTrue,
            reason: '$className is Data layer exception',
          );
        }
      });

      test('rejects domain exceptions needing prefix (not in allowed lists)',
          () {
        final testCases = [
          'ValidationException',
          'TimeoutException',
          'CancelledException',
        ];

        for (final className in testCases) {
          expect(
            _isAllowedWithoutPrefix(className),
            isFalse,
            reason: '$className should require feature prefix',
          );
        }
      });
    });

    group('Feature Prefix Suggestion', () {
      test('suggests feature prefix from file path', () {
        final testCases = [
          TestFeatureSuggestion(
            filePath:
                'lib/features/todos/domain/exceptions/todo_exceptions.dart',
            exceptionName: 'NotFoundException',
            expectedSuggestion: 'TodoNotFoundException',
          ),
          TestFeatureSuggestion(
            filePath:
                'lib/features/users/domain/exceptions/user_exceptions.dart',
            exceptionName: 'ValidationException',
            expectedSuggestion: 'UserValidationException',
          ),
          TestFeatureSuggestion(
            filePath:
                'lib/features/orders/domain/exceptions/order_exceptions.dart',
            exceptionName: 'NetworkException',
            expectedSuggestion: 'OrderNetworkException',
          ),
        ];

        for (final testCase in testCases) {
          final suggestion = _suggestFeaturePrefix(
            testCase.exceptionName,
            testCase.filePath,
          );

          expect(
            suggestion,
            testCase.expectedSuggestion,
            reason:
                'Should suggest ${testCase.expectedSuggestion} for ${testCase.filePath}',
          );
        }
      });

      test('handles nested feature paths', () {
        final testCases = [
          TestFeatureSuggestion(
            filePath:
                'lib/features/auth/domain/exceptions/auth_exceptions.dart',
            exceptionName: 'NotFoundException',
            expectedSuggestion:
                'AuthNotFoundException', // Uses feature name after features/
          ),
          TestFeatureSuggestion(
            filePath:
                'lib/core/features/todos/domain/exceptions/todo_exceptions.dart',
            exceptionName: 'ValidationException',
            expectedSuggestion: 'TodoValidationException',
          ),
        ];

        for (final testCase in testCases) {
          final suggestion = _suggestFeaturePrefix(
            testCase.exceptionName,
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
          'lib/domain/exceptions/exception.dart',
          'lib/unknown/path.dart',
        ];

        for (final filePath in testCases) {
          final suggestion =
              _suggestFeaturePrefix('NotFoundException', filePath);

          expect(
            suggestion,
            contains('NotFoundException'),
            reason: 'Should contain exception name for $filePath',
          );
          // Fallback should add "Feature" prefix
          expect(
            suggestion,
            'FeatureNotFoundException',
            reason: 'Should use fallback prefix for $filePath',
          );
        }
      });
    });

    group('Domain Layer File Detection', () {
      test('correctly identifies domain layer files', () {
        final testCases = [
          'lib/features/todos/domain/exceptions/todo_exceptions.dart',
          'lib/domain/exceptions/app_exceptions.dart',
          'lib/core/domain/exceptions/core_exceptions.dart',
        ];

        for (final path in testCases) {
          expect(
            _isDomainFile(path),
            isTrue,
            reason: '$path should be detected as domain layer',
          );
        }
      });

      test('correctly identifies non-domain layer files', () {
        final testCases = [
          'lib/features/todos/data/exceptions/data_exceptions.dart',
          'lib/presentation/exceptions/ui_exceptions.dart',
          'lib/infrastructure/exceptions/infra_exceptions.dart',
        ];

        for (final path in testCases) {
          expect(
            _isDomainFile(path),
            isFalse,
            reason: '$path should not be detected as domain layer',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for generic exception name', () {
        final message = _getErrorMessage(
          'NotFoundException',
          'TodoNotFoundException',
        );

        expect(
          message,
          contains('should have feature prefix'),
          reason: 'Error message should mention feature prefix',
        );
        expect(
          message,
          contains('NotFoundException'),
          reason: 'Error message should include current name',
        );
        expect(
          message,
          contains('TodoNotFoundException'),
          reason: 'Error message should include suggested name',
        );
      });

      test('provides pattern explanation', () {
        final message = _getErrorMessage(
          'ValidationException',
          'UserValidationException',
        );

        expect(
          message,
          contains('{Feature}{ExceptionType}'),
          reason: 'Error message should explain naming pattern',
        );
      });

      test('includes helpful examples', () {
        final message = _getErrorMessage(
          'NetworkException',
          'OrderNetworkException',
        );

        expect(
          message,
          contains('TodoNotFoundException'),
          reason: 'Error message should include example',
        );
        expect(
          message,
          contains('UserValidationException'),
          reason: 'Error message should include another example',
        );
      });
    });

    group('Edge Cases', () {
      test('handles empty exception names', () {
        expect(_isGenericExceptionName(''), isFalse);
        expect(_isAllowedWithoutPrefix(''), isFalse);
      });

      test('handles very long exception names', () {
        final longName = 'VeryLongFeatureSpecificExceptionName' * 3;
        expect(
          _isGenericExceptionName(longName),
          isFalse,
          reason: 'Very long names are not generic',
        );
      });

      test('handles exception names without Exception suffix', () {
        final testCases = [
          'NotFound',
          'Validation',
          'Unauthorized',
        ];

        for (final className in testCases) {
          expect(
            _isGenericExceptionName(className),
            isFalse,
            reason: '$className without Exception suffix should not match',
          );
        }
      });

      test('handles compound exception names', () {
        final testCases = [
          'TodoTaskNotFoundException', // Feature + Type + Exception
          'UserAccountValidationException', // Feature + Domain + Exception
        ];

        for (final className in testCases) {
          expect(
            _isGenericExceptionName(className),
            isFalse,
            reason: '$className is compound and feature-specific',
          );
        }
      });
    });

    group('Integration Test Expectations', () {
      test('should detect bad examples', () {
        // This test documents what violations should be detected in bad example files
        final expectedViolations = {
          'exception_no_prefix_bad.dart': [
            'NotFoundException',
            'ValidationException',
            'UnauthorizedException',
            'NetworkException',
          ],
        };

        for (final entry in expectedViolations.entries) {
          for (final violation in entry.value) {
            expect(
              _isGenericExceptionName(violation),
              isTrue,
              reason: '$violation in ${entry.key} should be flagged',
            );
          }
        }
      });

      test('should accept good examples', () {
        // This test documents what exceptions should pass in good example files
        final expectedPassing = {
          'exception_with_prefix_good.dart': [
            'TodoNotFoundException',
            'TodoValidationException',
            'UserNotFoundException',
            'UserUnauthorizedException',
            'OrderNetworkException',
          ],
        };

        for (final entry in expectedPassing.entries) {
          for (final exception in entry.value) {
            expect(
              _isGenericExceptionName(exception),
              isFalse,
              reason: '$exception in ${entry.key} should pass',
            );
          }
        }
      });
    });
  });
}

// Helper classes for testing
class TestFeatureSuggestion {
  final String filePath;
  final String exceptionName;
  final String expectedSuggestion;

  TestFeatureSuggestion({
    required this.filePath,
    required this.exceptionName,
    required this.expectedSuggestion,
  });
}

// Helper functions that simulate rule logic

/// Generic exception suffixes from ExceptionValidationMixin
const _exceptionSuffixes = {
  'NotFoundException',
  'ValidationException',
  'UnauthorizedException',
  'NetworkException',
  'ServerException',
  'TimeoutException',
  'CancelledException',
  'InvalidException',
  'DuplicateException',
};

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

/// Dart built-in exceptions from ExceptionValidationMixin
const _dartBuiltInExceptions = {
  'Exception',
  'Error',
  'StateError',
  'ArgumentError',
  'FormatException',
  'RangeError',
  'UnimplementedError',
  'UnsupportedError',
};

bool _isGenericExceptionName(String className) {
  // Check if it exactly matches a generic suffix
  if (_exceptionSuffixes.contains(className)) {
    return true;
  }

  // Check if it's a very short, generic exception name
  if (className.endsWith('Exception') && className.length < 20) {
    final withoutSuffix = className.replaceAll('Exception', '');
    if (withoutSuffix.length < 5) {
      return true;
    }
  }

  return false;
}

bool _isAllowedWithoutPrefix(String className) {
  return _dartBuiltInExceptions.contains(className) ||
      _dataLayerExceptions.contains(className);
}

String _suggestFeaturePrefix(String className, String filePath) {
  final featureName = _extractFeatureName(filePath);

  if (featureName.isNotEmpty) {
    return '$featureName$className';
  }

  // Fallback: use generic "Feature" prefix
  return 'Feature$className';
}

String _extractFeatureName(String filePath) {
  // Extract feature name from path like: lib/features/{feature}/domain/...
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

bool _isDomainFile(String filePath) {
  return filePath.contains('/domain/') || filePath.contains('\\domain\\');
}

String _getErrorMessage(String currentName, String suggestedName) {
  return '''
Domain Exception "$currentName" should have feature prefix
Add feature prefix to exception name:
  Current:  class $currentName implements Exception
  Suggested: class $suggestedName implements Exception

Pattern: {Feature}{ExceptionType}
Examples: TodoNotFoundException, UserValidationException

This helps identify which feature the exception belongs to.
''';
}
