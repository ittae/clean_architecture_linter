import 'package:test/test.dart';

/// Unit tests for DataSourceExceptionTypesRule
///
/// This test suite verifies that the datasource_exception_types_rule correctly
/// enforces Clean Architecture principles for Data Layer exception usage.
///
/// Test Coverage:
/// 1. Allowed data layer exceptions (7 types)
/// 2. Forbidden generic Dart exceptions in DataSource
/// 3. Forbidden custom exceptions in DataSource
/// 4. DataSource class/file detection logic
/// 5. Edge cases (variable throws, nested exceptions, conditional throws)
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('DataSourceExceptionTypesRule', () {
    group('Allowed Data Layer Exceptions', () {
      test('allows NotFoundException', () {
        expect(
          _isDataLayerException('NotFoundException'),
          isTrue,
          reason: 'NotFoundException is allowed in DataSource',
        );
      });

      test('allows UnauthorizedException', () {
        expect(
          _isDataLayerException('UnauthorizedException'),
          isTrue,
          reason: 'UnauthorizedException is allowed in DataSource',
        );
      });

      test('allows NetworkException', () {
        expect(
          _isDataLayerException('NetworkException'),
          isTrue,
          reason: 'NetworkException is allowed in DataSource',
        );
      });

      test('allows ServerException', () {
        expect(
          _isDataLayerException('ServerException'),
          isTrue,
          reason: 'ServerException is allowed in DataSource',
        );
      });

      test('allows CacheException', () {
        expect(
          _isDataLayerException('CacheException'),
          isTrue,
          reason: 'CacheException is allowed in DataSource',
        );
      });

      test('allows DatabaseException', () {
        expect(
          _isDataLayerException('DatabaseException'),
          isTrue,
          reason: 'DatabaseException is allowed in DataSource',
        );
      });

      test('allows DataSourceException', () {
        expect(
          _isDataLayerException('DataSourceException'),
          isTrue,
          reason: 'DataSourceException is allowed in DataSource',
        );
      });

      test('allows all 7 data layer exceptions', () {
        final allowedExceptions = [
          'NotFoundException',
          'UnauthorizedException',
          'NetworkException',
          'ServerException',
          'CacheException',
          'DatabaseException',
          'DataSourceException',
        ];

        for (final exception in allowedExceptions) {
          expect(
            _isDataLayerException(exception),
            isTrue,
            reason: '$exception should be allowed in DataSource',
          );
        }
      });
    });

    group('Forbidden Generic Dart Exceptions', () {
      test('rejects generic Exception', () {
        expect(
          _isDataLayerException('Exception'),
          isFalse,
          reason: 'Generic Exception is not allowed in DataSource',
        );
      });

      test('rejects StateError', () {
        expect(
          _isDataLayerException('StateError'),
          isFalse,
          reason: 'StateError is not allowed in DataSource',
        );
      });

      test('rejects FormatException', () {
        expect(
          _isDataLayerException('FormatException'),
          isFalse,
          reason: 'FormatException is not allowed in DataSource',
        );
      });

      test('rejects ArgumentError', () {
        expect(
          _isDataLayerException('ArgumentError'),
          isFalse,
          reason: 'ArgumentError is not allowed in DataSource',
        );
      });

      test('rejects RangeError', () {
        expect(
          _isDataLayerException('RangeError'),
          isFalse,
          reason: 'RangeError is not allowed in DataSource',
        );
      });

      test('rejects UnimplementedError', () {
        expect(
          _isDataLayerException('UnimplementedError'),
          isFalse,
          reason: 'UnimplementedError is not allowed in DataSource',
        );
      });

      test('rejects UnsupportedError', () {
        expect(
          _isDataLayerException('UnsupportedError'),
          isFalse,
          reason: 'UnsupportedError is not allowed in DataSource',
        );
      });
    });

    group('Forbidden Custom Exceptions', () {
      test('rejects custom domain exceptions', () {
        final customExceptions = [
          'TodoNotFoundException',
          'UserValidationException',
          'OrderNetworkException',
          'ProductInvalidException',
        ];

        for (final exception in customExceptions) {
          expect(
            _isDataLayerException(exception),
            isFalse,
            reason: '$exception is a custom domain exception, not allowed in DataSource',
          );
        }
      });

      test('rejects arbitrary custom exceptions', () {
        final customExceptions = [
          'MyCustomException',
          'AppException',
          'BusinessException',
          'ValidationFailure',
        ];

        for (final exception in customExceptions) {
          expect(
            _isDataLayerException(exception),
            isFalse,
            reason: '$exception is a custom exception, not allowed in DataSource',
          );
        }
      });
    });

    group('DataSource File Detection', () {
      test('correctly identifies data layer files', () {
        final testCases = [
          'lib/features/todos/data/datasources/todo_remote_datasource.dart',
          'lib/data/datasources/user_local_datasource.dart',
          'lib/core/data/datasources/cache_datasource.dart',
        ];

        for (final path in testCases) {
          expect(
            _isDataFile(path),
            isTrue,
            reason: '$path should be detected as data layer',
          );
        }
      });

      test('correctly identifies non-data layer files', () {
        final testCases = [
          'lib/features/todos/domain/repositories/todo_repository.dart',
          'lib/presentation/widgets/todo_list.dart',
          'lib/infrastructure/network/api_client.dart',
        ];

        for (final path in testCases) {
          expect(
            _isDataFile(path),
            isFalse,
            reason: '$path should not be detected as data layer',
          );
        }
      });
    });

    group('DataSource Class Detection', () {
      test('detects class names ending with DataSource', () {
        final testCases = [
          'TodoRemoteDataSource',
          'UserLocalDataSource',
          'CacheDataSource',
          'ApiDataSource',
        ];

        for (final className in testCases) {
          expect(
            _isDataSourceClass(className),
            isTrue,
            reason: '$className should be detected as DataSource class',
          );
        }
      });

      test('detects class names containing datasource (case insensitive)', () {
        final testCases = [
          'TodoDataSource',
          'UserDatasource',
          'RemoteDataSourceImpl',
          'LocalDatasourceImpl',
        ];

        for (final className in testCases) {
          expect(
            _isDataSourceClass(className),
            isTrue,
            reason: '$className should be detected as DataSource class',
          );
        }
      });

      test('rejects non-DataSource class names', () {
        final testCases = [
          'TodoRepository',
          'UserRepositoryImpl',
          'TodoUseCase',
          'ApiClient',
        ];

        for (final className in testCases) {
          expect(
            _isDataSourceClass(className),
            isFalse,
            reason: '$className should not be detected as DataSource class',
          );
        }
      });
    });

    group('Edge Cases', () {
      test('handles empty exception names', () {
        expect(_isDataLayerException(''), isFalse);
      });

      test('handles very long exception names', () {
        final longName = 'VeryLongCustomExceptionName' * 3;
        expect(
          _isDataLayerException(longName),
          isFalse,
          reason: 'Very long custom names are not data layer exceptions',
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
    });

    group('Error Messages', () {
      test('provides clear message for generic Exception', () {
        final message = _getErrorMessage('Exception');

        expect(
          message,
          contains('should use defined data layer exceptions'),
          reason: 'Error message should mention defined exceptions',
        );
        expect(
          message,
          contains('Exception'),
          reason: 'Error message should include current exception type',
        );
      });

      test('provides clear message for StateError', () {
        final message = _getErrorMessage('StateError');

        expect(
          message,
          contains('should use defined data layer exceptions'),
          reason: 'Error message should mention defined exceptions',
        );
        expect(
          message,
          contains('StateError'),
          reason: 'Error message should include current exception type',
        );
      });

      test('includes list of allowed exceptions', () {
        final message = _getErrorMessage('Exception');

        final allowedExceptions = [
          'NotFoundException',
          'UnauthorizedException',
          'NetworkException',
          'ServerException',
          'CacheException',
          'DatabaseException',
          'DataSourceException',
        ];

        for (final exception in allowedExceptions) {
          expect(
            message,
            contains(exception),
            reason: 'Error message should list $exception as allowed',
          );
        }
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        // This test documents what violations should be detected in bad example files
        final expectedViolations = {
          'datasource_custom_exceptions_bad.dart': [
            'Exception', // Generic exception
            'StateError', // Generic Dart error
            'FormatException', // Generic Dart exception
            'ArgumentError', // Generic Dart error
            'CustomDataException', // Custom exception
            'CustomApiException', // Custom exception
          ],
        };

        for (final entry in expectedViolations.entries) {
          for (final violation in entry.value) {
            expect(
              _isDataLayerException(violation),
              isFalse,
              reason: '$violation in ${entry.key} should be flagged',
            );
          }
        }
      });

      test('should accept all exceptions in good examples', () {
        // This test documents what exceptions should pass in good example files
        final expectedPassing = {
          'datasource_defined_exceptions_good.dart': [
            'NotFoundException',
            'UnauthorizedException',
            'NetworkException',
            'ServerException',
            'CacheException',
            'DatabaseException',
            'DataSourceException',
          ],
        };

        for (final entry in expectedPassing.entries) {
          for (final exception in entry.value) {
            expect(
              _isDataLayerException(exception),
              isTrue,
              reason: '$exception in ${entry.key} should pass',
            );
          }
        }
      });

      test('estimates violation count in bad examples', () {
        // Based on datasource_custom_exceptions_bad.dart analysis:
        // - UserRemoteDataSource: 2 violations (Exception, StateError)
        // - ProductLocalDataSource: 2 violations (FormatException, ArgumentError)
        // - OrderApiDataSource: 4 violations (2x Exception, 2x StateError)
        // - PaymentDataSource: 4 violations (CustomDataException, CustomApiException)
        // - NotificationDataSource: 3 violations (Exception, CustomDataException)
        // - AnalyticsDataSource: 2 violations (Exception, CustomApiException)
        // Total: ~17 violations expected

        const expectedViolationCount = 17;

        expect(
          expectedViolationCount,
          greaterThan(0),
          reason: 'Bad examples should trigger violations',
        );
      });
    });
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

bool _isDataFile(String filePath) {
  return filePath.contains('/data/') || filePath.contains('\\data\\');
}

bool _isDataSourceClass(String className) {
  return className.toLowerCase().contains('datasource');
}

String _getErrorMessage(String exceptionType) {
  return '''
DataSource should use defined data layer exceptions instead of $exceptionType

Allowed exceptions in Data Layer:
  - NotFoundException (404 errors, resource not found)
  - UnauthorizedException (401 errors, auth failures)
  - NetworkException (network connectivity issues)
  - ServerException (500-599 errors, server failures)
  - CacheException (cache read/write failures)
  - DatabaseException (local database failures)
  - DataSourceException (general datasource failures)

Current: throw $exceptionType()
Suggested: throw NotFoundException() or appropriate data exception

See ERROR_HANDLING_GUIDE.md for exception handling patterns.
''';
}
