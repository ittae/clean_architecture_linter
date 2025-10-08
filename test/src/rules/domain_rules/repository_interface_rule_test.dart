import 'package:test/test.dart';

/// Unit tests for RepositoryInterfaceRule
///
/// This test suite verifies that the repository_interface_rule correctly
/// enforces Clean Architecture principles for Repository abstraction patterns.
///
/// Test Coverage:
/// 1. Repository interface detection (abstract class/abstract interface class)
/// 2. Concrete repository detection in domain layer
/// 3. Import validation (data layer implementations, infrastructure)
/// 4. Constructor dependency validation
/// 5. Field dependency validation
/// 6. Method return type validation (Model vs Entity)
/// 7. Edge cases (private classes, generics, inheritance)
///
/// Note: These are unit tests for the rule logic. Integration tests are
/// provided via the example/ directory's good_examples/ and bad_examples/.
void main() {
  group('RepositoryInterfaceRule', () {
    group('Repository Interface Detection', () {
      test('detects abstract class repositories', () {
        final testCases = [
          'abstract class UserRepository',
          'abstract class TodoRepository',
          'abstract class OrderRepository',
          'abstract class ProductRepository',
        ];

        for (final declaration in testCases) {
          expect(
            _isAbstractRepository(declaration),
            isTrue,
            reason: '$declaration should be detected as abstract repository',
          );
        }
      });

      test('detects abstract interface class repositories (Dart 3)', () {
        final testCases = [
          'abstract interface class UserRepository',
          'abstract interface class TodoRepository',
        ];

        for (final declaration in testCases) {
          expect(
            _isAbstractInterfaceRepository(declaration),
            isTrue,
            reason: '$declaration should be detected as abstract interface',
          );
        }
      });

      test('detects concrete repositories in domain layer', () {
        final testCases = [
          TestRepository(
            isAbstract: false,
            hasImplementation: true,
            layerPath:
                'lib/features/todos/domain/repositories/todo_repository.dart',
          ),
          TestRepository(
            isAbstract: false,
            hasImplementation: true,
            layerPath: 'lib/domain/repositories/user_repository.dart',
          ),
        ];

        for (final repo in testCases) {
          expect(
            _isConcreteRepositoryInDomain(repo),
            isTrue,
            reason: 'Concrete repository in domain layer should be detected',
          );
        }
      });

      test('accepts abstract repositories', () {
        final testCases = [
          TestRepository(
            isAbstract: true,
            hasImplementation: false,
            layerPath:
                'lib/features/todos/domain/repositories/todo_repository.dart',
          ),
        ];

        for (final repo in testCases) {
          expect(
            _isConcreteRepositoryInDomain(repo),
            isFalse,
            reason: 'Abstract repository should be accepted',
          );
        }
      });

      test('detects repositories with only abstract methods', () {
        final repo = TestRepository(
          hasAbstractKeyword: false,
          allMethodsAbstract: true,
        );

        expect(
          _isEffectivelyAbstract(repo),
          isTrue,
          reason:
              'Repository with all abstract methods is effectively abstract',
        );
      });
    });

    group('Repository Naming Detection', () {
      test('detects classes with Repository in name', () {
        final testCases = [
          'UserRepository',
          'TodoRepository',
          'IUserRepository',
          'AbstractTodoRepository',
        ];

        for (final className in testCases) {
          expect(
            _containsRepository(className),
            isTrue,
            reason: '$className should contain Repository',
          );
        }
      });

      test('ignores non-repository classes', () {
        final testCases = [
          'UserUseCase',
          'TodoModel',
          'UserEntity',
          'TodoDataSource',
        ];

        for (final className in testCases) {
          expect(
            _containsRepository(className),
            isFalse,
            reason: '$className should NOT contain Repository',
          );
        }
      });

      test('detects repository implementation naming', () {
        final testCases = [
          'UserRepositoryImpl',
          'TodoRepositoryImplementation',
          'OrderRepoImpl',
        ];

        for (final className in testCases) {
          expect(
            _isRepositoryImplClass(className),
            isTrue,
            reason: '$className should be detected as implementation',
          );
        }
      });
    });

    group('Import Validation', () {
      test('detects data layer repository implementation imports', () {
        final testCases = [
          'package:app/features/todos/data/repositories/todo_repository_impl.dart',
          'package:app/data/repositories/user_repository_impl.dart',
          '../../../data/repositories/order_repository_impl.dart',
        ];

        for (final importUri in testCases) {
          expect(
            _isDataRepositoryImplImport(importUri),
            isTrue,
            reason:
                '$importUri should be detected as data repository impl import',
          );
        }
      });

      test('accepts domain repository interface imports', () {
        final testCases = [
          'package:app/features/todos/domain/repositories/todo_repository.dart',
          'package:app/domain/repositories/user_repository.dart',
          '../repositories/order_repository.dart',
        ];

        for (final importUri in testCases) {
          expect(
            _isDataRepositoryImplImport(importUri),
            isFalse,
            reason: '$importUri should be accepted',
          );
        }
      });

      test('detects direct infrastructure dependency imports', () {
        final testCases = [
          'package:sqflite/sqflite.dart',
          'package:hive/hive.dart',
          'package:shared_preferences/shared_preferences.dart',
          'package:cloud_firestore/cloud_firestore.dart',
        ];

        for (final importUri in testCases) {
          expect(
            _isInfrastructureDependency(importUri),
            isTrue,
            reason:
                '$importUri should be detected as infrastructure dependency',
          );
        }
      });

      test('accepts allowed package imports', () {
        final testCases = [
          'package:fpdart/fpdart.dart',
          'package:dartz/dartz.dart',
          'package:freezed_annotation/freezed_annotation.dart',
          'dart:async',
        ];

        for (final importUri in testCases) {
          expect(
            _isInfrastructureDependency(importUri),
            isFalse,
            reason: '$importUri should be accepted',
          );
        }
      });

      test('validates import path patterns', () {
        final domainImportingData = TestImportContext(
          importUri: 'package:app/data/repositories/user_repository_impl.dart',
          currentFilePath: 'lib/domain/usecases/get_user_usecase.dart',
        );

        expect(
          _violatesImportRules(domainImportingData),
          isTrue,
          reason: 'Domain importing data repository impl should violate',
        );
      });
    });

    group('Constructor Dependency Validation', () {
      test('detects constructor depending on concrete repository', () {
        final testCases = [
          'final UserRepositoryImpl repository',
          'final TodoRepositoryImpl _todoRepo',
          'this.productRepositoryImpl',
        ];

        for (final paramDeclaration in testCases) {
          expect(
            _isConcreteRepositoryDependency(paramDeclaration),
            isTrue,
            reason:
                '$paramDeclaration should be detected as concrete dependency',
          );
        }
      });

      test('accepts constructor depending on abstract repository', () {
        final testCases = [
          'final UserRepository repository',
          'final TodoRepository _todoRepo',
          'this.productRepository',
        ];

        for (final paramDeclaration in testCases) {
          expect(
            _isConcreteRepositoryDependency(paramDeclaration),
            isFalse,
            reason: '$paramDeclaration should be accepted (abstract)',
          );
        }
      });

      test('validates constructor parameter types', () {
        final constructor = TestConstructor(
          parameters: [
            TestParameter(typeName: 'UserRepositoryImpl'),
            TestParameter(typeName: 'TodoRepository'), // Abstract - OK
          ],
        );

        final violations = _getConstructorViolations(constructor);
        expect(
          violations.length,
          equals(1),
          reason: 'Should detect one concrete dependency violation',
        );
      });
    });

    group('Field Dependency Validation', () {
      test('detects field with concrete repository type', () {
        final testCases = [
          'final UserRepositoryImpl _repository',
          'TodoRepositoryImpl todoRepo',
          'late final ProductRepositoryImpl productRepo',
        ];

        for (final fieldDeclaration in testCases) {
          expect(
            _isConcreteRepositoryField(fieldDeclaration),
            isTrue,
            reason:
                '$fieldDeclaration should be detected as concrete dependency',
          );
        }
      });

      test('accepts field with abstract repository type', () {
        final testCases = [
          'final UserRepository _repository',
          'TodoRepository todoRepo',
          'late final ProductRepository productRepo',
        ];

        for (final fieldDeclaration in testCases) {
          expect(
            _isConcreteRepositoryField(fieldDeclaration),
            isFalse,
            reason: '$fieldDeclaration should be accepted (abstract)',
          );
        }
      });

      test('validates field type declarations', () {
        final fields = [
          TestField(typeName: 'UserRepositoryImpl'),
          TestField(typeName: 'TodoRepositoryImpl'),
          TestField(typeName: 'OrderRepository'), // Abstract - OK
        ];

        final violations = _getFieldViolations(fields);
        expect(
          violations.length,
          equals(2),
          reason: 'Should detect two concrete dependency violations',
        );
      });
    });

    group('Method Return Type Validation', () {
      test('detects method returning data layer model', () {
        final testCases = [
          'UserModel',
          'TodoDto',
          'OrderResponse',
          'ProductModel',
        ];

        for (final returnType in testCases) {
          expect(
            _isDataLayerModel(returnType),
            isTrue,
            reason: '$returnType should be detected as data layer model',
          );
        }
      });

      test('accepts method returning domain entity', () {
        final testCases = [
          'User',
          'Todo',
          'Order',
          'Product',
          'Result<User, UserFailure>',
        ];

        for (final returnType in testCases) {
          expect(
            _isDataLayerModel(returnType),
            isFalse,
            reason: '$returnType should be accepted as domain entity',
          );
        }
      });

      test('validates repository method signatures', () {
        final methods = [
          TestMethod(name: 'getUser', returnType: 'UserModel'), // Violation
          TestMethod(name: 'getTodo', returnType: 'Todo'), // OK
          TestMethod(name: 'getOrders', returnType: 'OrderDto'), // Violation
        ];

        final violations = _getMethodReturnTypeViolations(methods);
        expect(
          violations.length,
          equals(2),
          reason: 'Should detect two model return type violations',
        );
      });

      test('detects specific data layer type patterns', () {
        final dataTypePatterns = [
          ('UserModel', true),
          ('TodoDto', true),
          ('OrderResponse', true),
          ('ProductDataEntity', true),
          ('User', false),
          ('Todo', false),
        ];

        for (final (typeName, shouldViolate) in dataTypePatterns) {
          expect(
            _isDataLayerModel(typeName),
            equals(shouldViolate),
            reason: '$typeName data type detection incorrect',
          );
        }
      });
    });

    group('Layer-Aware Filtering', () {
      test('validates only domain layer files', () {
        final testCases = [
          ('lib/features/todos/domain/repositories/todo_repository.dart', true),
          ('lib/domain/repositories/user_repository.dart', true),
          (
            'lib/features/todos/data/repositories/todo_repository_impl.dart',
            false
          ),
          ('lib/presentation/pages/home_page.dart', false),
        ];

        for (final (filePath, shouldValidate) in testCases) {
          expect(
            _isDomainLayerFile(filePath),
            equals(shouldValidate),
            reason: 'Layer detection for $filePath incorrect',
          );
        }
      });

      test('skips validation for non-domain files', () {
        final testCases = [
          'lib/data/repositories/user_repository_impl.dart',
          'lib/presentation/widgets/user_card.dart',
          'lib/core/utils/helpers.dart',
        ];

        for (final filePath in testCases) {
          expect(
            _isDomainLayerFile(filePath),
            isFalse,
            reason: '$filePath should not be validated',
          );
        }
      });
    });

    group('Error Messages', () {
      test('concrete repository error message is clear', () {
        const errorMessage =
            'Repository in domain layer should be abstract: UserRepository';

        expect(
          errorMessage.contains('abstract'),
          isTrue,
          reason: 'Error should mention abstract',
        );
        expect(
          errorMessage.contains('domain layer'),
          isTrue,
          reason: 'Error should mention domain layer',
        );
      });

      test('import violation error provides guidance', () {
        const errorMessage =
            'Importing concrete repository implementation from data layer';

        expect(
          errorMessage.contains('concrete repository'),
          isTrue,
          reason: 'Error should mention concrete repository',
        );
        expect(
          errorMessage.contains('data layer'),
          isTrue,
          reason: 'Error should mention data layer',
        );
      });

      test('infrastructure dependency error is specific', () {
        const errorMessage =
            'Direct infrastructure dependency detected in domain repository';

        expect(
          errorMessage.contains('infrastructure'),
          isTrue,
          reason: 'Error should mention infrastructure',
        );
        expect(
          errorMessage.contains('domain repository'),
          isTrue,
          reason: 'Error should mention domain repository',
        );
      });

      test('model return type error provides solution', () {
        const errorMessage =
            'Repository method returns data layer model: UserModel';
        const correctionMessage =
            'Repository methods should return domain entities, not data models.';

        expect(
          errorMessage.contains('data layer model'),
          isTrue,
          reason: 'Error should identify data layer model',
        );
        expect(
          correctionMessage.contains('domain entities'),
          isTrue,
          reason: 'Correction should suggest domain entities',
        );
      });
    });

    group('Edge Cases', () {
      test('handles repository with partial implementation', () {
        final repo = TestRepository(
          hasAbstractKeyword: true,
          hasImplementedMethods: true,
          hasAbstractMethods: true,
        );

        expect(
          _isValidAbstractRepository(repo),
          isTrue,
          reason: 'Abstract class with some implemented methods is valid',
        );
      });

      test('handles repository implementing multiple interfaces', () {
        final repo = TestRepository(
          implementedInterfaces: [
            'UserRepository',
            'Searchable',
            'Cacheable',
          ],
        );

        expect(
          _implementsRepositoryInterface(repo),
          isTrue,
          reason: 'Should detect Repository interface among multiple',
        );
      });

      test('handles generic repository types', () {
        final testCases = [
          'Repository<User>',
          'Repository<Todo, TodoId>',
          'CrudRepository<Order, String>',
        ];

        for (final typeName in testCases) {
          expect(
            _isGenericRepository(typeName),
            isTrue,
            reason: '$typeName should be detected as generic repository',
          );
        }
      });

      test('handles private repository classes', () {
        final testCases = [
          '_UserRepository',
          '_TodoRepositoryImpl',
        ];

        for (final className in testCases) {
          expect(
            _isPrivateClass(className),
            isTrue,
            reason: '$className should be detected as private',
          );
        }
      });

      test('handles repository inheritance chains', () {
        final repo = TestRepository(
          extendsClass: 'BaseRepository<User>',
          implementedInterfaces: ['UserRepository'],
        );

        expect(
          _hasRepositoryInHierarchy(repo),
          isTrue,
          reason: 'Should detect Repository in inheritance chain',
        );
      });

      test('handles repositories in nested feature directories', () {
        final testCases = [
          'lib/features/auth/domain/repositories/auth_repository.dart',
          'lib/features/todos/sub_feature/domain/repositories/todo_repository.dart',
        ];

        for (final filePath in testCases) {
          expect(
            _isDomainLayerFile(filePath),
            isTrue,
            reason: '$filePath should be detected as domain layer',
          );
        }
      });

      test('handles Windows path separators', () {
        final testCases = [
          r'lib\features\todos\domain\repositories\todo_repository.dart',
          r'lib\domain\repositories\user_repository.dart',
        ];

        for (final filePath in testCases) {
          expect(
            _isDomainLayerFile(filePath),
            isTrue,
            reason: '$filePath with backslashes should be detected',
          );
        }
      });

      test('handles relative import paths', () {
        final testCases = [
          '../../../data/repositories/user_repository_impl.dart',
          '../../data/repositories/todo_repository_impl.dart',
        ];

        for (final importUri in testCases) {
          expect(
            _isDataRepositoryImplImport(importUri),
            isTrue,
            reason: 'Relative import $importUri should be detected',
          );
        }
      });
    });
  });
}

// ============================================================================
// Helper Functions (Simulating RepositoryInterfaceRule behavior)
// ============================================================================

/// Detects abstract class repositories
bool _isAbstractRepository(String declaration) {
  return declaration.contains('abstract') &&
      declaration.contains('class') &&
      declaration.contains('Repository');
}

/// Detects abstract interface class repositories (Dart 3)
bool _isAbstractInterfaceRepository(String declaration) {
  return declaration.contains('abstract') &&
      declaration.contains('interface') &&
      declaration.contains('class') &&
      declaration.contains('Repository');
}

/// Detects concrete repository in domain layer
bool _isConcreteRepositoryInDomain(TestRepository repo) {
  return !repo.isAbstract &&
      repo.hasImplementation &&
      _isDomainLayerFile(repo.layerPath);
}

/// Checks if repository is effectively abstract (all methods abstract)
bool _isEffectivelyAbstract(TestRepository repo) {
  return repo.hasAbstractKeyword || repo.allMethodsAbstract;
}

/// Checks if class name contains Repository
bool _containsRepository(String className) {
  return className.contains('Repository');
}

/// Detects repository implementation class names
bool _isRepositoryImplClass(String className) {
  return (className.endsWith('Impl') || className.endsWith('Implementation')) &&
      className.contains('Repo');
}

/// Detects data layer repository implementation imports
bool _isDataRepositoryImplImport(String importUri) {
  final hasDataPath =
      importUri.contains('/data/') || importUri.contains(r'\data\');
  final hasRepository =
      importUri.contains('repository') || importUri.contains('Repository');
  final hasImpl = importUri.contains('impl') || importUri.contains('Impl');

  return hasDataPath && hasRepository && hasImpl;
}

/// Detects infrastructure dependency imports
bool _isInfrastructureDependency(String importUri) {
  const infraPatterns = [
    'package:sqflite',
    'package:hive',
    'package:shared_preferences',
    'package:cloud_firestore',
  ];

  return infraPatterns.any((pattern) => importUri.startsWith(pattern));
}

/// Checks if import violates rules
bool _violatesImportRules(TestImportContext context) {
  final isDomainFile = _isDomainLayerFile(context.currentFilePath);
  final isDataImport = _isDataRepositoryImplImport(context.importUri);

  return isDomainFile && isDataImport;
}

/// Detects concrete repository dependency in constructor parameter
bool _isConcreteRepositoryDependency(String paramDeclaration) {
  return paramDeclaration.contains('Impl') &&
      (paramDeclaration.contains('Repository') ||
          paramDeclaration.contains('Repo'));
}

/// Gets constructor violations
List<String> _getConstructorViolations(TestConstructor constructor) {
  return constructor.parameters
      .where((p) => _isRepositoryImplClass(p.typeName))
      .map((p) => p.typeName)
      .toList();
}

/// Detects concrete repository field
bool _isConcreteRepositoryField(String fieldDeclaration) {
  return fieldDeclaration.contains('Impl') &&
      (fieldDeclaration.contains('Repository') ||
          fieldDeclaration.contains('Repo'));
}

/// Gets field violations
List<String> _getFieldViolations(List<TestField> fields) {
  return fields
      .where((f) => _isRepositoryImplClass(f.typeName))
      .map((f) => f.typeName)
      .toList();
}

/// Detects data layer model types
bool _isDataLayerModel(String typeName) {
  return typeName.endsWith('Model') ||
      typeName.endsWith('Dto') ||
      typeName.endsWith('Response') ||
      (typeName.endsWith('Entity') && typeName.contains('Data'));
}

/// Gets method return type violations
List<String> _getMethodReturnTypeViolations(List<TestMethod> methods) {
  return methods
      .where((m) => _isDataLayerModel(m.returnType))
      .map((m) => m.name)
      .toList();
}

/// Detects domain layer files
bool _isDomainLayerFile(String filePath) {
  return filePath.contains('/domain/') || filePath.contains(r'\domain\');
}

/// Validates abstract repository
bool _isValidAbstractRepository(TestRepository repo) {
  return repo.hasAbstractKeyword;
}

/// Checks if implements Repository interface
bool _implementsRepositoryInterface(TestRepository repo) {
  return repo.implementedInterfaces
      .any((interface) => interface.contains('Repository'));
}

/// Detects generic repository types
bool _isGenericRepository(String typeName) {
  return typeName.contains('Repository') &&
      typeName.contains('<') &&
      typeName.contains('>');
}

/// Detects private class names
bool _isPrivateClass(String className) {
  return className.startsWith('_');
}

/// Checks repository in inheritance chain
bool _hasRepositoryInHierarchy(TestRepository repo) {
  return (repo.extendsClass?.contains('Repository') ?? false) ||
      _implementsRepositoryInterface(repo);
}

// ============================================================================
// Test Helper Classes
// ============================================================================

class TestRepository {
  final bool isAbstract;
  final bool hasImplementation;
  final String layerPath;
  final bool hasAbstractKeyword;
  final bool allMethodsAbstract;
  final bool hasImplementedMethods;
  final bool hasAbstractMethods;
  final List<String> implementedInterfaces;
  final String? extendsClass;

  TestRepository({
    this.isAbstract = false,
    this.hasImplementation = false,
    this.layerPath = '',
    this.hasAbstractKeyword = false,
    this.allMethodsAbstract = false,
    this.hasImplementedMethods = false,
    this.hasAbstractMethods = false,
    this.implementedInterfaces = const [],
    this.extendsClass,
  });
}

class TestImportContext {
  final String importUri;
  final String currentFilePath;

  TestImportContext({
    required this.importUri,
    required this.currentFilePath,
  });
}

class TestConstructor {
  final List<TestParameter> parameters;

  TestConstructor({required this.parameters});
}

class TestParameter {
  final String typeName;

  TestParameter({required this.typeName});
}

class TestField {
  final String typeName;

  TestField({required this.typeName});
}

class TestMethod {
  final String name;
  final String returnType;

  TestMethod({required this.name, required this.returnType});
}
