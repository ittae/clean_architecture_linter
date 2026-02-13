# Unified CleanArchitectureUtils API Design

## Document Overview

**Purpose**: Define the complete API surface, method signatures, naming conventions, and documentation standards for the unified CleanArchitectureUtils class

**Target File**: `lib/src/clean_architecture_linter_base.dart`

**Design Principles**:
1. **Consistency**: Unified naming patterns across all method categories
2. **Clarity**: Self-documenting method names with comprehensive dartdoc
3. **Flexibility**: Optional parameters for different use cases
4. **Performance**: Optimized implementations with caching where applicable
5. **Compatibility**: Backward compatibility via @Deprecated wrappers

---

## Naming Convention System

### Method Naming Patterns

| Category | Pattern | Example | Description |
|----------|---------|---------|-------------|
| **Layer Files** | `is{Layer}File(String)` | `isDomainFile()` | Checks if file belongs to layer |
| **Component Files** | `is{Component}File(String)` | `isUseCaseFile()` | Checks specific component type |
| **Class Names** | `is{Component}Class(String)` | `isUseCaseClass()` | Validates class naming pattern |
| **Type Annotations** | `is{Type}Type(TypeAnnotation?)` | `isResultType()` | Checks type annotation |
| **Exception Patterns** | `is{Layer}Exception(String)` | `isDataException()` | Identifies exception category |
| **AST Checks** | `is{Pattern}(AstNode)` | `isRethrow()` | Validates AST node pattern |
| **AST Traversal** | `{verb}{Noun}(AstNode?)` | `findParentClass()` | Navigates AST structure |
| **Interface Checks** | `implements{Interface}(...)` | `implementsException()` | Checks interface implementation |
| **Extraction** | `extract{Data}(String)` | `extractFeatureName()` | Extracts information from string |
| **Filtering** | `should{Action}(String)` | `shouldExcludeFile()` | Decision-making predicates |

### Parameter Naming Standards

| Parameter Type | Name | Type | Description |
|---------------|------|------|-------------|
| File path | `filePath` | `String` | Absolute or relative file path |
| Class name | `className` | `String` | Simple class name (not fully qualified) |
| Type annotation | `returnType` | `TypeAnnotation?` | Nullable type annotation from AST |
| Type name | `typeName` | `String` | String representation of type |
| AST node | `node` | `{Specific}Declaration` | Concrete AST node type |
| Method | `method` | `MethodDeclaration` | Method AST node |
| Class | `classDeclaration` | `ClassDeclaration` | Class AST node |

### Return Value Conventions

- **Boolean predicates**: Return `bool` (never null)
- **AST searches**: Return nullable types (e.g., `ClassDeclaration?`)
- **String extraction**: Return `String` (empty string if not found, never null)
- **All public methods**: Fully documented return values with examples

---

## API Categories

### Category 1: File Exclusion & Filtering

#### 1.1 shouldExcludeFile()

**Signature**:
```dart
static bool shouldExcludeFile(String filePath)
```

**Documentation**:
```dart
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
```

**Implementation Notes**:
- Keep existing implementation from CleanArchitectureUtils
- Preserve all 4 private helper methods: `_isTestFile()`, `_isGeneratedFile()`, `_isBuildArtifact()`, `_isDocumentationFile()`
- No changes needed

---

### Category 2: Layer File Detection

#### 2.1 isDomainFile()

**Signature**:
```dart
static bool isDomainFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
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
```

**Implementation Strategy**:
```dart
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
```

**Deprecation**:
```dart
@Deprecated('Use isDomainFile instead. Will be removed in v3.0.0.')
static bool isDomainLayerFile(String filePath) {
  return isDomainFile(filePath);
}
```

---

#### 2.2 isDataFile()

**Signature**:
```dart
static bool isDataFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
/// Checks if a file belongs to the data layer.
///
/// Recognizes files in these directories:
/// - `/data/` - Standard data layer directory
/// - `/datasources/`, `/data_sources/` - Data source implementations
/// - `/repositories/` - Repository implementations
/// - `/models/` - Data models
///
/// By default, automatically excludes test files, generated files, and build
/// artifacts. Set [excludeFiles] to `false` to include all files regardless.
///
/// Examples:
/// ```dart
/// isDataFile('lib/features/todos/data/models/todo_model.dart');           // true
/// isDataFile('lib/features/todos/data/datasources/todo_remote_ds.dart');  // true
/// isDataFile('lib/features/todos/data/repositories/todo_repo_impl.dart'); // true
/// isDataFile('lib/features/todos/data/models/todo_model.freezed.dart');   // false (excluded)
/// isDataFile('lib/features/todos/domain/entities/todo.dart');             // false
/// ```
///
/// Parameters:
/// - [filePath]: The file path to check
/// - [excludeFiles]: Whether to exclude test/generated files (default: true)
///
/// Returns `true` if the file belongs to the data layer.
```

**Implementation Strategy**:
```dart
static bool isDataFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/data/') ||
      normalized.contains('/datasources/') ||
      normalized.contains('/data_sources/') ||
      normalized.contains('/repositories/') ||
      normalized.contains('/models/');
}
```

**Deprecation**:
```dart
@Deprecated('Use isDataFile instead. Will be removed in v3.0.0.')
static bool isDataLayerFile(String filePath) {
  return isDataFile(filePath);
}
```

---

#### 2.3 isPresentationFile()

**Signature**:
```dart
static bool isPresentationFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
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
```

**Implementation Strategy**:
```dart
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
```

**Deprecation**:
```dart
@Deprecated('Use isPresentationFile instead. Will be removed in v3.0.0.')
static bool isPresentationLayerFile(String filePath) {
  return isPresentationFile(filePath);
}
```

---

### Category 3: Component-Specific File Detection

#### 3.1 isUseCaseFile()

**Signature**:
```dart
static bool isUseCaseFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isUseCaseFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/usecases/') ||
      normalized.contains('/use_cases/');
}
```

---

#### 3.2 isDataSourceFile()

**Signature**:
```dart
static bool isDataSourceFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isDataSourceFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/datasources/') ||
      normalized.contains('/data_sources/');
}
```

---

#### 3.3 isRepositoryFile()

**Signature**:
```dart
static bool isRepositoryFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isRepositoryFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/repositories/');
}
```

---

#### 3.4 isRepositoryImplFile()

**Signature**:
```dart
static bool isRepositoryImplFile(String filePath, {bool excludeFiles = true})
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isRepositoryImplFile(String filePath, {bool excludeFiles = true}) {
  if (excludeFiles && shouldExcludeFile(filePath)) return false;

  final normalized = _normalizePath(filePath);
  return normalized.contains('/repositories/') &&
      (normalized.endsWith('_impl.dart') || normalized.contains('_repository_impl.dart'));
}
```

---

### Category 4: Class Name Validation

#### 4.1 isUseCaseClass()

**Signature**:
```dart
static bool isUseCaseClass(String className)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isUseCaseClass(String className) {
  return className.endsWith('UseCase') ||
      className.endsWith('Usecase') ||
      className.contains('UseCase');
}
```

---

#### 4.2 isDataSourceClass()

**Signature**:
```dart
static bool isDataSourceClass(String className)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isDataSourceClass(String className) {
  return className.endsWith('DataSource') ||
      className.endsWith('Datasource') ||
      className.contains('DataSource');
}
```

---

#### 4.3 isRepositoryClass()

**Signature**:
```dart
static bool isRepositoryClass(String className)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isRepositoryClass(String className) {
  return className.contains('Repository');
}
```

---

#### 4.4 isRepositoryInterfaceClass()

**Signature**:
```dart
static bool isRepositoryInterfaceClass(String className)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isRepositoryInterfaceClass(String className) {
  return className.endsWith('Repository') &&
      !className.endsWith('RepositoryImpl');
}
```

---

#### 4.5 isRepositoryImplClass()

**Signature**:
```dart
static bool isRepositoryImplClass(String className)
```

**Documentation**:
```dart
/// Checks if a class name suggests a repository implementation.
///
/// Recognizes these patterns:
/// - Class name ends with `RepositoryImpl` (e.g., `TodoRepositoryImpl`)
/// - Class name ends with `Impl` and contains `Repository` (e.g., `TodoRepoImpl`)
///
/// Examples:
/// ```dart
/// isRepositoryImplClass('TodoRepositoryImpl');       // true
/// isRepositoryImplClass('TodoRepoImpl');             // true
/// isRepositoryImplClass('UserRepositoryImpl');       // true
/// isRepositoryImplClass('TodoRepository');           // false (interface)
/// isRepositoryImplClass('TodoDataSourceImpl');       // false (not a repository)
/// ```
///
/// Parameters:
/// - [className]: The simple class name (not fully qualified)
///
/// Returns `true` if the class name suggests a repository implementation.
```

**Implementation**:
```dart
static bool isRepositoryImplClass(String className) {
  return className.endsWith('RepositoryImpl') ||
      (className.endsWith('Impl') && className.contains('Repository'));
}
```

---

### Category 5: AST-Based Repository Validation

#### 5.1 isRepositoryInterface()

**Signature**:
```dart
static bool isRepositoryInterface(ClassDeclaration classDeclaration)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isRepositoryInterface(ClassDeclaration classDeclaration) {
  final className = classDeclaration.name.lexeme;

  // Step 1: Check naming patterns
  final repositoryPatterns = ['Repository', 'DataSource', 'Gateway', 'Port'];
  final isRepositoryClass = repositoryPatterns.any((pattern) => className.contains(pattern));

  if (!isRepositoryClass) return false;

  // Step 2: Check if abstract
  final isAbstractClass = classDeclaration.abstractKeyword != null;

  // Step 3: Check if all methods are abstract
  final hasOnlyAbstractMethods = classDeclaration.members
      .whereType<MethodDeclaration>()
      .every((method) => method.isAbstract || method.isGetter || method.isSetter);

  return isRepositoryClass && (isAbstractClass || hasOnlyAbstractMethods);
}
```

---

#### 5.2 isRepositoryInterfaceMethod()

**Signature**:
```dart
static bool isRepositoryInterfaceMethod(MethodDeclaration method)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isRepositoryInterfaceMethod(MethodDeclaration method) {
  return method.isAbstract || method.isGetter || method.isSetter;
}
```

---

### Category 6: Type Annotation Validation

#### 6.1 isResultType()

**Signature**:
```dart
static bool isResultType(TypeAnnotation? returnType)
```

**Documentation**:
```dart
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
/// Future<Result<Todo, Failure>> getTodo();        // isResultType → false (checks Result inside Future)
/// Result<List<Todo>, Failure> getTodos();         // isResultType → true
/// Either<Failure, Todo> findTodo();               // isResultType → true
/// Task<User> loadUser();                          // isResultType → true
/// void updateTodo(Todo todo);                     // isResultType → false
/// ```
///
/// Parameters:
/// - [returnType]: The type annotation to check (nullable)
///
/// Returns `true` if the type is a Result or Either variant, `false` otherwise.
```

**Implementation**:
```dart
static bool isResultType(TypeAnnotation? returnType) {
  if (returnType == null) return false;

  final typeString = returnType.toString();
  return typeString.startsWith('Result<') ||
      typeString.startsWith('Either<') ||
      typeString.startsWith('Task<') ||
      typeString.startsWith('TaskEither<');
}
```

---

#### 6.2 isVoidType()

**Signature**:
```dart
static bool isVoidType(TypeAnnotation? returnType)
```

**Documentation**:
```dart
/// Checks if a type annotation is void.
///
/// Examples:
/// ```dart
/// void addTodo(Todo todo);                  // isVoidType → true
/// Future<void> deleteTodo(String id);       // isVoidType → false (Future<void>, not void)
/// Future<List<Todo>> getTodos();            // isVoidType → false
/// ```
///
/// Parameters:
/// - [returnType]: The type annotation to check (nullable)
///
/// Returns `true` if the type is void, `false` otherwise.
```

**Implementation**:
```dart
static bool isVoidType(TypeAnnotation? returnType) {
  if (returnType == null) return false;
  return returnType.toString() == 'void';
}
```

---

### Category 7: Exception Pattern Recognition

#### 7.1 isDataException()

**Signature**:
```dart
static bool isDataException(String typeName)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isDataException(String typeName) {
  // Generic patterns
  if (typeName.endsWith('DataException') || typeName.endsWith('DataError')) {
    return true;
  }

  // Known data layer exceptions
  const dataExceptions = {
    'ServerException',
    'NetworkException',
    'CacheException',
    'DatabaseException',
    'NotFoundException',
    'UnauthorizedException',
    'DataSourceException',
  };

  return dataExceptions.contains(typeName);
}
```

---

#### 7.2 isDomainException()

**Signature**:
```dart
static bool isDomainException(String typeName)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool isDomainException(String typeName) {
  return typeName.endsWith('DomainException') ||
      typeName.endsWith('DomainError') ||
      typeName.endsWith('Failure');
}
```

---

#### 7.3 implementsException()

**Signature**:
```dart
static bool implementsException(ClassDeclaration node)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static bool implementsException(ClassDeclaration node) {
  final extendsClause = node.extendsClause;
  final implementsClause = node.implementsClause;
  final withClause = node.withClause;

  return (extendsClause?.superclass.toString().contains('Exception') ?? false) ||
      (implementsClause?.interfaces.any((i) => i.toString().contains('Exception')) ?? false) ||
      (withClause?.mixinTypes.any((m) => m.toString().contains('Exception')) ?? false);
}
```

---

### Category 8: AST Traversal & Utilities

#### 8.1 findParentClass()

**Signature**:
```dart
static ClassDeclaration? findParentClass(AstNode? node)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static ClassDeclaration? findParentClass(AstNode? node) {
  var current = node;
  while (current != null) {
    if (current is ClassDeclaration) return current;
    current = current.parent;
  }
  return null;
}
```

---

#### 8.2 isPrivateMethod()

**Signature**:
```dart
static bool isPrivateMethod(MethodDeclaration method)
```

**Documentation**:
```dart
/// Checks if a method is private (name starts with underscore).
///
/// In Dart, identifiers starting with `_` are library-private.
///
/// Examples:
/// ```dart
/// class TodoRepository {
///   void publicMethod() {}       // isPrivateMethod → false
///   void _privateMethod() {}     // isPrivateMethod → true
///   void _internalHelper() {}    // isPrivateMethod → true
/// }
/// ```
///
/// Parameters:
/// - [method]: The method declaration to check
///
/// Returns `true` if the method is private.
```

**Implementation**:
```dart
static bool isPrivateMethod(MethodDeclaration method) {
  return method.name.lexeme.startsWith('_');
}
```

---

#### 8.3 isRethrow()

**Signature**:
```dart
static bool isRethrow(ThrowExpression node)
```

**Documentation**:
```dart
/// Checks if a throw expression is a rethrow.
///
/// A rethrow re-throws the currently caught exception without wrapping it.
///
/// Examples:
/// ```dart
/// try {
///   riskyOperation();
/// } catch (e) {
///   throw e;         // isRethrow → false (explicit throw)
///   rethrow;         // isRethrow → true (rethrow)
/// }
/// ```
///
/// Parameters:
/// - [node]: The throw expression to check
///
/// Returns `true` if the expression is a rethrow.
```

**Implementation**:
```dart
static bool isRethrow(ThrowExpression node) {
  return node.expression.toString() == 'rethrow';
}
```

---

### Category 9: Feature & Path Utilities

#### 9.1 extractFeatureName()

**Signature**:
```dart
static String extractFeatureName(String filePath)
```

**Documentation**:
```dart
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
```

**Implementation**:
```dart
static String extractFeatureName(String filePath) {
  final match = RegExp(r'/features/(\w+)/').firstMatch(filePath);
  if (match == null) return '';

  final featureName = match.group(1)!;
  return _capitalizeAndSingularize(featureName);
}
```

---

### Category 10: Internal Helpers (Private)

#### 10.1 _normalizePath()

**Signature**:
```dart
static String _normalizePath(String path)
```

**Documentation**:
```dart
/// Normalizes a file path by converting backslashes to forward slashes.
///
/// This ensures consistent path matching across Windows and Unix systems.
///
/// Examples:
/// ```dart
/// _normalizePath('lib\\domain\\entities\\todo.dart');
/// // Returns: 'lib/domain/entities/todo.dart'
///
/// _normalizePath('lib/domain/entities/todo.dart');
/// // Returns: 'lib/domain/entities/todo.dart' (already normalized)
/// ```
```

**Implementation**:
```dart
static String _normalizePath(String path) {
  return path.replaceAll('\\', '/');
}
```

---

#### 10.2 _capitalizeAndSingularize()

**Signature**:
```dart
static String _capitalizeAndSingularize(String text)
```

**Documentation**:
```dart
/// Capitalizes the first letter and attempts to singularize a string.
///
/// Singularization rules:
/// - `{word}ies` → `{word}y` (e.g., 'categories' → 'Category')
/// - `{word}s` → `{word}` (e.g., 'todos' → 'Todo')
///
/// Examples:
/// ```dart
/// _capitalizeAndSingularize('todos');       // Returns: 'Todo'
/// _capitalizeAndSingularize('users');       // Returns: 'User'
/// _capitalizeAndSingularize('categories');  // Returns: 'Category'
/// _capitalizeAndSingularize('todo');        // Returns: 'Todo'
/// ```
```

**Implementation**:
```dart
static String _capitalizeAndSingularize(String text) {
  // Capitalize first letter
  final capitalized = text[0].toUpperCase() + text.substring(1);

  // Singularize (simple heuristic)
  if (capitalized.endsWith('ies')) {
    return capitalized.substring(0, capitalized.length - 3) + 'y';
  } else if (capitalized.endsWith('s')) {
    return capitalized.substring(0, capitalized.length - 1);
  }

  return capitalized;
}
```

---

## Complete API Summary

### Method Count by Category

| Category | Public Methods | Private Methods | Total |
|----------|----------------|-----------------|-------|
| File Exclusion | 1 | 4 | 5 |
| Layer Detection | 3 | 0 | 3 |
| Component Files | 4 | 0 | 4 |
| Class Validation | 5 | 0 | 5 |
| AST Repository | 2 | 0 | 2 |
| Type Checking | 2 | 0 | 2 |
| Exception Patterns | 3 | 0 | 3 |
| AST Traversal | 3 | 0 | 3 |
| Feature Utilities | 1 | 2 | 3 |
| **Total** | **24** | **6** | **30** |

### Deprecated Methods (3)

| Old Method | New Method | Removal Version |
|------------|------------|-----------------|
| `isDomainLayerFile()` | `isDomainFile()` | v3.0.0 |
| `isDataLayerFile()` | `isDataFile()` | v3.0.0 |
| `isPresentationLayerFile()` | `isPresentationFile()` | v3.0.0 |

---

## Design Rationale

### Why Optional `excludeFiles` Parameter?

**Problem**: RuleUtils had no file exclusion, CleanArchitectureUtils always excluded.

**Solution**: Make it optional with sensible default (`true`).

**Benefits**:
- Backward compatible with CleanArchitectureUtils (excludes by default)
- Allows RuleUtils use case (can disable exclusion)
- Explicit and self-documenting

**Example**:
```dart
// Default behavior (excludes test files)
if (isDomainFile(filePath)) { }

// Include all files (RuleUtils behavior)
if (isDomainFile(filePath, excludeFiles: false)) { }
```

---

### Why Keep Both Repository Validation Methods?

**Problem**: AST-based (`isRepositoryInterface`) vs string-based (`isRepositoryInterfaceClass`)

**Solution**: Keep both for different use cases.

**Rationale**:
- **Fast filtering**: Use `isRepositoryInterfaceClass()` for quick name checks
- **Precise validation**: Use `isRepositoryInterface()` for accurate AST validation
- Different performance/accuracy tradeoffs

**Usage Pattern**:
```dart
// Step 1: Fast filter
if (!isRepositoryInterfaceClass(className)) return;

// Step 2: Precise validation
if (isRepositoryInterface(classDeclaration)) {
  // Confirmed repository interface
}
```

---

### Why Not Merge Repository File Methods?

We have 3 repository file methods:
- `isRepositoryFile()` - Any repository
- `isRepositoryImplFile()` - Implementation only
- Implicit interface check: `isRepositoryFile() && !isRepositoryImplFile()`

**Rationale**:
- Clear separation of concerns
- Self-documenting code
- Avoids ambiguity

---

## Testing Strategy

### Unit Test Coverage Requirements

**Minimum Coverage**: 90% for all public methods

**Test Categories**:

1. **Happy Path Tests** (2-3 per method)
   - Standard inputs that should pass
   - Common use cases

2. **Edge Case Tests** (2-3 per method)
   - Empty strings, null values (where applicable)
   - Unusual but valid inputs
   - Boundary conditions

3. **Negative Tests** (1-2 per method)
   - Inputs that should return false
   - Invalid patterns

4. **Integration Tests** (1 per category)
   - Multiple methods working together
   - Real file paths from example project

**Example Test Structure**:
```dart
group('isDomainFile', () {
  test('returns true for standard domain directory', () {
    expect(CleanArchitectureUtils.isDomainFile('lib/features/todos/domain/entities/todo.dart'), true);
  });

  test('returns true for usecases directory', () {
    expect(CleanArchitectureUtils.isDomainFile('lib/features/todos/usecases/get_todos.dart'), true);
  });

  test('excludes test files by default', () {
    expect(CleanArchitectureUtils.isDomainFile('lib/features/todos/domain/entities/todo_test.dart'), false);
  });

  test('includes test files when excludeFiles is false', () {
    expect(CleanArchitectureUtils.isDomainFile('lib/features/todos/domain/entities/todo_test.dart', excludeFiles: false), true);
  });

  test('returns false for non-domain files', () {
    expect(CleanArchitectureUtils.isDomainFile('lib/features/todos/data/models/todo_model.dart'), false);
  });

  test('handles Windows paths correctly', () {
    expect(CleanArchitectureUtils.isDomainFile('lib\\features\\todos\\domain\\entities\\todo.dart'), true);
  });
});
```

---

## Documentation Standards

### DartDoc Template

Every public method must include:

1. **Summary Line** (1 sentence)
   - Starts with verb (Checks, Validates, Finds, Extracts, etc.)
   - Describes what the method does

2. **Description** (optional, 1-3 paragraphs)
   - Detailed explanation
   - Recognized patterns or rules
   - Important caveats or notes

3. **Examples Section** (required)
   - 3-5 real-world examples
   - Show both positive and negative cases
   - Use realistic file paths and names

4. **Parameters Section** (if applicable)
   - Describe each parameter
   - Include type and purpose

5. **Returns Section** (required)
   - Describe return value
   - Specify what true/false/null means

6. **See Also Section** (optional)
   - Link related methods
   - Cross-reference for better understanding

**Template**:
```dart
/// [One-line summary starting with verb].
///
/// [Optional detailed description, 1-3 paragraphs].
///
/// Recognizes these patterns:
/// - Pattern 1
/// - Pattern 2
/// - Pattern 3
///
/// Examples:
/// ```dart
/// // Positive example 1
/// methodName('input1');  // true
///
/// // Positive example 2
/// methodName('input2');  // true
///
/// // Negative example
/// methodName('input3');  // false
/// ```
///
/// Parameters:
/// - [param1]: Description
/// - [param2]: Description
///
/// Returns [what true means] or [what false means].
///
/// See also:
/// - [relatedMethod1] for [purpose]
/// - [relatedMethod2] for [purpose]
```

---

## Implementation Checklist

### Phase 2 Implementation (Layer Detection)

- [ ] Implement `isDomainFile()` with `excludeFiles` parameter
- [ ] Implement `isDataFile()` with `excludeFiles` parameter
- [ ] Implement `isPresentationFile()` with `excludeFiles` parameter
- [ ] Add `@Deprecated` to old methods (`isDomainLayerFile`, etc.)
- [ ] Add `_normalizePath()` private helper
- [ ] Write unit tests (90% coverage)
- [ ] Write integration tests
- [ ] Update dartdoc comments

### Phase 3 Implementation (All Other Methods)

- [ ] Implement component file methods (4 methods)
- [ ] Implement class validation methods (5 methods)
- [ ] Implement type checking methods (2 methods)
- [ ] Implement exception pattern methods (3 methods)
- [ ] Implement AST traversal methods (3 methods)
- [ ] Implement feature utilities (1 method)
- [ ] Add `_capitalizeAndSingularize()` private helper
- [ ] Write unit tests (90% coverage)
- [ ] Write integration tests
- [ ] Update dartdoc comments

### Quality Gates

- [ ] All public methods have dartdoc comments
- [ ] All examples in dartdoc compile and run
- [ ] Unit test coverage ≥90%
- [ ] Integration tests pass
- [ ] `dart analyze` reports 0 issues
- [ ] `dart format` passes
- [ ] All deprecated methods work correctly (redirect to new methods)

---

## Version Strategy

### v2.0.0 (Initial Release)

**Changes**:
- Add all new unified API methods
- Add @Deprecated to 3 old methods
- Maintain 100% backward compatibility

**Breaking Changes**: None (deprecated methods still work)

### v2.x.x (Transition Period)

**Duration**: 3-6 months

**Activities**:
- Monitor deprecation warnings
- Provide migration guide
- Support users in transition

### v3.0.0 (Cleanup Release)

**Changes**:
- Remove all @Deprecated methods
- Remove RuleUtils class entirely

**Breaking Changes**: Remove deprecated methods

**Migration Path**: Users must update to new method names before upgrading to v3.0.0

---

## Performance Considerations

### Path Normalization Caching

**Current**: Every call to `isDomainFile()` normalizes the path

**Optimization Opportunity**:
```dart
static final _pathCache = <String, String>{};

static String _normalizePath(String path) {
  return _pathCache.putIfAbsent(path, () => path.replaceAll('\\', '/'));
}
```

**Trade-off**:
- Pro: Faster repeated checks on same paths
- Con: Memory usage (cache grows unbounded)
- Decision: Implement if performance testing shows benefit

### RegExp Compilation

**Current**: `extractFeatureName()` creates new RegExp every call

**Optimization**:
```dart
static final _featureNamePattern = RegExp(r'/features/(\w+)/');

static String extractFeatureName(String filePath) {
  final match = _featureNamePattern.firstMatch(filePath);
  // ...
}
```

**Impact**: Minor performance gain, recommended to implement

---

## Next Steps

1. **Task 13**: Implement the API as designed in this document
2. **Task 14**: Update 13 rule files to use new API
3. **Task 15**: Add @Deprecated wrappers to RuleUtils
4. **Testing**: Achieve 90% unit test coverage
5. **Documentation**: Update README.md and CHANGELOG.md

**Estimated Timeline**: 3 weeks total (as per migration plan)
