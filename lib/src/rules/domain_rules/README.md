# Domain Layer Rules

This directory contains lint rules that enforce Clean Architecture principles **within the Domain layer**.

## Domain Layer Responsibilities

The Domain layer contains:
- **Entities**: Core business objects (use Freezed)
- **UseCases**: Business logic operations
- **Repository Interfaces**: Abstract contracts for data access
- **Domain Exceptions/Failures**: Business-specific error types

The Domain layer must:
- ✅ Remain **pure** (no framework dependencies)
- ✅ Define **abstract** interfaces for external dependencies
- ✅ Handle errors through **Domain exceptions**
- ❌ Never depend on Data or Presentation layers

---

## Rules in this Category

### 1. Domain Purity Rule (`domain_purity_rule.dart`)
**Purpose**: Ensures Domain layer remains pure and framework-independent.

**What it checks**:
- ❌ No Flutter dependencies (`package:flutter`)
- ❌ No Riverpod dependencies (`package:flutter_riverpod`)
- ❌ No HTTP client dependencies (`package:dio`, `package:http`)
- ✅ Allowed: Dart core libraries, domain-specific packages (e.g., `dartz`, `freezed_annotation`)

---

### 2. Dependency Inversion Rule (`dependency_inversion_rule.dart`)
**Purpose**: Enforces Dependency Inversion Principle (DIP) in Domain layer.

**What it checks**:
- ✅ Domain defines **abstract** Repository interfaces
- ✅ UseCases depend on Repository **interfaces** (not implementations)
- ❌ No direct dependencies on concrete Data layer classes

**Example**:
```dart
// ✅ GOOD: UseCase depends on Repository interface
class GetTodoUseCase {
  final TodoRepository repository; // Abstract interface

  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);
    return result.when(
      success: (todo) => todo,
      failure: (failure) => throw failure.toException(),
    );
  }
}

// ❌ BAD: UseCase depends on Repository implementation
class GetTodoUseCase {
  final TodoRepositoryImpl repository; // Concrete implementation
}
```

---

### 3. Repository Interface Rule (`repository_interface_rule.dart`)
**Purpose**: Enforces proper Repository interface patterns in Domain layer.

**What it checks**:
- ✅ Repository interfaces must be **abstract**
- ✅ Repository methods must have no implementation (abstract methods only)
- ✅ Repository interfaces belong in Domain layer

**Example**:
```dart
// ✅ GOOD: Abstract Repository interface
abstract class TodoRepository {
  Future<List<Todo>> getTodos();
  Future<Todo> getTodo(String id);
  Future<void> createTodo(Todo todo);
}

// ❌ BAD: Concrete Repository class
class TodoRepository {
  Future<List<Todo>> getTodos() async {
    // ❌ Has implementation in Domain layer
  }
}
```

---

### 4. UseCase No Result Return Rule (`usecase_no_result_return_rule.dart`)
**Purpose**: Enforces pass-through style UseCase return types.

**What it checks**:
- ❌ UseCase methods should NOT return `Result<T, F>`/`Either<L, R>` wrappers
- ✅ UseCases should return `Future<Entity>` directly
- ✅ UseCases may throw domain exceptions only for business validation

**Error handling flow**:
```
Repository → Entity (exceptions pass-through)
UseCase → validation + pass-through → Entity OR throw Domain Exception
Presentation → AsyncValue.guard()/when(error) handles exception state
```

**Example**:
```dart
// ❌ BAD: UseCase returns Result wrapper
Future<Result<Todo, TodoFailure>> call(String id) async {
  return repository.getTodo(id);
}

// ✅ GOOD: UseCase uses pass-through
Future<Todo> call(String id) async {
  if (id.isEmpty) {
    throw const InvalidInputException.withCode('errorValidationIdRequired');
  }
  return repository.getTodo(id);
}
```

---

### 5. UseCase Must Convert Failure Rule (`usecase_must_convert_failure_rule.dart`)
**Purpose**: (Legacy/no-op) kept for backward compatibility after pass-through migration.

**What it checks**:
- ✅ UseCase should validate input and throw domain exceptions when needed
- ❌ Don't throw raw Failure objects

**Example**:
```dart
// ✅ GOOD: Convert Failure to Exception
final result = await repository.getTodo(id);
return result.when(
  success: (todo) => todo,
  failure: (failure) => throw failure.toException(), // ✓ Converts to exception
);

// ❌ BAD: Throw raw Failure
return result.when(
  success: (todo) => todo,
  failure: (failure) => throw failure, // ✗ Raw Failure object
);
```

---

### 6. Exception Naming Convention Rule (`exception_naming_convention_rule.dart`)
**Purpose**: Enforces feature-prefixed naming for Domain exceptions.

**Naming pattern**: `{Feature}{ExceptionType}`

**Example**:
```dart
// ✅ GOOD: Feature-prefixed exceptions
class TodoNotFoundException implements Exception {}
class TodoInvalidInputException implements Exception {}
class UserAuthException implements Exception {}

// ❌ BAD: Generic exceptions without feature prefix
class NotFoundException implements Exception {}
class ValidationException implements Exception {}
```

**Why**: Prevents naming conflicts and clearly indicates which feature an exception belongs to.

---

### 7. Exception Message Localization Rule (`exception_message_localization_rule.dart`)
**Purpose**: Enforces Korean language for exception messages (project-specific).

**What it checks**:
- ✅ Exception messages should be in Korean
- ❌ English exception messages trigger warnings

**Example**:
```dart
// ✅ GOOD: Korean messages
throw TodoNotFoundException('할 일을 찾을 수 없습니다: $id');

// ⚠️ WARNING: English messages
throw TodoNotFoundException('Todo not found: $id');
```

**Note**: This is a project-specific rule. Adjust or disable if your project uses different languages.

---

## Best Practices

1. **Keep Domain Pure**: No framework dependencies
2. **Use Abstractions**: Define Repository interfaces
3. **Handle Errors Properly**: Convert Failure → Exception in UseCases
4. **Follow Naming Conventions**: Feature-prefixed exceptions
5. **Test Everything**: UseCases contain core business logic

---

## Testing

Domain layer rules are tested in the example project:

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
- [Data Layer Rules](../data_rules/README.md)
- [Presentation Layer Rules](../presentation_rules/README.md)
