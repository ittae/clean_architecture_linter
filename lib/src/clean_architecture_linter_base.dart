/// Base configuration and utilities for Clean Architecture Linter.
///
/// This file contains shared utilities and configuration that can be used
/// across different lint rules.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Utility functions for Clean Architecture layer detection and file filtering.
///
/// This class provides a unified API for analyzing Dart files in Clean Architecture
/// projects, including layer detection, class validation, type checking, and AST
/// utilities.
class CleanArchitectureUtils {
  // ============================================================================
  // Category 1: File Exclusion & Filtering
  // ============================================================================

  /// Determines if a file should be excluded from lint analysis.
  ///
  /// Excludes:
  /// - **Test files**: `/test/`, `_test.dart`, `/integration_test/`
  /// - **Generated files**: `.g.dart`, `.freezed.dart`, `.mocks.dart`, `.config.dart`, `.gr.dart`, `.localizely.dart`, `.pb.dart`
  /// - **Build artifacts**: `/build/`, `/.dart_tool/`, `.packages`
  /// - **Documentation**: `.md`, `.txt`, `.rst`, non-essential `.yaml` files
  ///
  /// Examples:
  /// ```dart
  /// shouldExcludeFile('lib/domain/entities/todo.dart');           // false
  /// shouldExcludeFile('lib/domain/entities/todo_test.dart');      // true (test file)
  /// shouldExcludeFile('lib/data/models/todo_model.freezed.dart'); // true (generated)
  /// shouldExcludeFile('build/generated/assets.dart');             // true (build artifact)
  /// shouldExcludeFile('README.md');                               // true (documentation)
  /// ```
  ///
  /// Returns `true` if the file should be excluded, `false` otherwise.
  static bool shouldExcludeFile(String filePath) {
    // Exclude test folders
    if (_isTestFile(filePath)) {
      return true;
    }

    // Exclude generated files
    if (_isGeneratedFile(filePath)) {
      return true;
    }

    // Exclude build artifacts
    if (_isBuildArtifact(filePath)) {
      return true;
    }

    // Exclude documentation files (but keep pubspec.yaml and analysis_options.yaml)
    if (_isDocumentationFile(filePath)) {
      return true;
    }

    return false;
  }

  /// Checks if a file is a test file.
  static bool _isTestFile(String filePath) {
    return filePath.contains('/test/') ||
        filePath.contains('\\test\\') ||
        filePath.endsWith('_test.dart') ||
        filePath.contains('/integration_test/') ||
        filePath.contains('\\integration_test\\');
  }

  /// Checks if a file is generated code.
  static bool _isGeneratedFile(String filePath) {
    return filePath.endsWith('.g.dart') ||
        filePath.endsWith('.freezed.dart') ||
        filePath.endsWith('.mocks.dart') ||
        filePath.endsWith('.config.dart') ||
        filePath.endsWith('.gr.dart') ||
        filePath.endsWith('.localizely.dart') ||
        filePath.contains('.pb.dart');
  }

  /// Checks if a file is a build artifact.
  static bool _isBuildArtifact(String filePath) {
    return filePath.contains('/build/') ||
        filePath.contains('\\build\\') ||
        filePath.startsWith('build/') ||
        filePath.startsWith('build\\') ||
        filePath.contains('/.dart_tool/') ||
        filePath.contains('\\.dart_tool\\') ||
        filePath.startsWith('.dart_tool/') ||
        filePath.startsWith('.dart_tool\\') ||
        filePath.endsWith('.packages') ||
        filePath.contains('/.packages') ||
        filePath.contains('\\.packages');
  }

  /// Checks if a file is documentation without code.
  static bool _isDocumentationFile(String filePath) {
    if (filePath.endsWith('.md') ||
        filePath.endsWith('.txt') ||
        filePath.endsWith('.rst')) {
      return true;
    }

    // Keep important YAML files but exclude others
    if (filePath.endsWith('.yaml') || filePath.endsWith('.yml')) {
      final fileName = filePath.split('/').last.split('\\').last;
      final importantYamlFiles = [
        'pubspec.yaml',
        'analysis_options.yaml',
        'build.yaml',
        'dependency_validator.yaml',
      ];
      return !importantYamlFiles.contains(fileName);
    }

    return false;
  }

  // ============================================================================
  // Category 2: Layer File Detection
  // ============================================================================

  /// Checks if a file belongs to the domain layer.
  ///
  /// Recognizes files in these directories:
  /// - `/domain/` - Standard domain layer directory
  /// - `/usecases/`, `/use_cases/` - Use case implementations
  /// - `/entities/` - Domain entities
  /// - `/exceptions/` - Domain-specific exceptions
  ///
  /// By default, automatically excludes test files, generated files, and build
  /// artifacts. Set [excludeFiles] to `false` to include all files regardless.
  ///
  /// Examples:
  /// ```dart
  /// isDomainFile('lib/features/todos/domain/entities/todo.dart');      // true
  /// isDomainFile('lib/features/todos/usecases/get_todos.dart');        // true
  /// isDomainFile('lib/features/todos/domain/entities/todo_test.dart'); // false (excluded)
  /// isDomainFile('lib/features/todos/domain/entities/todo_test.dart', excludeFiles: false); // true
  /// isDomainFile('lib/features/todos/data/models/todo_model.dart');    // false
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file belongs to the domain layer.
  static bool isDomainFile(String filePath, {bool excludeFiles = true}) {
    // Step 1: Optional file exclusion
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    // Step 2: Path normalization
    final normalized = _normalizePath(filePath);

    // Step 3: Extended path pattern matching
    return normalized.contains('/domain/') ||
        normalized.contains('/usecases/') ||
        normalized.contains('/use_cases/') ||
        normalized.contains('/entities/') ||
        normalized.contains('/exceptions/');
  }

  /// Checks if a file belongs to the data layer.
  ///
  /// Recognizes files in these directories:
  /// - `/data/` - Standard data layer directory
  /// - `/datasources/`, `/data_sources/` - Data source implementations
  /// - `/repositories/` - Repository implementations (excludes `/domain/repositories/`)
  /// - `/models/` - Data models
  ///
  /// By default, automatically excludes test files, generated files, and build
  /// artifacts. Set [excludeFiles] to `false` to include all files regardless.
  ///
  /// Note: `/repositories/` in domain layer (e.g., `/domain/repositories/`) are
  /// correctly identified as domain files, not data files.
  ///
  /// Examples:
  /// ```dart
  /// isDataFile('lib/features/todos/data/models/todo_model.dart');           // true
  /// isDataFile('lib/features/todos/data/datasources/todo_remote_ds.dart');  // true
  /// isDataFile('lib/features/todos/data/repositories/todo_repo_impl.dart'); // true
  /// isDataFile('lib/features/todos/domain/repositories/todo_repository.dart'); // false (domain layer)
  /// isDataFile('lib/features/todos/data/models/todo_model.freezed.dart');   // false (excluded)
  /// isDataFile('lib/features/todos/domain/entities/todo.dart');             // false
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file belongs to the data layer.
  static bool isDataFile(String filePath, {bool excludeFiles = true}) {
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    final normalized = _normalizePath(filePath);

    // /domain/repositories/ should be recognized as domain, not data
    // Check this before other patterns to avoid false positives
    if (normalized.contains('/domain/')) {
      return false;
    }

    return normalized.contains('/data/') ||
        normalized.contains('/datasources/') ||
        normalized.contains('/data_sources/') ||
        normalized.contains('/repositories/') ||
        normalized.contains('/models/');
  }

  /// Checks if a file belongs to the presentation layer.
  ///
  /// Recognizes files in these directories:
  /// - `/presentation/` - Standard presentation layer directory
  /// - `/ui/`, `/views/` - UI components and views
  /// - `/widgets/` - Reusable widget components
  /// - `/pages/`, `/screens/` - Application screens
  /// - `/states/` - UI state management (Riverpod, Bloc, etc.)
  ///
  /// By default, automatically excludes test files, generated files, and build
  /// artifacts. Set [excludeFiles] to `false` to include all files regardless.
  ///
  /// Examples:
  /// ```dart
  /// isPresentationFile('lib/features/todos/presentation/pages/todo_page.dart');    // true
  /// isPresentationFile('lib/features/todos/ui/widgets/todo_card.dart');            // true
  /// isPresentationFile('lib/features/todos/states/todo_state.dart');               // true
  /// isPresentationFile('lib/features/todos/presentation/pages/todo_page_test.dart'); // false (excluded)
  /// isPresentationFile('lib/features/todos/domain/entities/todo.dart');            // false
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file belongs to the presentation layer.
  static bool isPresentationFile(String filePath, {bool excludeFiles = true}) {
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    final normalized = _normalizePath(filePath);
    return normalized.contains('/presentation/') ||
        normalized.contains('/ui/') ||
        normalized.contains('/views/') ||
        normalized.contains('/widgets/') ||
        normalized.contains('/pages/') ||
        normalized.contains('/screens/') ||
        normalized.contains('/states/');
  }

  // ============================================================================
  // Category 3: Component-Specific File Detection
  // ============================================================================

  /// Checks if a file is a use case implementation.
  ///
  /// Recognizes use case files in these directories:
  /// - `/usecases/`
  /// - `/use_cases/`
  ///
  /// Examples:
  /// ```dart
  /// isUseCaseFile('lib/features/todos/domain/usecases/get_todos.dart');     // true
  /// isUseCaseFile('lib/features/todos/use_cases/create_todo_usecase.dart'); // true
  /// isUseCaseFile('lib/features/todos/domain/entities/todo.dart');          // false
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file is a use case.
  static bool isUseCaseFile(String filePath, {bool excludeFiles = true}) {
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    final normalized = _normalizePath(filePath);
    return normalized.contains('/usecases/') ||
        normalized.contains('/use_cases/');
  }

  /// Checks if a file is a data source implementation.
  ///
  /// Recognizes data source files in these directories:
  /// - `/datasources/`
  /// - `/data_sources/`
  ///
  /// Examples:
  /// ```dart
  /// isDataSourceFile('lib/features/todos/data/datasources/todo_remote_ds.dart');   // true
  /// isDataSourceFile('lib/features/todos/data/data_sources/todo_local_ds.dart');   // true
  /// isDataSourceFile('lib/features/todos/data/repositories/todo_repo_impl.dart');  // false
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file is a data source.
  static bool isDataSourceFile(String filePath, {bool excludeFiles = true}) {
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    final normalized = _normalizePath(filePath);
    return normalized.contains('/datasources/') ||
        normalized.contains('/data_sources/');
  }

  /// Checks if a file is a repository (interface or implementation).
  ///
  /// Recognizes repository files in `/repositories/` directory.
  ///
  /// Note: This method does not distinguish between interfaces and implementations.
  /// Use [isRepositoryInterfaceFile] or [isRepositoryImplFile] for specific checks.
  ///
  /// Examples:
  /// ```dart
  /// isRepositoryFile('lib/features/todos/domain/repositories/todo_repository.dart');      // true
  /// isRepositoryFile('lib/features/todos/data/repositories/todo_repository_impl.dart');   // true
  /// isRepositoryFile('lib/features/todos/data/datasources/todo_remote_ds.dart');          // false
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file is a repository.
  static bool isRepositoryFile(String filePath, {bool excludeFiles = true}) {
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    final normalized = _normalizePath(filePath);
    return normalized.contains('/repositories/');
  }

  /// Checks if a file is a repository implementation (not interface).
  ///
  /// Recognizes repository implementation files by:
  /// - Located in `/repositories/` directory
  /// - File name ends with `_impl.dart` or `_repository_impl.dart`
  ///
  /// Examples:
  /// ```dart
  /// isRepositoryImplFile('lib/features/todos/data/repositories/todo_repository_impl.dart');  // true
  /// isRepositoryImplFile('lib/features/todos/data/repositories/todo_repo_impl.dart');        // true
  /// isRepositoryImplFile('lib/features/todos/domain/repositories/todo_repository.dart');     // false (interface)
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to check
  /// - [excludeFiles]: Whether to exclude test/generated files (default: true)
  ///
  /// Returns `true` if the file is a repository implementation.
  static bool isRepositoryImplFile(
    String filePath, {
    bool excludeFiles = true,
  }) {
    if (excludeFiles && shouldExcludeFile(filePath)) return false;

    final normalized = _normalizePath(filePath);
    return normalized.contains('/repositories/') &&
        (normalized.endsWith('_impl.dart') ||
            normalized.contains('_repository_impl.dart'));
  }

  // ============================================================================
  // Category 4: Class Name Validation
  // ============================================================================

  /// Checks if a class name matches use case naming conventions.
  ///
  /// Recognizes these patterns:
  /// - Class name ends with `UseCase` (e.g., `GetTodoUseCase`)
  /// - Class name ends with `Usecase` (e.g., `GetTodoUsecase`)
  /// - Class name contains `UseCase` (e.g., `BaseUseCaseImpl`)
  ///
  /// Examples:
  /// ```dart
  /// isUseCaseClass('GetTodoUseCase');           // true
  /// isUseCaseClass('CreateTodoUsecase');        // true
  /// isUseCaseClass('DeleteTodoUseCaseImpl');    // true
  /// isUseCaseClass('TodoRepository');           // false
  /// ```
  ///
  /// Parameters:
  /// - [className]: The simple class name (not fully qualified)
  ///
  /// Returns `true` if the class name follows use case conventions.
  static bool isUseCaseClass(String className) {
    return className.endsWith('UseCase') ||
        className.endsWith('Usecase') ||
        className.contains('UseCase');
  }

  /// Checks if a class name matches data source naming conventions.
  ///
  /// Recognizes these patterns:
  /// - Class name ends with `DataSource` (e.g., `TodoRemoteDataSource`)
  /// - Class name ends with `Datasource` (e.g., `TodoLocalDatasource`)
  /// - Class name contains `DataSource` (e.g., `BaseDataSourceImpl`)
  ///
  /// Examples:
  /// ```dart
  /// isDataSourceClass('TodoRemoteDataSource');     // true
  /// isDataSourceClass('TodoLocalDatasource');      // true
  /// isDataSourceClass('TodoDataSourceImpl');       // true
  /// isDataSourceClass('TodoRepository');           // false
  /// ```
  ///
  /// Parameters:
  /// - [className]: The simple class name (not fully qualified)
  ///
  /// Returns `true` if the class name follows data source conventions.
  static bool isDataSourceClass(String className) {
    return className.endsWith('DataSource') ||
        className.endsWith('Datasource') ||
        className.contains('DataSource');
  }

  /// Checks if a class name matches repository naming conventions.
  ///
  /// Recognizes any class name containing `Repository`.
  ///
  /// Note: This method does not distinguish between interfaces and implementations.
  /// Use [isRepositoryInterfaceClass] or [isRepositoryImplClass] for specific checks.
  ///
  /// Examples:
  /// ```dart
  /// isRepositoryClass('TodoRepository');          // true
  /// isRepositoryClass('TodoRepositoryImpl');      // true
  /// isRepositoryClass('BaseRepositoryAdapter');   // true
  /// isRepositoryClass('TodoDataSource');          // false
  /// ```
  ///
  /// Parameters:
  /// - [className]: The simple class name (not fully qualified)
  ///
  /// Returns `true` if the class name contains 'Repository'.
  static bool isRepositoryClass(String className) {
    return className.contains('Repository');
  }

  /// Checks if a class name suggests a repository interface (not implementation).
  ///
  /// This is a fast, name-based check useful for quick filtering before more
  /// expensive AST analysis. For precise validation, use [isRepositoryInterface]
  /// with a ClassDeclaration.
  ///
  /// Recognizes:
  /// - Class name ends with `Repository`
  /// - Class name does NOT end with `RepositoryImpl`
  ///
  /// Examples:
  /// ```dart
  /// isRepositoryInterfaceClass('TodoRepository');          // true
  /// isRepositoryInterfaceClass('UserRepository');          // true
  /// isRepositoryInterfaceClass('TodoRepositoryImpl');      // false (implementation)
  /// isRepositoryInterfaceClass('TodoRepo');                // false (doesn't end with Repository)
  /// ```
  ///
  /// Parameters:
  /// - [className]: The simple class name (not fully qualified)
  ///
  /// Returns `true` if the class name suggests a repository interface.
  ///
  /// See also:
  /// - [isRepositoryInterface] for AST-based precise validation
  /// - [isRepositoryImplClass] for implementation class check
  static bool isRepositoryInterfaceClass(String className) {
    return className.endsWith('Repository') &&
        !className.endsWith('RepositoryImpl');
  }

  /// Checks if a class name suggests a repository implementation.
  ///
  /// Recognizes these patterns:
  /// - Class name ends with `RepositoryImpl` (e.g., `TodoRepositoryImpl`)
  /// - Class name ends with `RepositoryImplementation` (e.g., `TodoRepositoryImplementation`)
  /// - Class name ends with `Impl` and contains `Repository` (e.g., `TodoRepoImpl`)
  ///
  /// Examples:
  /// ```dart
  /// isRepositoryImplClass('TodoRepositoryImpl');              // true
  /// isRepositoryImplClass('TodoRepositoryImplementation');    // true
  /// isRepositoryImplClass('TodoRepoImpl');                    // true
  /// isRepositoryImplClass('UserRepositoryImpl');              // true
  /// isRepositoryImplClass('TodoRepository');                  // false (interface)
  /// isRepositoryImplClass('TodoDataSourceImpl');              // false (not a repository)
  /// ```
  ///
  /// Parameters:
  /// - [className]: The simple class name (not fully qualified)
  ///
  /// Returns `true` if the class name suggests a repository implementation.
  static bool isRepositoryImplClass(String className) {
    return className.endsWith('RepositoryImpl') ||
        className.endsWith('RepositoryImplementation') ||
        (className.endsWith('Impl') && className.contains('Repository'));
  }

  // ============================================================================
  // Category 5: AST-Based Repository Validation
  // ============================================================================

  // Note: isRepositoryInterface() and isRepositoryInterfaceMethod() already exist
  // below and will be kept as-is. They are already well-implemented.

  /// Checks if a class is a repository interface using AST analysis.
  ///
  /// This is a precise but slower method that examines the actual class structure.
  /// Use this for accurate validation when you have AST nodes available.
  ///
  /// Validates:
  /// 1. **Naming**: Class name contains `Repository`, `DataSource`, `Gateway`, or `Port`
  /// 2. **Structure**: Class is abstract OR all methods are abstract
  /// 3. **Methods**: Getters and setters are allowed in interfaces
  ///
  /// Examples:
  /// ```dart
  /// // Valid repository interface
  /// abstract class TodoRepository {
  ///   Future<List<Todo>> getTodos();
  ///   Future<void> addTodo(Todo todo);
  /// }
  ///
  /// // Valid (all methods abstract, no 'abstract' keyword)
  /// class UserRepository {
  ///   Future<User> getUser(String id);
  ///   Future<void> updateUser(User user);
  /// }
  ///
  /// // Invalid (has concrete implementation)
  /// class TodoRepository {
  ///   Future<List<Todo>> getTodos() async {
  ///     return []; // Implementation present
  ///   }
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [classDeclaration]: The class AST node to validate
  ///
  /// Returns `true` if the class is a repository interface.
  ///
  /// See also:
  /// - [isRepositoryInterfaceClass] for fast name-based filtering
  /// - [isRepositoryInterfaceMethod] for individual method validation
  static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
    final className = classDeclaration.name.lexeme;

    // Step 1: Check naming patterns
    final repositoryPatterns = ['Repository', 'DataSource', 'Gateway', 'Port'];
    final isRepositoryClass = repositoryPatterns.any(
      (pattern) => className.contains(pattern),
    );

    if (!isRepositoryClass) return false;

    // Step 2: Check if abstract
    final isAbstractClass = classDeclaration.abstractKeyword != null;

    // Step 3: Check if all methods are abstract
    final hasOnlyAbstractMethods = classDeclaration.members
        .whereType<MethodDeclaration>()
        .every(
          (method) => method.isAbstract || method.isGetter || method.isSetter,
        );

    return isRepositoryClass && (isAbstractClass || hasOnlyAbstractMethods);
  }

  /// Checks if a method belongs to a repository interface.
  ///
  /// Validates that the method is abstract (no implementation body) or is a
  /// getter/setter, which are allowed in repository interfaces.
  ///
  /// Examples:
  /// ```dart
  /// // Valid repository interface methods
  /// Future<List<Todo>> getTodos();           // Abstract method ✓
  /// Stream<Todo> watchTodo(String id);       // Abstract method ✓
  /// String get baseUrl;                      // Getter ✓
  /// set timeout(Duration value);             // Setter ✓
  ///
  /// // Invalid (has implementation)
  /// Future<List<Todo>> getTodos() async {    // Concrete method ✗
  ///   return [];
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [method]: The method AST node to validate
  ///
  /// Returns `true` if the method is valid for a repository interface.
  static bool isRepositoryInterfaceMethod(MethodDeclaration method) {
    return method.isAbstract || method.isGetter || method.isSetter;
  }

  // ============================================================================
  // Category 6: Type Annotation Validation
  // ============================================================================

  /// Checks if a type annotation is a Result or Either type.
  ///
  /// Recognizes these functional result types:
  /// - `Result<T, E>` - Result type from result package
  /// - `Either<L, R>` - Either type from dartz/fpdart
  /// - `Task<T>` - Asynchronous computation from fpdart
  /// - `TaskEither<L, R>` - Asynchronous Either from fpdart
  ///
  /// Supports recursive type checking for nested generics.
  ///
  /// Examples:
  /// ```dart
  /// // From method signatures
  /// Future<Result<Todo, Failure>> getTodo();        // (checks Result inside Future)
  /// Result<List<Todo>, Failure> getTodos();         // true
  /// Either<Failure, Todo> findTodo();               // true
  /// Task<User> loadUser();                          // true
  /// void updateTodo(Todo todo);                     // false
  /// ```
  ///
  /// Parameters:
  /// - [returnType]: The type annotation to check (nullable)
  ///
  /// Returns `true` if the type is a Result or Either variant, `false` otherwise.
  static bool isResultType(TypeAnnotation? returnType) {
    if (returnType == null) return false;

    final typeStr = returnType.toString();

    // Check for common Result/Either patterns
    if (typeStr.contains('Result<') ||
        typeStr.contains('Either<') ||
        typeStr.contains('Task<') ||
        typeStr.contains('TaskEither<') ||
        typeStr.contains('Result ') ||
        typeStr.contains('Either ')) {
      return true;
    }

    // Check with NamedType for more precise detection
    if (returnType is NamedType) {
      final name = returnType.name2.lexeme;
      if (name == 'Result' ||
          name == 'Either' ||
          name == 'Task' ||
          name == 'TaskEither') {
        return true;
      }

      // Check type arguments (e.g., Future<Result<T, E>>)
      final typeArgs = returnType.typeArguments;
      if (typeArgs != null) {
        for (final arg in typeArgs.arguments) {
          if (isResultType(arg)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Checks if a type annotation is void.
  ///
  /// Examples:
  /// ```dart
  /// void addTodo(Todo todo);                  // true
  /// Future<void> deleteTodo(String id);       // false (Future<void>, not void)
  /// Future<List<Todo>> getTodos();            // false
  /// ```
  ///
  /// Parameters:
  /// - [returnType]: The type annotation to check (nullable)
  ///
  /// Returns `true` if the type is void, `false` otherwise.
  static bool isVoidType(TypeAnnotation? returnType) {
    if (returnType == null) return false;
    return returnType.toString().contains('void');
  }

  // ============================================================================
  // Category 7: Exception Pattern Recognition
  // ============================================================================

  /// Known data layer exception types.
  static const _dataExceptions = {
    'ServerException',
    'NetworkException',
    'CacheException',
    'DatabaseException',
    'NotFoundException',
    'UnauthorizedException',
    'DataSourceException',
  };

  /// Checks if an exception type belongs to the data layer.
  ///
  /// Recognizes these data layer exception patterns:
  /// - **Generic**: Ends with `DataException` or `DataError`
  /// - **Network**: `ServerException`, `NetworkException`
  /// - **Storage**: `CacheException`, `DatabaseException`
  /// - **Other**: `NotFoundException`, `UnauthorizedException`
  ///
  /// Examples:
  /// ```dart
  /// isDataException('ServerException');          // true
  /// isDataException('NetworkException');         // true
  /// isDataException('CacheException');           // true
  /// isDataException('TodoDataException');        // true
  /// isDataException('TodoNotFoundException');    // true
  /// isDataException('InvalidTodoException');     // false (domain exception)
  /// isDataException('TodoFailure');              // false (domain failure)
  /// ```
  ///
  /// Parameters:
  /// - [typeName]: The exception type name to check
  ///
  /// Returns `true` if the exception belongs to the data layer.
  ///
  /// See also:
  /// - [isDomainException] for domain layer exceptions
  static bool isDataException(String typeName) {
    // Generic patterns
    if (typeName.endsWith('DataException') || typeName.endsWith('DataError')) {
      return true;
    }

    // Known data layer exceptions
    return _dataExceptions.contains(typeName);
  }

  /// Checks if an exception type belongs to the domain layer.
  ///
  /// Recognizes these domain layer exception patterns:
  /// - Ends with `DomainException` or `DomainError`
  /// - Ends with `Failure` (common in Clean Architecture)
  /// - Feature-specific exceptions (e.g., `TodoException`, `UserException`)
  ///
  /// Examples:
  /// ```dart
  /// isDomainException('InvalidTodoException');        // true (feature-specific)
  /// isDomainException('TodoNotFoundFailure');         // true (ends with Failure)
  /// isDomainException('UserValidationFailure');       // true
  /// isDomainException('AuthenticationFailure');       // true
  /// isDomainException('ServerException');             // false (data layer)
  /// ```
  ///
  /// Parameters:
  /// - [typeName]: The exception type name to check
  ///
  /// Returns `true` if the exception belongs to the domain layer.
  ///
  /// See also:
  /// - [isDataException] for data layer exceptions
  static bool isDomainException(String typeName) {
    return typeName.endsWith('DomainException') ||
        typeName.endsWith('DomainError') ||
        typeName.endsWith('Failure');
  }

  /// Checks if a class implements or extends the Exception interface.
  ///
  /// Validates these inheritance patterns:
  /// - `extends Exception`
  /// - `implements Exception`
  /// - `with Exception` (mixin)
  ///
  /// Examples:
  /// ```dart
  /// // Valid exception classes
  /// class TodoException extends Exception {}             // true
  /// class CacheException implements Exception {}         // true
  /// class BaseException with Exception {}                // true
  ///
  /// // Invalid
  /// class TodoError {}                                    // false (no Exception)
  /// class TodoFailure extends Equatable {}               // false (extends different class)
  /// ```
  ///
  /// Parameters:
  /// - [node]: The class declaration to check
  ///
  /// Returns `true` if the class implements/extends Exception.
  static bool implementsException(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    final implementsClause = node.implementsClause;
    final withClause = node.withClause;

    return (extendsClause?.superclass.toString().contains('Exception') ??
            false) ||
        (implementsClause?.interfaces.any(
              (i) => i.toString().contains('Exception'),
            ) ??
            false) ||
        (withClause?.mixinTypes.any(
              (m) => m.toString().contains('Exception'),
            ) ??
            false);
  }

  // ============================================================================
  // Category 8: AST Traversal & Utilities
  // ============================================================================

  /// Finds the parent class declaration of an AST node.
  ///
  /// Traverses up the AST tree from the given node until it finds a
  /// ClassDeclaration, or returns null if the node is not inside a class.
  ///
  /// Examples:
  /// ```dart
  /// // Inside a method
  /// class TodoRepository {
  ///   void addTodo(Todo todo) {
  ///     // node = parameter 'todo'
  ///     findParentClass(node); // Returns TodoRepository ClassDeclaration
  ///   }
  /// }
  ///
  /// // Top-level function
  /// void globalFunction() {
  ///   // node = parameter
  ///   findParentClass(node); // Returns null (not in a class)
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [node]: The AST node to start from (nullable)
  ///
  /// Returns the parent ClassDeclaration, or null if not found.
  static ClassDeclaration? findParentClass(AstNode? node) {
    var current = node;
    while (current != null) {
      if (current is ClassDeclaration) return current;
      current = current.parent;
    }
    return null;
  }

  /// Checks if a method is private (name starts with underscore).
  ///
  /// In Dart, identifiers starting with `_` are library-private.
  ///
  /// Examples:
  /// ```dart
  /// class TodoRepository {
  ///   void publicMethod() {}       // false
  ///   void _privateMethod() {}     // true
  ///   void _internalHelper() {}    // true
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [method]: The method declaration to check
  ///
  /// Returns `true` if the method is private.
  static bool isPrivateMethod(MethodDeclaration method) {
    return method.name.lexeme.startsWith('_');
  }

  /// Checks if a throw expression is a rethrow.
  ///
  /// A rethrow re-throws the currently caught exception without wrapping it.
  ///
  /// Examples:
  /// ```dart
  /// try {
  ///   riskyOperation();
  /// } catch (e) {
  ///   throw e;         // false (explicit throw)
  ///   rethrow;         // true (rethrow)
  /// }
  /// ```
  ///
  /// Parameters:
  /// - [node]: The throw expression to check
  ///
  /// Returns `true` if the expression is a rethrow.
  static bool isRethrow(ThrowExpression node) {
    return node.expression.toString() == 'rethrow' ||
        node.expression is RethrowExpression;
  }

  // ============================================================================
  // Category 9: Feature & Path Utilities
  // ============================================================================

  /// Pre-compiled regular expression for feature name extraction.
  static final _featureNamePattern = RegExp(r'/features/(\w+)/');

  /// Extracts the feature name from a file path.
  ///
  /// Assumes the standard feature-based project structure:
  /// `lib/features/{feature}/...`
  ///
  /// The extracted feature name is:
  /// 1. Capitalized (first letter uppercase)
  /// 2. Singularized (removes trailing 's', 'ies' → 'y')
  ///
  /// Examples:
  /// ```dart
  /// extractFeatureName('lib/features/todos/domain/entities/todo.dart');
  /// // Returns: 'Todo'
  ///
  /// extractFeatureName('lib/features/users/data/models/user_model.dart');
  /// // Returns: 'User'
  ///
  /// extractFeatureName('lib/features/categories/domain/entities/category.dart');
  /// // Returns: 'Category' (ies → y)
  ///
  /// extractFeatureName('lib/domain/entities/todo.dart');
  /// // Returns: '' (no /features/ directory)
  /// ```
  ///
  /// Parameters:
  /// - [filePath]: The file path to extract from
  ///
  /// Returns the capitalized, singularized feature name, or empty string if not found.
  static String extractFeatureName(String filePath) {
    final normalized = _normalizePath(filePath);
    final match = _featureNamePattern.firstMatch(normalized);
    if (match == null) return '';

    final featureName = match.group(1)!;
    return _capitalizeAndSingularize(featureName);
  }

  // ============================================================================
  // Category 10: Internal Helpers (Private)
  // ============================================================================

  /// Normalizes a file path by converting backslashes to forward slashes.
  ///
  /// This ensures consistent path matching across Windows and Unix systems.
  static String _normalizePath(String path) {
    return path.replaceAll('\\', '/');
  }

  /// Capitalizes the first letter and attempts to singularize a string.
  ///
  /// Singularization rules:
  /// - `{word}ies` → `{word}y` (e.g., 'categories' → 'Category')
  /// - `{word}s` → `{word}` (e.g., 'todos' → 'Todo')
  static String _capitalizeAndSingularize(String text) {
    // Capitalize first letter
    final capitalized = text[0].toUpperCase() + text.substring(1);

    // Singularize (simple heuristic)
    if (capitalized.endsWith('ies')) {
      return '${capitalized.substring(0, capitalized.length - 3)}y';
    } else if (capitalized.endsWith('s')) {
      return capitalized.substring(0, capitalized.length - 1);
    }

    return capitalized;
  }

  // ============================================================================
  // Deprecated Methods (backward compatibility - remove in v3.0.0)
  // ============================================================================

  /// **Deprecated**: Use [isDomainFile] instead.
  /// This method will be removed in v3.0.0.
  @Deprecated('Use isDomainFile instead. Will be removed in v3.0.0.')
  static bool isDomainLayerFile(String filePath) {
    return isDomainFile(filePath);
  }

  /// **Deprecated**: Use [isDataFile] instead.
  /// This method will be removed in v3.0.0.
  @Deprecated('Use isDataFile instead. Will be removed in v3.0.0.')
  static bool isDataLayerFile(String filePath) {
    return isDataFile(filePath);
  }

  /// **Deprecated**: Use [isPresentationFile] instead.
  /// This method will be removed in v3.0.0.
  @Deprecated('Use isPresentationFile instead. Will be removed in v3.0.0.')
  static bool isPresentationLayerFile(String filePath) {
    return isPresentationFile(filePath);
  }
}

/// Base class for Clean Architecture lint rules that automatically excludes test files.
abstract class CleanArchitectureLintRule extends DartLintRule {
  const CleanArchitectureLintRule({required super.code});

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Skip analysis for test files and generated files
    if (CleanArchitectureUtils.shouldExcludeFile(filePath)) {
      return;
    }

    // Call the rule-specific implementation
    runRule(resolver, reporter, context);
  }

  /// Override this method instead of run() to implement rule-specific logic.
  /// Test files are automatically excluded.
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  );
}

/// Configuration options for Clean Architecture Linter rules.
class CleanArchitectureConfig {
  /// Whether to enforce strict naming conventions.
  final bool strictNaming;

  /// Whether to allow certain external dependencies in domain layer.
  final bool allowExternalDependencies;

  /// Custom patterns for file and class naming.
  final Map<String, List<String>> namingPatterns;

  const CleanArchitectureConfig({
    this.strictNaming = true,
    this.allowExternalDependencies = false,
    this.namingPatterns = const {},
  });
}
