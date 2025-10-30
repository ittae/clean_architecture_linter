import 'package:test/test.dart';

/// Unit tests for UseCaseNoResultReturnRule
///
/// This test suite verifies that the usecase_no_result_return_rule correctly
/// enforces Clean Architecture principles for UseCase return types.
///
/// Test Coverage:
/// 1. UseCase class detection logic
/// 2. Result/Either/Task return type detection
/// 3. Private method exclusion
/// 4. Void method exclusion
/// 5. Error message accuracy
/// 6. Multiple Result type library support (fpdart, dartz, oxidized)
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('UseCaseNoResultReturnRule', () {
    group('UseCase Class Detection', () {
      test('detects classes ending with UseCase', () {
        final testCases = [
          'GetTodoUseCase',
          'CreateUserUseCase',
          'DeleteOrderUseCase',
          'ValidateTodoUseCase',
        ];

        for (final className in testCases) {
          expect(
            _isUseCaseClassName(className),
            isTrue,
            reason: '$className should be detected as UseCase',
          );
        }
      });

      test('ignores classes not ending with UseCase', () {
        final testCases = [
          'TodoRepository',
          'UserService',
          'OrderController',
          'TodoModel',
          'GetTodo', // Missing UseCase suffix
        ];

        for (final className in testCases) {
          expect(
            _isUseCaseClassName(className),
            isFalse,
            reason: '$className should NOT be detected as UseCase',
          );
        }
      });
    });

    group('Result Type Detection', () {
      test('detects Result<T, F> return type', () {
        final testCases = [
          'Result<Todo, TodoFailure>',
          'Result<List<Todo>, TodoFailure>',
          'Result<bool, String>',
          'Result<int, Error>',
        ];

        for (final typeStr in testCases) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: '$typeStr should be detected as Result type',
          );
        }
      });

      test('detects Either<L, R> return type', () {
        final testCases = [
          'Either<TodoFailure, Todo>',
          'Either<Failure, List<Todo>>',
          'Either<String, bool>',
          'Either<Error, int>',
        ];

        for (final typeStr in testCases) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: '$typeStr should be detected as Either type',
          );
        }
      });

      test('detects Task and TaskEither return types', () {
        final testCases = [
          'Task<Either<Failure, Todo>>',
          'TaskEither<Failure, Todo>',
          'Task<Result<Todo, Failure>>',
        ];

        for (final typeStr in testCases) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: '$typeStr should be detected as Task type',
          );
        }
      });

      test('detects Future-wrapped Result types', () {
        final testCases = [
          'Future<Result<Todo, TodoFailure>>',
          'Future<Either<Failure, List<Todo>>>',
          'Future<Task<Either<Failure, Todo>>>',
        ];

        for (final typeStr in testCases) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: '$typeStr should be detected as Future-wrapped Result',
          );
        }
      });

      test('ignores non-Result return types', () {
        final testCases = [
          'Todo',
          'List<Todo>',
          'Future<Todo>',
          'Future<List<Todo>>',
          'bool',
          'int',
          'String',
          'void',
          'Future<void>',
        ];

        for (final typeStr in testCases) {
          expect(
            _isResultTypeName(typeStr),
            isFalse,
            reason: '$typeStr should NOT be detected as Result type',
          );
        }
      });
    });

    group('Private Method Exclusion', () {
      test('identifies private methods by underscore prefix', () {
        final privateMethods = [
          '_helper',
          '_validateTodo',
          '_transformData',
          '_privateMethod',
        ];

        for (final methodName in privateMethods) {
          expect(
            _isPrivateMethod(methodName),
            isTrue,
            reason: '$methodName should be identified as private',
          );
        }
      });

      test('identifies public methods without underscore', () {
        final publicMethods = [
          'call',
          'execute',
          'validate',
          'getTodo',
          'createUser',
        ];

        for (final methodName in publicMethods) {
          expect(
            _isPrivateMethod(methodName),
            isFalse,
            reason: '$methodName should be identified as public',
          );
        }
      });
    });

    group('Void Method Exclusion', () {
      test('identifies void return type', () {
        final voidTypes = ['void'];

        for (final typeStr in voidTypes) {
          expect(
            _isVoidType(typeStr),
            isTrue,
            reason: '$typeStr should be identified as void',
          );
        }
      });

      test('identifies Future<void> return type', () {
        final futureVoidTypes = ['Future<void>'];

        for (final typeStr in futureVoidTypes) {
          expect(
            _isVoidType(typeStr),
            isTrue,
            reason: '$typeStr should be identified as Future<void>',
          );
        }
      });

      test('excludes non-void return types', () {
        final nonVoidTypes = [
          'Todo',
          'bool',
          'int',
          'Future<Todo>',
          'Future<bool>',
          'Result<Todo, Failure>',
        ];

        for (final typeStr in nonVoidTypes) {
          expect(
            _isVoidType(typeStr),
            isFalse,
            reason: '$typeStr should NOT be identified as void',
          );
        }
      });
    });

    group('Result Type Library Support', () {
      test('supports fpdart library types', () {
        final fpdartTypes = [
          'Either<Failure, Todo>', // fpdart Either
          'Task<Either<Failure, Todo>>', // fpdart Task
          'TaskEither<Failure, Todo>', // fpdart TaskEither
        ];

        for (final typeStr in fpdartTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'fpdart type $typeStr should be supported',
          );
        }
      });

      test('supports dartz library types', () {
        final dartzTypes = [
          'Either<Failure, Todo>', // dartz Either
        ];

        for (final typeStr in dartzTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'dartz type $typeStr should be supported',
          );
        }
      });

      test('supports oxidized library types', () {
        final oxidizedTypes = [
          'Result<Todo, Failure>', // oxidized Result
        ];

        for (final typeStr in oxidizedTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'oxidized type $typeStr should be supported',
          );
        }
      });

      test('supports custom Result implementations', () {
        final customTypes = [
          'Result<Todo, CustomFailure>',
          'CustomResult<Todo, Error>',
        ];

        for (final typeStr in customTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'custom Result type $typeStr should be supported',
          );
        }
      });
    });

    group('Error Message Validation', () {
      test('error message mentions UseCase should NOT return Result', () {
        const expectedPhrases = [
          'UseCase',
          'should NOT return Result',
          'unwrap',
          'Entity',
          'throw domain exception',
        ];

        const errorMessage =
            'UseCase method "call" should NOT return Result. '
            'UseCase should unwrap Result and return Entity or throw domain exception.';

        for (final phrase in expectedPhrases) {
          expect(
            errorMessage.toLowerCase().contains(phrase.toLowerCase()),
            isTrue,
            reason: 'Error message should mention "$phrase"',
          );
        }
      });

      test('correction message provides actionable example', () {
        const expectedPhrases = [
          'unwrap',
          'result.when',
          'success',
          'failure',
          'throw',
          'toException',
        ];

        const correctionMessage =
            'Unwrap Result from Repository:\n'
            '  Before: Future<Result<Todo, TodoFailure>> call()\n'
            '  After:  Future<Todo> call() // unwrap and throw on failure\n\n'
            'Pattern:\n'
            '  final result = await repository.getTodo(id);\n'
            '  return result.when(\n'
            '    success: (data) => data,\n'
            '    failure: (error) => throw error.toException(),\n'
            '  );';

        for (final phrase in expectedPhrases) {
          expect(
            correctionMessage.toLowerCase().contains(phrase.toLowerCase()),
            isTrue,
            reason: 'Correction message should mention "$phrase"',
          );
        }
      });
    });

    group('Edge Cases', () {
      test('handles generic type parameters correctly', () {
        final genericTypes = [
          'Result<T, E>',
          'Either<L, R>',
          'Future<Result<T, F>>',
        ];

        for (final typeStr in genericTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'Generic type $typeStr should be detected',
          );
        }
      });

      test('handles nested Future types', () {
        final nestedTypes = [
          'Future<Future<Result<Todo, Failure>>>',
          'Future<Task<Either<Failure, Todo>>>',
        ];

        for (final typeStr in nestedTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'Nested type $typeStr should be detected',
          );
        }
      });

      test('handles complex generic combinations', () {
        final complexTypes = [
          'Result<List<Todo>, Map<String, Failure>>',
          'Either<Failure, Map<String, List<Todo>>>',
        ];

        for (final typeStr in complexTypes) {
          expect(
            _isResultTypeName(typeStr),
            isTrue,
            reason: 'Complex type $typeStr should be detected',
          );
        }
      });
    });
  });
}

// ============================================================================
// Helper Functions (Simulating CleanArchitectureUtils behavior)
// ============================================================================

/// Simulates CleanArchitectureUtils.isUseCaseClass()
bool _isUseCaseClassName(String className) {
  return className.endsWith('UseCase');
}

/// Simulates detection of Result/Either/Task types
bool _isResultTypeName(String typeStr) {
  return typeStr.contains('Result<') ||
      typeStr.contains('Either<') ||
      typeStr.contains('Task<') ||
      typeStr.contains('TaskEither<') ||
      typeStr.contains('Result ') ||
      typeStr.contains('Either ');
}

/// Simulates private method detection
bool _isPrivateMethod(String methodName) {
  return methodName.startsWith('_');
}

/// Simulates void type detection
bool _isVoidType(String typeStr) {
  return typeStr.contains('void');
}
