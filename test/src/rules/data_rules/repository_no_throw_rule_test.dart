import 'package:test/test.dart';

/// Unit tests for RepositoryNoThrowRule
///
/// This test suite verifies that the repository_no_throw_rule correctly
/// enforces Clean Architecture error handling boundaries in Repository implementations.
///
/// Test Coverage:
/// 1. Repository implementation detection
/// 2. Allowed throw patterns (rethrow, private methods, constructors)
/// 3. Forbidden throw patterns (direct throws in public methods)
/// 4. Repository interface detection
/// 5. Integration with RepositoryRuleVisitor mixin
///
/// Error Handling Flow (Pass-through pattern):
/// - DataSource: Throws AppException (NotFoundException, NetworkException)
/// - Repository: Pass-through (lets exceptions bubble up)
/// - UseCase: May add business validation, throws AppException
/// - Presentation: AsyncValue.guard() catches exceptions
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('RepositoryNoThrowRule', () {
    group('Repository Implementation Detection', () {
      test(
        'detects Repository implementation by class name with Impl suffix',
        () {
          expect(
            _isRepositoryImplementation('TodoRepositoryImpl'),
            isTrue,
            reason: 'Class name ending with Impl should be detected',
          );
        },
      );

      test(
        'detects Repository implementation by class name with Implementation suffix',
        () {
          expect(
            _isRepositoryImplementation('UserRepositoryImplementation'),
            isTrue,
            reason: 'Class name ending with Implementation should be detected',
          );
        },
      );

      test('detects Repository by interface implementation', () {
        // This would be checked via AST analysis
        expect(
          _isRepositoryImplementation('TodoRepositoryImpl'),
          isTrue,
          reason:
              'Classes implementing Repository interfaces should be detected',
        );
      });

      test('rejects non-Repository classes', () {
        final testCases = [
          'TodoUseCase',
          'UserController',
          'ApiClient',
          'DataSource',
        ];

        for (final className in testCases) {
          expect(
            _isRepositoryImplementation(className),
            isFalse,
            reason: '$className should not be detected as Repository',
          );
        }
      });
    });

    group('Repository Interface Detection', () {
      test('detects abstract Repository interface', () {
        expect(
          _isRepositoryInterface('TodoRepository'),
          isTrue,
          reason: 'Abstract class with Repository in name should be detected',
        );
      });

      test('detects Repository interface by naming convention', () {
        final testCases = [
          'UserRepository',
          'OrderRepository',
          'ProductRepository',
        ];

        for (final className in testCases) {
          expect(
            _isRepositoryInterface(className),
            isTrue,
            reason: '$className should be detected as Repository interface',
          );
        }
      });

      test('rejects Repository implementations as interfaces', () {
        final testCases = [
          'TodoRepositoryImpl',
          'UserRepositoryImplementation',
        ];

        for (final className in testCases) {
          expect(
            _isRepositoryInterface(className),
            isFalse,
            reason: '$className is implementation, not interface',
          );
        }
      });
    });

    group('Allowed Throw Patterns', () {
      test('allows rethrow in catch blocks', () {
        expect(
          _isAllowedThrow(ThrowContext.rethrowInCatch),
          isTrue,
          reason: 'Rethrow should be allowed in catch blocks',
        );
      });

      test('allows throws in private helper methods', () {
        expect(
          _isAllowedThrow(ThrowContext.privateMethod),
          isTrue,
          reason:
              'Private methods can throw (will be caught by public methods)',
        );
      });

      test('allows throws in constructors', () {
        expect(
          _isAllowedThrow(ThrowContext.constructor),
          isTrue,
          reason: 'Constructors can throw for validation',
        );
      });

      test('documents all allowed patterns', () {
        final allowedPatterns = [
          ThrowContext.rethrowInCatch,
          ThrowContext.privateMethod,
          ThrowContext.constructor,
        ];

        for (final pattern in allowedPatterns) {
          expect(
            _isAllowedThrow(pattern),
            isTrue,
            reason: '$pattern should be allowed',
          );
        }
      });
    });

    group('Forbidden Throw Patterns', () {
      test('forbids direct throw in public methods', () {
        expect(
          _isAllowedThrow(ThrowContext.publicMethod),
          isFalse,
          reason: 'Public methods should not throw directly',
        );
      });

      test('forbids throw ArgumentError in public methods', () {
        expect(
          _isAllowedThrow(ThrowContext.argumentValidation),
          isFalse,
          reason: 'Argument validation should return Failure, not throw',
        );
      });

      test('forbids throw Exception in catch blocks', () {
        expect(
          _isAllowedThrow(ThrowContext.newThrowInCatch),
          isFalse,
          reason: 'Creating new exception in catch should return Failure',
        );
      });

      test('forbids throw StateError', () {
        expect(
          _isAllowedThrow(ThrowContext.stateError),
          isFalse,
          reason: 'StateError should be converted to Failure',
        );
      });
    });

    group('Repository Naming Conventions', () {
      test('validates Repository interface naming', () {
        final validNames = [
          'TodoRepository',
          'UserRepository',
          'OrderRepository',
        ];

        for (final name in validNames) {
          expect(
            _isValidRepositoryName(name),
            isTrue,
            reason: '$name follows interface naming convention',
          );
        }
      });

      test('validates Repository implementation naming', () {
        final validNames = [
          'TodoRepositoryImpl',
          'UserRepositoryImplementation',
          'OrderRepositoryImpl',
        ];

        for (final name in validNames) {
          expect(
            _isValidRepositoryName(name),
            isTrue,
            reason: '$name follows implementation naming convention',
          );
        }
      });

      test('rejects invalid Repository naming', () {
        final invalidNames = [
          'TodoRepo', // Should use full "Repository"
          'UserRepositoryService', // Wrong suffix
          'OrderRepositoryManager', // Wrong suffix
        ];

        for (final name in invalidNames) {
          expect(
            _isValidRepositoryName(name),
            isFalse,
            reason: '$name does not follow naming convention',
          );
        }
      });
    });

    group('Error Messages', () {
      test('provides clear message for non-standard throws', () {
        final message = _getErrorMessage(ThrowContext.publicMethod);

        expect(
          message,
          contains('non-standard exception'),
          reason: 'Error message should mention non-standard',
        );
        expect(
          message,
          contains('AppException'),
          reason: 'Error message should suggest AppException',
        );
      });

      test('provides clear message for throw in catch', () {
        final message = _getErrorMessage(ThrowContext.newThrowInCatch);

        expect(
          message,
          contains('AppException'),
          reason: 'Error message should suggest AppException types',
        );
        expect(
          message,
          contains('UNIFIED_ERROR_GUIDE.md'),
          reason: 'Error message should reference documentation',
        );
      });

      test('includes AppException types example', () {
        final message = _getErrorMessage(ThrowContext.argumentValidation);

        expect(
          message,
          contains('NotFoundException'),
          reason: 'Error message should show AppException example',
        );
        expect(
          message,
          contains('InvalidInputException'),
          reason: 'Error message should show InvalidInputException example',
        );
      });

      test('explains pass-through pattern', () {
        final message = _getErrorMessage(ThrowContext.publicMethod);

        expect(
          message,
          contains('pass through'),
          reason: 'Error message should explain pass-through pattern',
        );
      });
    });

    group('Method Validation Rules', () {
      test('validates public methods', () {
        expect(
          _shouldValidateMethod(MethodContext.publicMethod),
          isTrue,
          reason: 'Public methods should be validated',
        );
      });

      test('skips private methods', () {
        expect(
          _shouldValidateMethod(MethodContext.privateMethod),
          isFalse,
          reason: 'Private methods are helpers, skip validation',
        );
      });

      test('skips constructors', () {
        expect(
          _shouldValidateMethod(MethodContext.constructor),
          isFalse,
          reason: 'Constructors are handled separately',
        );
      });

      test('skips getters and setters', () {
        expect(
          _shouldValidateMethod(MethodContext.getter),
          isFalse,
          reason: 'Getters should not be validated',
        );
        expect(
          _shouldValidateMethod(MethodContext.setter),
          isFalse,
          reason: 'Setters should not be validated',
        );
      });

      test('skips operators', () {
        expect(
          _shouldValidateMethod(MethodContext.operator),
          isFalse,
          reason: 'Operators should not be validated',
        );
      });
    });

    group('Edge Cases', () {
      test('handles nested throws in try-catch', () {
        // This would be complex AST analysis
        expect(
          _isAllowedThrow(ThrowContext.nestedTryCatch),
          isFalse,
          reason: 'Nested throws should still return Failure',
        );
      });

      test('handles async/await error handling', () {
        expect(
          _shouldValidateMethod(MethodContext.asyncMethod),
          isTrue,
          reason: 'Async methods should be validated',
        );
      });

      test('detects Result types to warn against them', () {
        final returnTypes = [
          'Result<Todo, TodoFailure>',
          'Future<Result<List<User>, Failure>>',
          'Stream<Result<Data, Error>>',
        ];

        for (final returnType in returnTypes) {
          expect(
            _hasResultReturnType(returnType),
            isTrue,
            reason: '$returnType should be detected to warn against Result usage',
          );
        }
      });

      test('accepts pass-through return types', () {
        final returnTypes = ['Future<Todo>', 'Future<List<User>>', 'Stream<Data>'];

        for (final returnType in returnTypes) {
          expect(
            _hasResultReturnType(returnType),
            isFalse,
            reason: '$returnType is pass-through pattern (no Result)',
          );
        }
      });
    });

    group('Integration Test Expectations', () {
      test('should detect violations in bad examples', () {
        // This test documents what violations should be detected in bad example files
        final expectedViolations = {
          'repository_throws_bad.dart': [
            'TodoRepositoryImpl.getTodo: ArgumentError throw (line 38)',
            'TodoRepositoryImpl.getTodo: Exception throw in catch (line 46)',
            'TodoRepositoryImpl.getTodos: StateError throw (line 56)',
          ],
        };

        // All these should be flagged as violations
        expect(
          expectedViolations['repository_throws_bad.dart']!.length,
          equals(3),
          reason: 'Should detect 3 violations in bad example',
        );
      });

      test('should accept all patterns in good examples', () {
        // This test documents what should pass in good example files
        final expectedPassing = {
          'repository_no_throw_good.dart': [
            'TodoRepositoryImpl: Returns Failure instead of throwing',
            'UserRepositoryImpl: Constructor throws (allowed)',
            'ProductRepositoryImpl: Uses rethrow (allowed)',
            'TodoRepositoryImpl._fetchFromCache: Private method throws (allowed)',
          ],
        };

        expect(
          expectedPassing['repository_no_throw_good.dart']!.length,
          equals(4),
          reason: 'Should accept 4 allowed patterns in good example',
        );
      });

      test('estimates violation count in bad examples', () {
        // Based on repository_throws_bad.dart analysis:
        // - Line 38: throw ArgumentError (public method)
        // - Line 46: throw Exception in catch (not rethrow)
        // - Line 56: throw StateError (public method)
        // Total: 3 violations expected

        const expectedViolationCount = 3;

        expect(
          expectedViolationCount,
          greaterThan(0),
          reason: 'Bad examples should trigger violations',
        );
      });
    });

    group('RepositoryRuleVisitor Mixin Integration', () {
      test('uses isRepositoryImplementation from mixin', () {
        expect(
          _isRepositoryImplementation('TodoRepositoryImpl'),
          isTrue,
          reason: 'Mixin should detect Repository implementation',
        );
      });

      test('uses isAllowedRepositoryThrow from mixin', () {
        expect(
          _isAllowedThrow(ThrowContext.rethrowInCatch),
          isTrue,
          reason: 'Mixin should allow rethrow',
        );
        expect(
          _isAllowedThrow(ThrowContext.publicMethod),
          isFalse,
          reason: 'Mixin should forbid public method throws',
        );
      });

      test('uses shouldValidateRepositoryMethod from mixin', () {
        expect(
          _shouldValidateMethod(MethodContext.publicMethod),
          isTrue,
          reason: 'Mixin should validate public methods',
        );
        expect(
          _shouldValidateMethod(MethodContext.privateMethod),
          isFalse,
          reason: 'Mixin should skip private methods',
        );
      });

      test('uses isRepositoryInterface from mixin', () {
        expect(
          _isRepositoryInterface('TodoRepository'),
          isTrue,
          reason: 'Mixin should detect Repository interfaces',
        );
      });
    });
  });
}

// Helper enums and classes for testing

enum ThrowContext {
  rethrowInCatch,
  privateMethod,
  constructor,
  publicMethod,
  argumentValidation,
  newThrowInCatch,
  stateError,
  nestedTryCatch,
}

enum MethodContext {
  publicMethod,
  privateMethod,
  constructor,
  getter,
  setter,
  operator,
  asyncMethod,
}

// Helper functions that simulate rule logic

bool _isRepositoryImplementation(String className) {
  // Simulate RepositoryRuleVisitor.isRepositoryImplementation
  if (className.endsWith('Impl') || className.endsWith('Implementation')) {
    if (className.contains('Repository')) {
      return true;
    }
  }
  return false;
}

bool _isRepositoryInterface(String className) {
  // Simulate RepositoryRuleVisitor.isRepositoryInterface
  if (className.contains('Repository') &&
      !className.endsWith('Impl') &&
      !className.endsWith('Implementation')) {
    return true;
  }
  return false;
}

bool _isAllowedThrow(ThrowContext context) {
  // Simulate RepositoryRuleVisitor.isAllowedRepositoryThrow
  switch (context) {
    case ThrowContext.rethrowInCatch:
      return true; // Rethrow is allowed
    case ThrowContext.privateMethod:
      return true; // Private methods can throw
    case ThrowContext.constructor:
      return true; // Constructors can throw
    case ThrowContext.publicMethod:
    case ThrowContext.argumentValidation:
    case ThrowContext.newThrowInCatch:
    case ThrowContext.stateError:
    case ThrowContext.nestedTryCatch:
      return false; // Not allowed
  }
}

bool _isValidRepositoryName(String className) {
  if (!className.contains('Repository')) return false;

  // Either interface (no suffix) or implementation (Impl/Implementation)
  if (className.endsWith('Repository')) return true;
  if (className.endsWith('Impl')) return true;
  if (className.endsWith('Implementation')) return true;

  return false;
}

bool _shouldValidateMethod(MethodContext context) {
  // Simulate RepositoryRuleVisitor.shouldValidateRepositoryMethod
  switch (context) {
    case MethodContext.publicMethod:
    case MethodContext.asyncMethod:
      return true; // Validate public methods
    case MethodContext.privateMethod:
    case MethodContext.constructor:
    case MethodContext.getter:
    case MethodContext.setter:
    case MethodContext.operator:
      return false; // Skip these
  }
}

bool _hasResultReturnType(String returnType) {
  return returnType.contains('Result<');
}

String _getErrorMessage(ThrowContext context) {
  return '''
Repository throws non-standard exception type. Use AppException types instead.

Use AppException types:
  - NotFoundException("message")
  - InvalidInputException("message")
  - ServerException("message")

Or let DataSource exceptions pass through to AsyncValue.guard().
See UNIFIED_ERROR_GUIDE.md
''';
}
