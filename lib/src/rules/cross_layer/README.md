# Cross-Layer Rules

This directory contains lint rules that validate architectural boundaries and dependencies **across multiple layers** of Clean Architecture.

## Rules in this Category

### 1. Layer Dependency Rule (`layer_dependency_rule.dart`)
**Purpose**: Enforces proper dependency direction between architectural layers.

**What it checks**:
- ✅ Presentation layer can depend on: Domain layer only
- ✅ Data layer can depend on: Domain layer only
- ✅ Domain layer: Must remain pure (no external dependencies)
- ❌ Presentation → Data imports are violations

**Example violation**:
```dart
// ❌ BAD: Presentation importing from Data layer
import 'package:app/features/todos/data/models/todo_model.dart';

// ✅ GOOD: Presentation importing from Domain layer
import 'package:app/features/todos/domain/entities/todo.dart';
```

---

### 2. Circular Dependency Rule (`circular_dependency_rule.dart`)
**Purpose**: Detects circular dependencies between files and architectural layers.

**What it checks**:
- ❌ Direct circular imports (A imports B, B imports A)
- ❌ Indirect circular imports (A → B → C → A)
- ❌ Layer-level circular dependencies

**Why it matters**: Circular dependencies make code harder to test, maintain, and understand. They can lead to initialization order issues and tight coupling.

---

### 3. Boundary Crossing Rule (`boundary_crossing_rule.dart`)
**Purpose**: Validates core boundary crossing patterns in Clean Architecture.

**What it checks**:
- ✅ Dependencies flow inward only (Presentation → Domain ← Data)
- ✅ Use interfaces for cross-layer dependencies when appropriate
- ❌ No direct instantiation of classes from outer layers

**Example**:
```dart
// ✅ GOOD: Using Domain interface in Presentation
class TodoNotifier {
  final TodoRepository repository; // Domain interface
}

// ❌ BAD: Using Data class directly in Presentation
class TodoNotifier {
  final TodoRepositoryImpl repository; // Data implementation
}
```

---

### 4. Test Coverage Rule (`test_coverage_rule.dart`)
**Purpose**: Enforces test coverage for critical Clean Architecture components.

**What it checks** (configurable):
- ✅ **UseCase**: Core business logic must be tested
- ✅ **Repository Implementation**: Data layer integration must be tested
- ⚠️ **DataSource Implementation**: Either has tests OR abstract interface (for mocking)
- ✅ **Riverpod Notifier**: State management logic must be tested

**Configuration**:
```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
      check_usecases: true       # Default: true
      check_repositories: true   # Default: true
      check_datasources: true    # Default: true
      check_notifiers: true      # Default: true
```

**Test file naming convention**:
```
lib/features/user/domain/usecases/get_user_usecase.dart
→ test/features/user/domain/usecases/get_user_usecase_test.dart
```

---

## Why Cross-Layer?

These rules validate interactions **between** layers rather than within a single layer:

- **Single-layer rules** (domain_rules, data_rules, presentation_rules): Validate code within one layer
- **Cross-layer rules** (this directory): Validate dependencies, boundaries, and interactions **across** layers

This separation makes the linting architecture clearer and easier to maintain.

---

## Testing

All cross-layer rules are tested in the example project and unit tests. To verify they work:

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
- [Main Linter Plugin](../../../clean_architecture_linter.dart)
