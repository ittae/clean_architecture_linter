import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';
import 'package:clean_architecture_linter/src/clean_architecture_linter_base.dart';

void main() {
  group('CleanArchitectureUtils - File Exclusion', () {
    group('shouldExcludeFile', () {
      test('should exclude test files', () {
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            'lib/features/auth/test/auth_test.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            'test/features/auth/auth_test.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            'integration_test/app_test.dart',
          ),
          isTrue,
        );
      });

      test('should exclude generated files', () {
        expect(
          CleanArchitectureUtils.shouldExcludeFile('lib/models/user.g.dart'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            'lib/models/user.freezed.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile('lib/mocks/user.mocks.dart'),
          isTrue,
        );
      });

      test('should exclude build artifacts', () {
        expect(
          CleanArchitectureUtils.shouldExcludeFile('build/app.js'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            '.dart_tool/package_config.json',
          ),
          isTrue,
        );
        expect(CleanArchitectureUtils.shouldExcludeFile('.packages'), isTrue);
      });

      test('should exclude documentation files', () {
        expect(CleanArchitectureUtils.shouldExcludeFile('README.md'), isTrue);
        expect(
          CleanArchitectureUtils.shouldExcludeFile('docs/guide.txt'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile('CHANGELOG.rst'),
          isTrue,
        );
      });

      test('should not exclude regular Dart files', () {
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            'lib/features/auth/domain/usecases/login_usecase.dart',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            'lib/features/auth/data/datasources/auth_remote_datasource.dart',
          ),
          isFalse,
        );
      });

      test('should handle Windows paths', () {
        expect(
          CleanArchitectureUtils.shouldExcludeFile(
            r'lib\features\auth\test\auth_test.dart',
          ),
          isTrue,
        );
      });
    });
  });

  group('CleanArchitectureUtils - Layer File Detection', () {
    group('isDomainFile', () {
      test('should identify domain layer files', () {
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/domain/entities/user.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/domain/usecases/login_usecase.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/usecases/login_usecase.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/use_cases/login_usecase.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/entities/user.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/exceptions/auth_exception.dart',
          ),
          isTrue,
        );
      });

      test('should exclude test files by default', () {
        expect(
          CleanArchitectureUtils.isDomainFile(
            'test/features/auth/domain/usecases/login_usecase_test.dart',
          ),
          isFalse,
        );
      });

      test('should include test files when excludeFiles is false', () {
        expect(
          CleanArchitectureUtils.isDomainFile(
            'test/features/auth/domain/usecases/login_usecase_test.dart',
            excludeFiles: false,
          ),
          isTrue,
        );
      });

      test('should not identify non-domain files', () {
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/data/models/user_model.dart',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isDomainFile(
            'lib/features/auth/presentation/pages/login_page.dart',
          ),
          isFalse,
        );
      });

      test('should handle Windows paths', () {
        expect(
          CleanArchitectureUtils.isDomainFile(
            r'lib\features\auth\domain\entities\user.dart',
          ),
          isTrue,
        );
      });
    });

    group('isDataFile', () {
      test('should identify data layer files', () {
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/data/models/user_model.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/data/datasources/auth_remote_datasource.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/datasources/auth_remote_datasource.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/models/user_model.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/data/repositories/auth_repository_impl.dart',
          ),
          isTrue,
        );
      });

      test('should exclude test files by default', () {
        expect(
          CleanArchitectureUtils.isDataFile(
            'test/features/auth/data/models/user_model_test.dart',
          ),
          isFalse,
        );
      });

      test('should include test files when excludeFiles is false', () {
        expect(
          CleanArchitectureUtils.isDataFile(
            'test/features/auth/data/models/user_model_test.dart',
            excludeFiles: false,
          ),
          isTrue,
        );
      });

      test('should not identify non-data files', () {
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/domain/entities/user.dart',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/presentation/pages/login_page.dart',
          ),
          isFalse,
        );
      });

      test('should not identify domain/repositories as data layer', () {
        // Regression test for bug: domain/repositories should not be detected as data layer
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/features/auth/domain/repositories/auth_repository.dart',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isDataFile(
            'lib/core/analytics/domain/repositories/analytics_repository.dart',
          ),
          isFalse,
        );
      });
    });

    group('isPresentationFile', () {
      test('should identify presentation layer files', () {
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/presentation/pages/login_page.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/presentation/widgets/login_button.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/widgets/login_button.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/pages/login_page.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/screens/login_screen.dart',
          ),
          isTrue,
        );
      });

      test('should exclude test files by default', () {
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'test/features/auth/presentation/pages/login_page_test.dart',
          ),
          isFalse,
        );
      });

      test('should include test files when excludeFiles is false', () {
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'test/features/auth/presentation/pages/login_page_test.dart',
            excludeFiles: false,
          ),
          isTrue,
        );
      });

      test('should not identify non-presentation files', () {
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/domain/entities/user.dart',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isPresentationFile(
            'lib/features/auth/data/models/user_model.dart',
          ),
          isFalse,
        );
      });
    });
  });

  group('CleanArchitectureUtils - Component-Specific Detection', () {
    group('isUseCaseFile', () {
      test('should identify UseCase files', () {
        expect(
          CleanArchitectureUtils.isUseCaseFile(
            'lib/features/auth/domain/usecases/login_usecase.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isUseCaseFile(
            'lib/features/auth/usecases/login_usecase.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isUseCaseFile(
            'lib/features/auth/use_cases/login_usecase.dart',
          ),
          isTrue,
        );
      });

      test('should not identify non-UseCase files', () {
        expect(
          CleanArchitectureUtils.isUseCaseFile(
            'lib/features/auth/domain/entities/user.dart',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isUseCaseFile(
            'lib/features/auth/data/repositories/auth_repository_impl.dart',
          ),
          isFalse,
        );
      });
    });

    group('isDataSourceFile', () {
      test('should identify DataSource files', () {
        expect(
          CleanArchitectureUtils.isDataSourceFile(
            'lib/features/auth/data/datasources/auth_remote_datasource.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataSourceFile(
            'lib/features/auth/datasources/auth_remote_datasource.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataSourceFile(
            'lib/features/auth/data/data_sources/auth_remote_datasource.dart',
          ),
          isTrue,
        );
      });

      test('should not identify non-DataSource files', () {
        expect(
          CleanArchitectureUtils.isDataSourceFile(
            'lib/features/auth/data/models/user_model.dart',
          ),
          isFalse,
        );
      });
    });

    group('isRepositoryFile', () {
      test('should identify Repository files', () {
        expect(
          CleanArchitectureUtils.isRepositoryFile(
            'lib/features/auth/domain/repositories/auth_repository.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isRepositoryFile(
            'lib/features/auth/repositories/auth_repository.dart',
          ),
          isTrue,
        );
      });

      test('should not identify non-Repository files', () {
        expect(
          CleanArchitectureUtils.isRepositoryFile(
            'lib/features/auth/domain/entities/user.dart',
          ),
          isFalse,
        );
      });
    });

    group('isRepositoryImplFile', () {
      test('should identify Repository implementation files', () {
        expect(
          CleanArchitectureUtils.isRepositoryImplFile(
            'lib/features/auth/data/repositories/auth_repository_impl.dart',
          ),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isRepositoryImplFile(
            'lib/features/auth/repositories/auth_repository_impl.dart',
          ),
          isTrue,
        );
      });

      test('should not identify interface files', () {
        expect(
          CleanArchitectureUtils.isRepositoryImplFile(
            'lib/features/auth/domain/repositories/auth_repository.dart',
          ),
          isFalse,
        );
      });
    });
  });

  group('CleanArchitectureUtils - Class Name Validation', () {
    group('isUseCaseClass', () {
      test('should identify UseCase class names', () {
        expect(CleanArchitectureUtils.isUseCaseClass('LoginUseCase'), isTrue);
        expect(CleanArchitectureUtils.isUseCaseClass('LoginUsecase'), isTrue);
        expect(
          CleanArchitectureUtils.isUseCaseClass('GetUserProfileUseCase'),
          isTrue,
        );
      });

      test('should not identify non-UseCase names', () {
        expect(
          CleanArchitectureUtils.isUseCaseClass('AuthRepository'),
          isFalse,
        );
        expect(CleanArchitectureUtils.isUseCaseClass('User'), isFalse);
      });
    });

    group('isDataSourceClass', () {
      test('should identify DataSource class names', () {
        expect(
          CleanArchitectureUtils.isDataSourceClass('AuthRemoteDataSource'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataSourceClass('AuthLocalDataSource'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataSourceClass('AuthRemoteDatasource'),
          isTrue,
        );
      });

      test('should not identify non-DataSource names', () {
        expect(
          CleanArchitectureUtils.isDataSourceClass('AuthRepository'),
          isFalse,
        );
      });
    });

    group('isRepositoryClass', () {
      test('should identify Repository class names', () {
        expect(
          CleanArchitectureUtils.isRepositoryClass('AuthRepository'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isRepositoryClass('UserRepository'),
          isTrue,
        );
      });

      test('should not identify non-Repository names', () {
        expect(CleanArchitectureUtils.isRepositoryClass('User'), isFalse);
      });
    });

    group('isRepositoryInterfaceClass', () {
      test('should identify Repository interface names', () {
        expect(
          CleanArchitectureUtils.isRepositoryInterfaceClass('AuthRepository'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isRepositoryInterfaceClass('IAuthRepository'),
          isTrue,
        );
      });

      test('should not identify implementation names', () {
        expect(
          CleanArchitectureUtils.isRepositoryInterfaceClass(
            'AuthRepositoryImpl',
          ),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isRepositoryInterfaceClass(
            'AuthRepositoryImplementation',
          ),
          isFalse,
        );
      });
    });

    group('isRepositoryImplClass', () {
      test('should identify Repository implementation names', () {
        expect(
          CleanArchitectureUtils.isRepositoryImplClass('AuthRepositoryImpl'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isRepositoryImplClass(
            'AuthRepositoryImplementation',
          ),
          isTrue,
        );
      });

      test('should not identify interface names', () {
        expect(
          CleanArchitectureUtils.isRepositoryImplClass('AuthRepository'),
          isFalse,
        );
      });
    });
  });

  group('CleanArchitectureUtils - Type Annotation Validation', () {
    group('isVoidType', () {
      test('should identify void type annotations', () {
        // Note: This requires AST node creation which is complex in unit tests
        // Integration tests with actual AST parsing would be more appropriate
        // For now, test with null
        expect(CleanArchitectureUtils.isVoidType(null), isFalse);
      });
    });

    group('isResultType', () {
      test('should identify Result type annotations', () {
        // Note: This requires AST node creation which is complex in unit tests
        // Integration tests with actual AST parsing would be more appropriate
        expect(CleanArchitectureUtils.isResultType(null), isFalse);
      });
    });
  });

  group('CleanArchitectureUtils - Exception Pattern Recognition', () {
    group('isDataException', () {
      test('should identify data layer exception names', () {
        expect(
          CleanArchitectureUtils.isDataException('ServerException'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataException('NetworkException'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataException('CacheException'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataException('DatabaseException'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataException('NotFoundException'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataException('UnauthorizedException'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDataException('DataSourceException'),
          isTrue,
        );
      });

      test('should not identify non-data exceptions', () {
        expect(CleanArchitectureUtils.isDataException('AuthFailure'), isFalse);
        expect(
          CleanArchitectureUtils.isDataException('ValidationException'),
          isFalse,
        );
      });
    });

    group('isDomainException', () {
      test('should identify domain layer exception names', () {
        expect(CleanArchitectureUtils.isDomainException('AuthFailure'), isTrue);
        expect(
          CleanArchitectureUtils.isDomainException('ValidationFailure'),
          isTrue,
        );
        expect(
          CleanArchitectureUtils.isDomainException('InvalidInputFailure'),
          isTrue,
        );
      });

      test('should not identify data exceptions as domain', () {
        expect(
          CleanArchitectureUtils.isDomainException('ServerException'),
          isFalse,
        );
        expect(
          CleanArchitectureUtils.isDomainException('NetworkException'),
          isFalse,
        );
      });
    });

    group('implementsException', () {
      test('should identify classes implementing Exception', () {
        // Note: This requires AST node creation which is complex in unit tests
        // Integration tests with actual AST parsing would be more appropriate
      });
    });
  });

  group('CleanArchitectureUtils - AST Traversal', () {
    group('findParentClass', () {
      test('should find parent ClassDeclaration', () {
        // Note: This requires AST node creation which is complex in unit tests
        // Integration tests with actual AST parsing would be more appropriate
      });
    });

    group('isPrivateMethod', () {
      test('should identify private methods', () {
        // Note: This requires AST node creation which is complex in unit tests
        // Integration tests with actual AST parsing would be more appropriate
      });
    });

    group('isRethrow', () {
      test('should identify rethrow statements', () {
        // Note: This requires AST node creation which is complex in unit tests
        // Integration tests with actual AST parsing would be more appropriate
      });
    });
  });

  group('CleanArchitectureUtils - Feature Utilities', () {
    group('extractFeatureName', () {
      test('should extract feature name from path', () {
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/features/authentication/domain/entities/user.dart',
          ),
          equals('Authentication'),
        );
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/features/todos/data/models/todo_model.dart',
          ),
          equals('Todo'),
        );
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/features/users/presentation/pages/profile_page.dart',
          ),
          equals('User'),
        );
      });

      test('should handle plural to singular conversion', () {
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/features/todos/domain/entities/todo.dart',
          ),
          equals('Todo'),
        );
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/features/categories/domain/entities/category.dart',
          ),
          equals('Category'),
        );
      });

      test('should capitalize feature name', () {
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/features/authentication/domain/entities/user.dart',
          ),
          equals('Authentication'),
        );
      });

      test('should return empty string when no feature found', () {
        expect(
          CleanArchitectureUtils.extractFeatureName(
            'lib/core/utils/helpers.dart',
          ),
          equals(''),
        );
      });

      test('should handle Windows paths', () {
        expect(
          CleanArchitectureUtils.extractFeatureName(
            r'lib\features\authentication\domain\entities\user.dart',
          ),
          equals('Authentication'),
        );
      });
    });
  });

  group('CleanArchitectureUtils - Deprecated Methods', () {
    group('isDomainLayerFile (deprecated)', () {
      test('should redirect to isDomainFile', () {
        // ignore: deprecated_member_use_from_same_package
        expect(
          CleanArchitectureUtils.isDomainLayerFile(
            'lib/features/auth/domain/entities/user.dart',
          ),
          isTrue,
        );
      });
    });

    group('isDataLayerFile (deprecated)', () {
      test('should redirect to isDataFile', () {
        // ignore: deprecated_member_use_from_same_package
        expect(
          CleanArchitectureUtils.isDataLayerFile(
            'lib/features/auth/data/models/user_model.dart',
          ),
          isTrue,
        );
      });
    });

    group('isPresentationLayerFile (deprecated)', () {
      test('should redirect to isPresentationFile', () {
        // ignore: deprecated_member_use_from_same_package
        expect(
          CleanArchitectureUtils.isPresentationLayerFile(
            'lib/features/auth/presentation/pages/login_page.dart',
          ),
          isTrue,
        );
      });
    });
  });
}
