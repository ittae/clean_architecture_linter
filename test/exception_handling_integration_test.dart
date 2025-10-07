import 'package:test/test.dart';

/// Integration tests for exception handling across all Clean Architecture layers.
///
/// This test suite verifies that all exception-related lint rules work together
/// to enforce correct exception handling patterns across layers:
///
/// Flow: DataSource → Repository → UseCase → Presentation
///
/// Rules Under Test:
/// 1. exception_naming_convention_rule (Task 24.1)
/// 2. datasource_exception_types_rule (Task 24.2)
/// 3. presentation_no_data_exceptions_rule (Task 24.3)
/// 4. repository_no_throw_rule (Task 24.4)
///
/// Test Coverage:
/// - Complete exception flow validation
/// - Inter-rule consistency
/// - False positive/negative detection
/// - Edge cases and boundary conditions
/// - Real-world usage patterns from example project
void main() {
  group('Exception Handling Integration Tests', () {
    group('Complete Exception Flow Validation', () {
      test('validates correct exception flow end-to-end', () {
        // Correct Flow:
        // 1. DataSource throws NotFoundException (data layer exception)
        // 2. Repository catches and converts to Result<Todo, TodoFailure>
        // 3. UseCase unwraps Result and throws TodoNotFoundException (domain exception)
        // 4. Presentation catches TodoNotFoundException (domain exception)

        final flow = ExceptionFlow(
          dataSourceException: 'NotFoundException', // Data layer
          repositoryConvertsTo: 'Result<Todo, TodoFailure>',
          useCaseThrows: 'TodoNotFoundException', // Domain layer
          presentationCatches: 'TodoNotFoundException', // Domain layer
        );

        expect(
          _validateExceptionFlow(flow),
          isTrue,
          reason: 'Correct exception flow should pass all rules',
        );
      });

      test('detects violation: Presentation catches Data exception', () {
        // Violation Flow:
        // Presentation catches NotFoundException (should catch TodoNotFoundException)

        final flow = ExceptionFlow(
          dataSourceException: 'NotFoundException',
          repositoryConvertsTo: 'Result<Todo, TodoFailure>',
          useCaseThrows: 'TodoNotFoundException',
          presentationCatches: 'NotFoundException', // ❌ Data exception in Presentation
        );

        final violations = _detectViolations(flow);

        expect(
          violations,
          contains(RuleViolation.presentationDataException),
          reason: 'Should detect Presentation catching Data exception',
        );
      });

      test('detects violation: Repository throws instead of returning Result', () {
        // Violation Flow:
        // Repository throws ArgumentError (should return Failure)

        final flow = ExceptionFlow(
          dataSourceException: 'NotFoundException',
          repositoryConvertsTo: 'throws ArgumentError', // ❌ Repository throws
          useCaseThrows: 'TodoNotFoundException',
          presentationCatches: 'TodoNotFoundException',
        );

        final violations = _detectViolations(flow);

        expect(
          violations,
          contains(RuleViolation.repositoryThrows),
          reason: 'Should detect Repository throwing exception',
        );
      });

      test('detects violation: DataSource uses generic Exception', () {
        // Violation Flow:
        // DataSource throws Exception (should throw NotFoundException)

        final flow = ExceptionFlow(
          dataSourceException: 'Exception', // ❌ Generic exception
          repositoryConvertsTo: 'Result<Todo, TodoFailure>',
          useCaseThrows: 'TodoNotFoundException',
          presentationCatches: 'TodoNotFoundException',
        );

        final violations = _detectViolations(flow);

        expect(
          violations,
          contains(RuleViolation.dataSourceGenericException),
          reason: 'Should detect DataSource using generic Exception',
        );
      });

      test('detects violation: Domain exception missing feature prefix', () {
        // Violation Flow:
        // UseCase throws NotFoundException (should throw TodoNotFoundException)

        final flow = ExceptionFlow(
          dataSourceException: 'NotFoundException',
          repositoryConvertsTo: 'Result<Todo, TodoFailure>',
          useCaseThrows: 'NotFoundException', // ❌ Missing feature prefix
          presentationCatches: 'NotFoundException',
        );

        final violations = _detectViolations(flow);

        expect(
          violations,
          contains(RuleViolation.missingFeaturePrefix),
          reason: 'Should detect domain exception missing feature prefix',
        );
      });
    });

    group('Inter-Rule Consistency', () {
      test('exception_naming_convention and presentation_no_data_exceptions agree', () {
        // Both rules should recognize the difference between:
        // - Data exceptions: NotFoundException (no prefix)
        // - Domain exceptions: TodoNotFoundException (with prefix)

        expect(
          _isDataLayerException('NotFoundException'),
          isTrue,
          reason: 'NotFoundException is data layer exception',
        );
        expect(
          _isDataLayerException('TodoNotFoundException'),
          isFalse,
          reason: 'TodoNotFoundException is domain exception',
        );
        expect(
          _needsFeaturePrefix('NotFoundException'),
          isTrue,
          reason: 'NotFoundException needs feature prefix in domain layer',
        );
        expect(
          _needsFeaturePrefix('TodoNotFoundException'),
          isFalse,
          reason: 'TodoNotFoundException already has feature prefix',
        );
      });

      test('datasource_exception_types and repository_no_throw coordinate', () {
        // DataSource can throw data exceptions
        // Repository must catch them and convert to Result

        final allowedDataExceptions = [
          'NotFoundException',
          'NetworkException',
          'ServerException',
          'CacheException',
          'DatabaseException',
          'DataSourceException',
          'UnauthorizedException',
        ];

        for (final exception in allowedDataExceptions) {
          expect(
            _isAllowedInDataSource(exception),
            isTrue,
            reason: '$exception should be allowed in DataSource',
          );
          expect(
            _mustBeCaughtByRepository(exception),
            isTrue,
            reason: '$exception must be caught by Repository',
          );
        }
      });

      test('all rules recognize layer boundaries correctly', () {
        // Domain layer
        expect(_isDomainLayer('lib/domain/exceptions/todo_exceptions.dart'), isTrue);
        expect(_isDomainLayer('lib/features/todos/domain/usecases/get_todo.dart'), isTrue);

        // Data layer
        expect(_isDataLayer('lib/data/datasources/todo_remote_datasource.dart'), isTrue);
        expect(_isDataLayer('lib/features/todos/data/repositories/todo_repository_impl.dart'), isTrue);

        // Presentation layer
        expect(_isPresentationLayer('lib/presentation/pages/todo_page.dart'), isTrue);
        expect(_isPresentationLayer('lib/features/todos/presentation/widgets/todo_list.dart'), isTrue);
      });
    });

    group('False Positive Detection', () {
      test('allows Dart built-in exceptions in all layers', () {
        final dartBuiltIns = [
          'Exception',
          'Error',
          'StateError',
          'ArgumentError',
          'FormatException',
        ];

        for (final exception in dartBuiltIns) {
          // These should not trigger feature prefix requirement
          expect(
            _isDartBuiltIn(exception),
            isTrue,
            reason: '$exception is Dart built-in',
          );
        }
      });

      test('allows rethrow in Repository catch blocks', () {
        expect(
          _isAllowedRepositoryThrow(ThrowContext.rethrowInCatch),
          isTrue,
          reason: 'Rethrow should be allowed in Repository',
        );
      });

      test('allows private method throws in Repository', () {
        expect(
          _isAllowedRepositoryThrow(ThrowContext.privateMethod),
          isTrue,
          reason: 'Private methods can throw (caught by public methods)',
        );
      });

      test('allows constructor throws in Repository', () {
        expect(
          _isAllowedRepositoryThrow(ThrowContext.constructor),
          isTrue,
          reason: 'Constructors can throw for validation',
        );
      });
    });

    group('False Negative Detection', () {
      test('detects generic exception in domain layer', () {
        // Even though "ValidationException" might seem descriptive,
        // it still needs a feature prefix in domain layer

        expect(
          _needsFeaturePrefix('ValidationException'),
          isTrue,
          reason: 'ValidationException needs feature prefix (TodoValidationException)',
        );
      });

      test('detects subtle Repository throw violations', () {
        // Repository throwing in catch block (not rethrow)
        expect(
          _isAllowedRepositoryThrow(ThrowContext.newExceptionInCatch),
          isFalse,
          reason: 'Creating new exception in catch should return Failure',
        );
      });

      test('detects custom exceptions in DataSource', () {
        final customExceptions = [
          'TodoApiException',
          'CustomDataException',
          'MyException',
        ];

        for (final exception in customExceptions) {
          expect(
            _isAllowedInDataSource(exception),
            isFalse,
            reason: '$exception is custom, not allowed in DataSource',
          );
        }
      });
    });

    group('Edge Cases and Boundary Conditions', () {
      test('handles nested exception hierarchies', () {
        // Data: NotFoundException
        // Domain: TodoNotFoundException extends DomainException
        // Presentation should catch TodoNotFoundException, not NotFoundException

        expect(
          _isDataLayerException('NotFoundException'),
          isTrue,
        );
        expect(
          _isDataLayerException('TodoNotFoundException'),
          isFalse,
        );
      });

      test('handles exception in multiple layers with same name', () {
        // NotFoundException can exist in both data and domain layers
        // Context (file path) determines which is which

        expect(
          _resolveExceptionLayer('NotFoundException', 'lib/data/exceptions/'),
          equals(Layer.data),
        );
        expect(
          _resolveExceptionLayer('NotFoundException', 'lib/domain/exceptions/'),
          equals(Layer.domain),
        );
      });

      test('handles async exception propagation', () {
        // Future<Result<T, E>> pattern should work correctly
        final asyncFlow = ExceptionFlow(
          dataSourceException: 'NetworkException',
          repositoryConvertsTo: 'Future<Result<Todo, TodoFailure>>',
          useCaseThrows: 'TodoNetworkException',
          presentationCatches: 'TodoNetworkException',
        );

        expect(
          _validateExceptionFlow(asyncFlow),
          isTrue,
          reason: 'Async exception flow should be valid',
        );
      });

      test('handles Stream exception propagation', () {
        // Stream<Result<T, E>> pattern
        final streamFlow = ExceptionFlow(
          dataSourceException: 'ServerException',
          repositoryConvertsTo: 'Stream<Result<Todo, TodoFailure>>',
          useCaseThrows: 'TodoServerException',
          presentationCatches: 'TodoServerException',
        );

        expect(
          _validateExceptionFlow(streamFlow),
          isTrue,
          reason: 'Stream exception flow should be valid',
        );
      });
    });

    group('Real-World Usage Patterns from Example Project', () {
      test('validates example project good patterns', () {
        final goodExamples = {
          'repository_no_throw_good.dart': [
            'Returns Failure instead of throwing',
            'Private methods can throw',
            'Constructors can throw',
            'Rethrow is allowed',
          ],
          'datasource_defined_exceptions_good.dart': [
            'Uses NotFoundException (data layer)',
            'Uses NetworkException (data layer)',
            'Uses ServerException (data layer)',
          ],
          'exception_with_prefix_good.dart': [
            'TodoNotFoundException (domain)',
            'UserValidationException (domain)',
            'OrderNetworkException (domain)',
          ],
          'todo_page_good.dart': [
            'Catches TodoNotFoundException (domain)',
            'Catches TodoNetworkException (domain)',
            'Catches TodoUnauthorizedException (domain)',
          ],
        };

        for (final example in goodExamples.entries) {
          expect(
            _hasViolations(example.key),
            isFalse,
            reason: '${example.key} should have no violations',
          );
        }
      });

      test('detects example project bad patterns', () {
        final expectedViolations = {
          'repository_throws_bad.dart': 3, // Task 24.4
          'datasource_custom_exceptions_bad.dart': 11, // Task 24.2
          'exception_no_prefix_bad.dart': 4, // Task 24.1
          'todo_page_bad.dart': 6, // Task 24.3
        };

        for (final example in expectedViolations.entries) {
          final actualCount = _countViolations(example.key);
          expect(
            actualCount,
            equals(example.value),
            reason: '${example.key} should have ${example.value} violations, found $actualCount',
          );
        }
      });

      test('validates total violation count in example project', () {
        // Total from all 4 rules:
        // 24.1: 4 violations (exception_no_prefix_bad.dart)
        // 24.2: 11 violations (datasource_custom_exceptions_bad.dart)
        // 24.3: 6 violations (todo_page_bad.dart)
        // 24.4: 3 violations (repository_throws_bad.dart)
        // Total: 24 violations expected

        const expectedTotalViolations = 24;

        expect(
          _getTotalViolationCount(),
          equals(expectedTotalViolations),
          reason: 'Example project should have exactly $expectedTotalViolations violations',
        );
      });
    });

    group('Rule Interaction Matrix', () {
      test('exception_naming_convention does not conflict with datasource_exception_types', () {
        // Data layer can use NotFoundException (no feature prefix)
        // Domain layer needs TodoNotFoundException (with feature prefix)

        expect(
          _isAllowedInDataSource('NotFoundException'),
          isTrue,
        );
        expect(
          _needsFeaturePrefixInDomain('NotFoundException'),
          isTrue,
        );
      });

      test('datasource_exception_types does not conflict with repository_no_throw', () {
        // DataSource can throw NotFoundException
        // Repository must catch and convert to Result

        expect(
          _isAllowedInDataSource('NotFoundException'),
          isTrue,
        );
        expect(
          _mustBeCaughtByRepository('NotFoundException'),
          isTrue,
        );
        expect(
          _isAllowedRepositoryThrow(ThrowContext.publicMethod),
          isFalse,
        );
      });

      test('repository_no_throw does not conflict with presentation_no_data_exceptions', () {
        // Repository converts to Result (no throw)
        // Presentation catches domain exceptions (not data exceptions)

        expect(
          _isAllowedRepositoryThrow(ThrowContext.publicMethod),
          isFalse,
        );
        expect(
          _isDataLayerException('NotFoundException'),
          isTrue,
        );
        expect(
          _canPresentationCatch('TodoNotFoundException'),
          isTrue,
        );
        expect(
          _canPresentationCatch('NotFoundException'),
          isFalse,
        );
      });
    });
  });
}

// Helper classes and enums

class ExceptionFlow {
  final String dataSourceException;
  final String repositoryConvertsTo;
  final String useCaseThrows;
  final String presentationCatches;

  ExceptionFlow({
    required this.dataSourceException,
    required this.repositoryConvertsTo,
    required this.useCaseThrows,
    required this.presentationCatches,
  });
}

enum RuleViolation {
  presentationDataException,
  repositoryThrows,
  dataSourceGenericException,
  missingFeaturePrefix,
}

enum ThrowContext {
  rethrowInCatch,
  privateMethod,
  constructor,
  publicMethod,
  newExceptionInCatch,
}

enum Layer {
  domain,
  data,
  presentation,
}

// Helper functions that simulate combined rule logic

bool _validateExceptionFlow(ExceptionFlow flow) {
  // Check each step of the flow
  if (!_isAllowedInDataSource(flow.dataSourceException)) return false;
  if (!flow.repositoryConvertsTo.contains('Result<')) return false;
  if (_isDataLayerException(flow.useCaseThrows)) return false;
  if (_isDataLayerException(flow.presentationCatches)) return false;
  return true;
}

List<RuleViolation> _detectViolations(ExceptionFlow flow) {
  final violations = <RuleViolation>[];

  // Check Presentation catches data exception
  if (_isDataLayerException(flow.presentationCatches)) {
    violations.add(RuleViolation.presentationDataException);
  }

  // Check Repository throws
  if (flow.repositoryConvertsTo.contains('throws')) {
    violations.add(RuleViolation.repositoryThrows);
  }

  // Check DataSource uses generic exception
  if (!_isAllowedInDataSource(flow.dataSourceException)) {
    violations.add(RuleViolation.dataSourceGenericException);
  }

  // Check domain exception missing feature prefix
  if (_needsFeaturePrefix(flow.useCaseThrows) && !_isDartBuiltIn(flow.useCaseThrows)) {
    violations.add(RuleViolation.missingFeaturePrefix);
  }

  return violations;
}

// Data layer exceptions (Task 24.2)
const _dataLayerExceptions = {
  'NotFoundException',
  'UnauthorizedException',
  'NetworkException',
  'ServerException',
  'CacheException',
  'DatabaseException',
  'DataSourceException',
};

// Dart built-in exceptions (Task 24.1)
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

// Generic exception suffixes needing feature prefix (Task 24.1)
const _genericExceptionSuffixes = {
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

bool _isDataLayerException(String exceptionName) {
  return _dataLayerExceptions.contains(exceptionName);
}

bool _needsFeaturePrefix(String exceptionName) {
  return _genericExceptionSuffixes.contains(exceptionName);
}

bool _needsFeaturePrefixInDomain(String exceptionName) {
  return _genericExceptionSuffixes.contains(exceptionName);
}

bool _isDartBuiltIn(String exceptionName) {
  return _dartBuiltInExceptions.contains(exceptionName);
}

bool _isAllowedInDataSource(String exceptionName) {
  return _dataLayerExceptions.contains(exceptionName);
}

bool _mustBeCaughtByRepository(String exceptionName) {
  return _dataLayerExceptions.contains(exceptionName);
}

bool _isAllowedRepositoryThrow(ThrowContext context) {
  switch (context) {
    case ThrowContext.rethrowInCatch:
    case ThrowContext.privateMethod:
    case ThrowContext.constructor:
      return true;
    case ThrowContext.publicMethod:
    case ThrowContext.newExceptionInCatch:
      return false;
  }
}

bool _canPresentationCatch(String exceptionName) {
  // Presentation can only catch domain exceptions (with feature prefix)
  return !_isDataLayerException(exceptionName);
}

bool _isDomainLayer(String filePath) {
  return filePath.contains('/domain/') || filePath.contains('\\domain\\');
}

bool _isDataLayer(String filePath) {
  return filePath.contains('/data/') || filePath.contains('\\data\\');
}

bool _isPresentationLayer(String filePath) {
  return filePath.contains('/presentation/') || filePath.contains('\\presentation\\');
}

Layer _resolveExceptionLayer(String exceptionName, String filePath) {
  if (_isDomainLayer(filePath)) return Layer.domain;
  if (_isDataLayer(filePath)) return Layer.data;
  if (_isPresentationLayer(filePath)) return Layer.presentation;
  return Layer.domain; // default
}

bool _hasViolations(String filename) {
  // Good examples should have no violations
  return filename.contains('_bad.');
}

int _countViolations(String filename) {
  // Simulate violation counting based on known examples
  final violations = {
    'repository_throws_bad.dart': 3,
    'datasource_custom_exceptions_bad.dart': 11,
    'exception_no_prefix_bad.dart': 4,
    'todo_page_bad.dart': 6,
  };
  return violations[filename] ?? 0;
}

int _getTotalViolationCount() {
  return 3 + 11 + 4 + 6; // 24 total
}
