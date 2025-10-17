# Data Layer Rules

This directory contains lint rules that enforce Clean Architecture principles **within the Data layer**.

## Data Layer Responsibilities

The Data layer contains:
- **Models**: Freezed data transfer objects (contain Entities + metadata)
- **Repository Implementations**: Concrete implementations of Domain Repository interfaces
- **DataSources**: External data access (Remote, Local, Cache)
- **Failures**: Data layer error types (converted to Domain exceptions)

The Data layer must:
- ✅ Implement Domain Repository **interfaces**
- ✅ Catch exceptions from DataSources and convert to `Result` types
- ✅ Use **Models** (not Entities directly)
- ✅ Throw specific **Data exceptions** in DataSources
- ❌ Never throw exceptions directly from Repository implementations

---

## Rules in this Category (12 rules)

### 1. Model Structure Rule (`model_structure_rule.dart`)
**Purpose**: Enforces proper Freezed Model structure with Entity composition.

**What it checks**:
- ✅ Models must use `@freezed` annotation
- ✅ Models must contain an Entity (composition, not duplication)
- ✅ Models can have additional fields for metadata (e.g., `lastUpdated`, `isLocal`)

**Example**:
```dart
// ✅ GOOD: Model with Entity composition
@freezed
class TodoModel with _$TodoModel {
  const factory TodoModel({
    required Todo entity,        // Entity composition
    DateTime? lastUpdated,       // Additional metadata
    @Default(false) bool isLocal,
  }) = _TodoModel;

  factory TodoModel.fromJson(Map<String, dynamic> json) =>
      _$TodoModelFromJson(json);
}

// ❌ BAD: Duplicating Entity fields
@freezed
class TodoModel with _$TodoModel {
  const factory TodoModel({
    required String id,          // ❌ Duplicates Entity fields
    required String title,
    required bool isCompleted,
  }) = _TodoModel;
}
```

---

### 2. DataSource Abstraction Rule (`datasource_abstraction_rule.dart`)
**Purpose**: Enforces proper DataSource abstraction patterns.

**What it checks**:
- ✅ DataSources should have abstract interfaces (for testability)
- ✅ DataSources belong in Data layer (not Domain)
- ✅ DataSource methods return Models (not Entities)
- ⚠️ Concrete DataSource without interface → warning (unless test file exists)

**Example**:
```dart
// ✅ GOOD: Abstract DataSource with implementation
abstract class TodoRemoteDataSource {
  Future<List<TodoModel>> getTodos();
}

class TodoRemoteDataSourceImpl implements TodoRemoteDataSource {
  @override
  Future<List<TodoModel>> getTodos() async {
    // API implementation
  }
}

// ❌ BAD: DataSource returns Entity (should return Model)
abstract class TodoRemoteDataSource {
  Future<List<Todo>> getTodos(); // ❌ Should return TodoModel
}
```

---

### 3. DataSource No Result Return Rule (`datasource_no_result_return_rule.dart`)
**Purpose**: Enforces that DataSources throw exceptions instead of returning `Result`.

**What it checks**:
- ❌ DataSource methods should NOT return `Result<T, F>` types
- ✅ DataSources should throw exceptions for errors

**Error handling flow**:
```
DataSource → throws Exception (NotFoundException, NetworkException, etc.)
Repository → catches Exception → returns Result<Entity, Failure>
UseCase → unwraps Result → Entity OR throw Domain Exception
```

**Example**:
```dart
// ❌ BAD: DataSource returns Result
Future<Result<TodoModel, Failure>> getTodo(String id) async {
  // ❌ Should throw exceptions instead
}

// ✅ GOOD: DataSource throws exceptions
Future<TodoModel> getTodo(String id) async {
  final response = await client.get('/todos/$id');

  if (response.statusCode == 404) {
    throw NotFoundException('Todo not found: $id'); // ✓ Throws exception
  }

  return TodoModel.fromJson(response.data);
}
```

---

### 4. Repository Must Return Result Rule (`repository_must_return_result_rule.dart`)
**Purpose**: Enforces that Repository implementations return `Result` types.

**What it checks**:
- ✅ Repository methods must return `Result<T, Failure>` or `Either<L, R>`
- ❌ Non-void methods that don't return Result types trigger violations

**Example**:
```dart
// ✅ GOOD: Repository returns Result
class TodoRepositoryImpl implements TodoRepository {
  @override
  Future<Result<List<Todo>, TodoFailure>> getTodos() async {
    try {
      final models = await remoteDataSource.getTodos();
      final entities = models.map((model) => model.entity).toList();
      return Result.success(entities);
    } catch (e) {
      return Result.failure(TodoFailure.fromException(e));
    }
  }
}

// ❌ BAD: Repository throws exceptions
class TodoRepositoryImpl implements TodoRepository {
  Future<List<Todo>> getTodos() async {
    return await remoteDataSource.getTodos(); // ❌ Can throw exceptions
  }
}
```

---

### 5. Repository No Throw Rule (`repository_no_throw_rule.dart`)
**Purpose**: Ensures Repository implementations don't throw exceptions directly.

**What it checks**:
- ❌ No `throw` statements in public Repository methods
- ✅ Exceptions should be caught and converted to `Result.failure`
- ✅ Rethrows in catch blocks are allowed
- ✅ Private helper methods can throw

**Example**:
```dart
// ✅ GOOD: Repository catches and converts exceptions
@override
Future<Result<Todo, TodoFailure>> getTodo(String id) async {
  try {
    final model = await remoteDataSource.getTodo(id);
    return Result.success(model.entity);
  } on NotFoundException catch (e) {
    return Result.failure(TodoFailure.notFound(e.message));
  } on NetworkException catch (e) {
    return Result.failure(TodoFailure.networkError(e.message));
  } catch (e) {
    return Result.failure(TodoFailure.unknown(e.toString()));
  }
}

// ❌ BAD: Repository throws exceptions
@override
Future<Result<Todo, TodoFailure>> getTodo(String id) async {
  if (!_isValidId(id)) {
    throw ValidationException('Invalid ID'); // ❌ Direct throw
  }
  // ...
}
```

---

### 6. DataSource Exception Types Rule (`datasource_exception_types_rule.dart`)
**Purpose**: Enforces use of defined Data layer exceptions only.

**Allowed Data exceptions**:
- `NotFoundException` (404 errors)
- `UnauthorizedException` (401/403 errors)
- `NetworkException` (connection errors)
- `ServerException` (5xx errors)
- `DataSourceException` (data source errors)
- `CacheException` (cache errors)
- `DatabaseException` (database errors)

**What it checks**:
- ✅ DataSources should use defined Data exceptions
- ❌ Don't use generic `Exception`, `StateError`, or custom exception types

**Example**:
```dart
// ✅ GOOD: Using defined Data exceptions
if (response.statusCode == 404) {
  throw NotFoundException('Todo not found: $id');
}

if (response.statusCode == 401) {
  throw UnauthorizedException('Authentication required');
}

if (response.statusCode >= 500) {
  throw ServerException('Server error: ${response.statusCode}');
}

// ❌ BAD: Using generic or custom exceptions
throw Exception('Error occurred'); // ❌ Generic
throw StateError('Invalid state'); // ❌ Dart built-in
throw CustomDataException('Error'); // ❌ Custom type
```

---

### 7. Failure Naming Convention Rule (`failure_naming_convention_rule.dart`)
**Purpose**: Enforces feature-prefixed naming for Failure classes.

**Naming pattern**: `{Feature}Failure`

**Example**:
```dart
// ✅ GOOD: Feature-prefixed Failures
@freezed
class TodoFailure with _$TodoFailure {
  const factory TodoFailure.notFound(String message) = TodoNotFoundFailure;
  const factory TodoFailure.networkError(String message) = TodoNetworkFailure;
}

@freezed
class UserFailure with _$UserFailure {
  const factory UserFailure.authError(String message) = UserAuthFailure;
}

// ❌ BAD: Generic Failure without feature prefix
@freezed
class Failure with _$Failure {
  const factory Failure.notFound(String message) = NotFoundFailure;
}
```

---

### 8. Model Entity Direct Access Rule (`model_entity_direct_access_rule.dart`)
**Purpose**: Enforces using `.toEntity()` method instead of direct `.entity` property access in Data layer.

**What it checks**:
- ❌ No direct `.entity` property access in Data layer (outside extensions)
- ✅ Use `.toEntity()` method for Model → Entity conversion
- ✅ Exception: Direct `.entity` access allowed inside extension methods

**Why this matters**:
- Provides explicit conversion boundary between Model and Entity
- Allows future conversion logic changes in one place
- Makes architectural boundaries clear in code

**Example**:
```dart
// ✅ GOOD: Using toEntity() method
class TodoRepositoryImpl implements TodoRepository {
  @override
  Future<Result<List<Todo>, Failure>> getTodos() async {
    try {
      final models = await dataSource.getTodos();
      return Success(models.map((m) => m.toEntity()).toList()); // ✓ Method call
    } on DataException catch (e) {
      return Failure(TodoFailure.fromDataException(e));
    }
  }
}

// ❌ BAD: Direct .entity access
class TodoRepositoryImpl implements TodoRepository {
  @override
  Future<Result<List<Todo>, Failure>> getTodos() async {
    try {
      final models = await dataSource.getTodos();
      return Success(models.map((m) => m.entity).toList()); // ❌ Direct access
    } on DataException catch (e) {
      return Failure(TodoFailure.fromDataException(e));
    }
  }
}

// ✅ GOOD: Direct access allowed in extension (implementation)
extension TodoModelX on TodoModel {
  Todo toEntity() => entity; // ✓ Allowed here - this is the conversion logic

  static TodoModel fromEntity(Todo entity) {
    return TodoModel(entity: entity);
  }
}
```

---

## Error Handling Flow

```
1. DataSource: Throws specific Data exceptions
   ↓
2. Repository: Catches exceptions → Converts to Failure → Returns Result<T, Failure>
   ↓
3. UseCase: Unwraps Result → Returns Entity OR throws Domain Exception
   ↓
4. Presentation: Catches Domain Exception → Updates UI state
```

---

## Best Practices

1. **Use Models for Data Transfer**: Contain Entity + metadata
2. **Handle Errors at Boundaries**: DataSource throws, Repository converts to Result
3. **Use Defined Exceptions**: Stick to the allowed Data exception types
4. **Test Repository Implementations**: Critical integration points
5. **Follow Naming Conventions**: Feature-prefixed Failures

---

## Testing

Data layer rules are tested in the example project:

```bash
# Analyze this package
dart analyze

# Run tests
dart test

# Test with example project
cd example && dart run custom_lint
```

---

## Related Documentation

- [Clean Architecture Guide](../../../../doc/CLEAN_ARCHITECTURE_GUIDE.md)
- [Error Handling Guide](../../../../doc/ERROR_HANDLING_GUIDE.md)
- [Cross-Layer Rules](../cross_layer/README.md)
- [Domain Layer Rules](../domain_rules/README.md)
- [Presentation Layer Rules](../presentation_rules/README.md)
