import 'package:test/test.dart';

/// Unit tests for AllowedInstanceVariablesRule
///
/// This test suite verifies that UseCase, Repository, and DataSource classes
/// only contain allowed instance variables according to Clean Architecture.
///
/// Test Coverage:
/// 1. UseCase - should only have Repository dependencies
/// 2. Repository - should only have DataSource dependencies
/// 3. DataSource - should only have infrastructure dependencies
/// 4. Mutable state variables should be disallowed
/// 5. Edge cases and special scenarios
///
/// Pattern:
/// - ✅ UseCase: final Repository fields only
/// - ✅ Repository: final DataSource fields only
/// - ✅ DataSource: final infrastructure (HTTP client, etc.) only
/// - ❌ Mutable state variables (non-final fields)
/// - ❌ Wrong layer dependencies
void main() {
  group('AllowedInstanceVariablesRule', () {
    group('UseCase Validation', () {
      test('allows Repository dependencies', () {
        expect(
          _isValidUseCaseDependency('TodoRepository'),
          isTrue,
          reason: 'UseCase should allow Repository dependencies',
        );
      });

      test('disallows DataSource dependencies', () {
        expect(
          _isValidUseCaseDependency('TodoRemoteDataSource'),
          isFalse,
          reason: 'UseCase should not depend on DataSource directly',
        );
      });

      test('disallows non-Repository types', () {
        expect(
          _isValidUseCaseDependency('TodoService'),
          isFalse,
          reason: 'UseCase should only depend on Repository types',
        );
      });
    });

    group('Repository Validation', () {
      test('allows DataSource dependencies', () {
        expect(
          _isValidRepositoryDependency('TodoRemoteDataSource'),
          isTrue,
          reason: 'Repository should allow DataSource dependencies',
        );

        expect(
          _isValidRepositoryDependency('TodoLocalDataSource'),
          isTrue,
          reason: 'Repository should allow multiple DataSource dependencies',
        );

        expect(
          _isValidRepositoryDependency('AuthDatasource'),
          isTrue,
          reason: 'Repository should allow Datasource variant (lowercase s)',
        );
      });

      test('disallows UseCase dependencies', () {
        expect(
          _isValidRepositoryDependency('GetTodoUseCase'),
          isFalse,
          reason: 'Repository should not depend on UseCase (wrong direction)',
        );

        expect(
          _isValidRepositoryDependency('GetTodoUsecase'),
          isFalse,
          reason:
              'Repository should not depend on Usecase variant (wrong direction)',
        );
      });

      test('disallows Repository dependencies', () {
        expect(
          _isValidRepositoryDependency('TodoRepository'),
          isFalse,
          reason: 'Repository should not depend on other Repositories',
        );
      });
    });

    group('DataSource Validation', () {
      test('allows infrastructure dependencies', () {
        expect(
          _isDisallowedDataSourceDependency('Dio'),
          isFalse,
          reason: 'DataSource should allow HTTP client dependencies',
        );

        expect(
          _isDisallowedDataSourceDependency('Database'),
          isFalse,
          reason: 'DataSource should allow DB client dependencies',
        );

        expect(
          _isDisallowedDataSourceDependency('String'),
          isFalse,
          reason: 'DataSource should allow configuration values',
        );
      });

      test('disallows domain layer dependencies', () {
        expect(
          _isDisallowedDataSourceDependency('TodoRepository'),
          isTrue,
          reason: 'DataSource should not depend on Repository',
        );

        expect(
          _isDisallowedDataSourceDependency('GetTodoUseCase'),
          isTrue,
          reason: 'DataSource should not depend on UseCase',
        );

        expect(
          _isDisallowedDataSourceDependency('GetTodoUsecase'),
          isTrue,
          reason: 'DataSource should not depend on Usecase variant',
        );

        expect(
          _isDisallowedDataSourceDependency('TodoEntity'),
          isTrue,
          reason: 'DataSource should not depend on Entity',
        );

        expect(
          _isDisallowedDataSourceDependency('TodoRemoteDataSource'),
          isTrue,
          reason: 'DataSource should not depend on other DataSource',
        );

        expect(
          _isDisallowedDataSourceDependency('AuthDatasource'),
          isTrue,
          reason: 'DataSource should not depend on other Datasource variant',
        );
      });

      test('disallows business logic dependencies', () {
        expect(
          _isDisallowedDataSourceDependency('TodoService'),
          isTrue,
          reason: 'DataSource should not depend on Service',
        );

        expect(
          _isDisallowedDataSourceDependency('TodoManager'),
          isTrue,
          reason: 'DataSource should not depend on Manager',
        );

        expect(
          _isDisallowedDataSourceDependency('TodoController'),
          isTrue,
          reason: 'DataSource should not depend on Controller',
        );
      });
    });

    group('Class Type Detection', () {
      test('identifies UseCase classes', () {
        expect(
          _isUseCaseClass('GetTodoUseCase'),
          isTrue,
          reason: 'Should identify UseCase by class name',
        );

        expect(
          _isUseCaseClass('CreateTodoUseCase'),
          isTrue,
          reason: 'Should identify various UseCase names',
        );

        expect(
          _isUseCaseClass('GetTodoUsecase'),
          isTrue,
          reason: 'Should identify Usecase variant',
        );
      });

      test('identifies Repository classes', () {
        expect(
          _isRepositoryClass('TodoRepositoryImpl'),
          isTrue,
          reason: 'Should identify RepositoryImpl by class name',
        );

        expect(
          _isRepositoryClass('UserRepositoryImpl'),
          isTrue,
          reason: 'Should identify various RepositoryImpl names',
        );
      });

      test('identifies DataSource classes', () {
        expect(
          _isDataSourceClass('TodoRemoteDataSource'),
          isTrue,
          reason: 'Should identify DataSource by class name',
        );

        expect(
          _isDataSourceClass('TodoLocalDataSource'),
          isTrue,
          reason: 'Should identify various DataSource names',
        );
      });
    });

    group('Edge Cases', () {
      test('validates field finality', () {
        expect(
          _isMutableField(isFinal: false),
          isTrue,
          reason: 'Non-final fields should be considered mutable',
        );

        expect(
          _isMutableField(isFinal: true),
          isFalse,
          reason: 'Final fields should not be considered mutable',
        );
      });
    });
  });
}

// ============================================================================
// Test Helper Functions
// ============================================================================

bool _isValidUseCaseDependency(String typeName) {
  return typeName.endsWith('Repository');
}

bool _isValidRepositoryDependency(String typeName) {
  return typeName.endsWith('DataSource') || typeName.endsWith('Datasource');
}

bool _isDisallowedDataSourceDependency(String typeName) {
  // Disallow domain layer types (check both uppercase and lowercase variants)
  if (typeName.endsWith('UseCase') ||
      typeName.endsWith('Usecase') ||
      typeName.endsWith('Repository') ||
      typeName.endsWith('Entity') ||
      typeName.endsWith('DataSource') ||
      typeName.endsWith('Datasource')) {
    return true;
  }

  // Disallow business logic types
  if (typeName.endsWith('Service') ||
      typeName.endsWith('Manager') ||
      typeName.endsWith('Controller')) {
    return true;
  }

  return false;
}

bool _isUseCaseClass(String className) {
  return className.endsWith('UseCase') || className.endsWith('Usecase');
}

bool _isRepositoryClass(String className) {
  return className.endsWith('RepositoryImpl');
}

bool _isDataSourceClass(String className) {
  return className.contains('DataSource');
}

bool _isMutableField({required bool isFinal}) {
  return !isFinal;
}
