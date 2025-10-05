# Clean Architecture Linter - Architecture Design Document

This document explains the architectural decisions, design patterns, and implementation strategies used in the Clean Architecture Linter package.

## Table of Contents

1. [Design Principles](#design-principles)
2. [Mixin-Based Architecture](#mixin-based-architecture)
3. [Code Organization Strategy](#code-organization-strategy)
4. [Utility Class Design](#utility-class-design)
5. [Error Handling Flow](#error-handling-flow)
6. [Performance Considerations](#performance-considerations)
7. [Evolution and Refactoring](#evolution-and-refactoring)

## Design Principles

### 1. DRY (Don't Repeat Yourself)
**Problem**: Early implementation had duplicated validation logic across 10+ rules
- Exception validation duplicated in 3 rules (106 lines eliminated)
- Repository validation duplicated in 3 rules (64 lines eliminated)
- Return type checking duplicated in 2 rules (minimal duplication)

**Solution**: Mixin-based architecture extracted common logic into reusable components
- `ExceptionValidationMixin` - 225 lines of reusable exception validation
- `RepositoryRuleVisitor` - 238 lines of reusable repository validation
- `ReturnTypeValidationMixin` - 129 lines of reusable return type checking

**Result**: 170 lines eliminated (13.6% reduction), improved maintainability

### 2. Composition Over Inheritance
**Pattern**: Use Dart mixins for code reuse instead of deep inheritance hierarchies

**Why Mixins?**
- **Multiple Composition**: Rules can use multiple mixins (exception + return type)
- **No Diamond Problem**: Dart mixins avoid multiple inheritance issues
- **Semantic Clarity**: `with ExceptionValidationMixin` clearly states capabilities
- **Easy Testing**: Mixins can be unit tested independently

**Example**:
```dart
// ✅ Good: Composition with mixins
class RepositoryMustReturnResultRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {
  // Inherits validation from both mixins
}

// ❌ Bad: Deep inheritance hierarchy
class BaseRepositoryRule extends CleanArchitectureLintRule { ... }
class RepositoryMustReturnResultRule extends BaseRepositoryRule { ... }
```

### 3. Single Responsibility Principle
Each component has one clear responsibility:

- **Mixins**: Provide validation logic for specific concerns
- **Rules**: Implement specific lint checks using mixin logic
- **Utilities**: Offer layer detection and type checking
- **Base Class**: Handle test file exclusion and plugin integration

### 4. Interface Segregation
**Pattern**: Small, focused mixins rather than one large base class

**Benefits**:
- Rules only import validation they need
- Reduces coupling between unrelated validations
- Easier to understand and test individual mixins

**Example**:
```dart
// ✅ Good: Use only needed mixins
class ExceptionNamingConventionRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {
  // Only exception validation, no repository logic
}

// ❌ Bad: Monolithic base class with all validations
class AllValidationsBaseRule extends CleanArchitectureLintRule {
  bool isExceptionClass(...) { }
  bool isRepositoryInterface(...) { }
  bool isResultType(...) { }
  // Too many responsibilities
}
```

## Mixin-Based Architecture

### Exception Validation Mixin
**Purpose**: Validate exception naming, feature prefixes, and layer-specific exception types

**Core Methods**:
```dart
mixin ExceptionValidationMixin {
  // Class validation
  bool isExceptionClass(ClassDeclaration node);

  // Naming validation
  bool isAllowedWithoutPrefix(String className);
  bool isGenericExceptionName(String className);

  // Layer detection
  bool isDataLayerException(String typeName);

  // Suggestion generation
  String suggestFeaturePrefix(String className, String filePath);
  String extractFeatureName(String filePath);
}
```

**Design Decisions**:
1. **Feature Name Extraction**: Uses regex pattern `/features/(\w+)/` for feature-based projects
2. **Singularization Logic**: Simple heuristic (`todos` → `Todo`, `categories` → `Category`)
3. **Allowed Exceptions**: Maintains whitelist for base exceptions (`Exception`, `Error`, `Failure`)
4. **Data Layer Detection**: Pattern matching for `DataException`, `NetworkException`, etc.

**Used By**:
- `exception_naming_convention_rule.dart`
- `datasource_exception_types_rule.dart`
- `presentation_no_data_exceptions_rule.dart`

### Repository Rule Visitor
**Purpose**: Identify repository interfaces and implementations, validate repository patterns

**Core Methods**:
```dart
mixin RepositoryRuleVisitor {
  // Class identification
  bool isRepositoryImplementation(ClassDeclaration classNode);
  bool isRepositoryInterface(ClassDeclaration classNode);

  // Method validation
  bool shouldSkipMethod(MethodDeclaration method);
  bool isAllowedRepositoryThrow(ThrowExpression node);
}
```

**Design Decisions**:
1. **Implementation Detection**: Looks for `Impl` suffix or concrete methods
2. **Interface Detection**: Checks for abstract keyword or all-abstract methods
3. **Private Method Handling**: Automatically skips methods starting with `_`
4. **Test Context**: Allows throw in test methods via context analysis

**Used By**:
- `repository_must_return_result_rule.dart`
- `repository_no_throw_rule.dart`
- `repository_interface_rule.dart`

### Return Type Validation Mixin
**Purpose**: Validate Result/Either return types and method signatures

**Core Methods**:
```dart
mixin ReturnTypeValidationMixin {
  // Type checking
  bool isResultReturnType(TypeAnnotation? returnType);

  // Method filtering
  bool shouldSkipMethod(MethodDeclaration method);
}
```

**Design Decisions**:
1. **Type Patterns**: Supports `Result<T, F>`, `Either<L, R>`, `Task<T>`, `TaskEither<L, R>`
2. **Recursive Checking**: Detects Result inside Future (`Future<Result<T, F>>`)
3. **Method Skipping**: Common logic for private methods and test contexts

**Used By**:
- `datasource_no_result_return_rule.dart`
- `usecase_no_result_return_rule.dart`
- `repository_must_return_result_rule.dart`

## Code Organization Strategy

### Directory Structure Rationale

```
lib/src/
├── clean_architecture_linter_base.dart  # Core utilities (1,014 lines)
├── mixins/                              # Validation logic (592 lines)
│   ├── exception_validation_mixin.dart
│   ├── repository_rule_visitor.dart
│   └── return_type_validation_mixin.dart
├── rules/
│   ├── domain_rules/                    # 7 rules
│   ├── data_rules/                      # 8 rules
│   ├── presentation_rules/              # 3 rules
│   └── cross_layer/                     # 2 rules
├── utils/                               # Additional utilities
└── validators/                          # Custom validators
```

**Why This Structure?**

1. **Mixins Separate from Rules**:
   - Mixins are reusable across multiple rules
   - Clear separation between validation logic and rule implementation
   - Easier to unit test mixins independently

2. **Layer-Based Rule Organization**:
   - Matches Clean Architecture layer structure
   - Easy to find rules by architectural layer
   - `cross_layer/` for rules that span multiple layers

3. **Utilities Centralized**:
   - `CleanArchitectureUtils` provides common utilities
   - Single source of truth for layer detection
   - Reduces import complexity

## Utility Class Design

### CleanArchitectureUtils Categories

The utility class is organized into 10 logical categories:

1. **File Exclusion & Filtering** (lines 17-119)
   - `shouldExcludeFile()` - Central exclusion logic
   - Excludes test files, generated files, build artifacts

2. **Layer File Detection** (lines 121-238)
   - `isDomainFile()`, `isDataFile()`, `isPresentationFile()`
   - Supports multiple directory naming conventions

3. **Component-Specific Detection** (lines 240-320)
   - `isUseCaseFile()`, `isDataSourceFile()`, `isRepositoryFile()`
   - More specific than layer detection

4. **Class Name Validation** (lines 322-483)
   - `isUseCaseClass()`, `isRepositoryClass()`, `isRepositoryImplClass()`
   - Name-based quick filtering

5. **AST-Based Repository Validation** (lines 485-579)
   - `isRepositoryInterface()`, `isRepositoryInterfaceMethod()`
   - Precise but slower AST analysis

6. **Type Annotation Validation** (lines 581-664)
   - `isResultType()`, `isVoidType()`
   - Recursive type checking

7. **Exception Pattern Recognition** (lines 666-782)
   - `isDataException()`, `isDomainException()`, `implementsException()`
   - Layer-specific exception identification

8. **AST Traversal & Utilities** (lines 784-865)
   - `findParentClass()`, `isPrivateMethod()`, `isRethrow()`
   - Common AST operations

9. **Feature & Path Utilities** (lines 867-909)
   - `extractFeatureName()` - Feature name extraction
   - Pre-compiled regex for performance

10. **Deprecated Methods** (lines 942-964)
    - Backward compatibility for v2.x
    - Marked for removal in v3.0.0

### Design Decisions

1. **Static Methods**: All utilities are static for easy access without instantiation
2. **Comprehensive Documentation**: Every method has detailed dartdoc with examples
3. **Performance Optimization**: Pre-compiled regex patterns, early returns
4. **Path Normalization**: Handles Windows and Unix path separators
5. **Flexible Exclusion**: `excludeFiles` parameter for fine-grained control

## Error Handling Flow

### Clean Architecture Error Handling Pattern

```
Data Layer → Domain Layer → Presentation Layer
  ↓              ↓              ↓
Exceptions    Result<T, F>   AsyncValue<T>
```

### Layer-Specific Error Handling

**Data Layer** (DataSource + Repository):
```dart
// ❌ Wrong: Direct exceptions
class TodoRepositoryImpl {
  Future<Todo> getTodo(String id) async {
    throw ServerException();  // Violates repository_no_throw
  }
}

// ✅ Correct: Result type
class TodoRepositoryImpl {
  Future<Result<Todo, Failure>> getTodo(String id) async {
    try {
      final data = await dataSource.getTodo(id);
      return Success(data);
    } on ServerException catch (e) {
      return Failure(TodoFailure.server(e.message));
    }
  }
}
```

**Domain Layer** (UseCase):
```dart
// ❌ Wrong: Result type leaking
class GetTodoUseCase {
  Future<Result<Todo, Failure>> call(String id) {  // Violates usecase_no_result_return
    return repository.getTodo(id);
  }
}

// ✅ Correct: Direct return or exception
class GetTodoUseCase {
  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);
    return result.when(
      success: (todo) => todo,
      failure: (failure) => throw failure,  // Convert to domain exception
    );
  }
}
```

**Presentation Layer** (Riverpod Notifier):
```dart
// ❌ Wrong: Manual error state management
@freezed
class TodoState with _$TodoState {
  factory TodoState({
    List<Todo> todos,
    String? errorMessage,  // Violates presentation_use_async_value
  }) = _TodoState;
}

// ✅ Correct: AsyncValue handles errors
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  Future<List<Todo>> build() async {
    return await getTodoUseCase();  // Riverpod auto-wraps in AsyncValue
  }
}
```

### Linter Enforcement

The linter enforces this flow with:
- `repository_must_return_result_rule` - Repositories must return Result
- `repository_no_throw_rule` - Repositories can't throw directly
- `datasource_exception_types_rule` - DataSources use data layer exceptions
- `usecase_no_result_return_rule` - UseCases don't return Result
- `presentation_no_data_exceptions_rule` - Presentation can't handle data exceptions
- `presentation_use_async_value_rule` - Presentation uses AsyncValue, not error fields

## Performance Considerations

### Optimization Strategies

1. **Early Returns**:
   ```dart
   static bool isDomainFile(String filePath) {
     if (excludeFiles && shouldExcludeFile(filePath)) return false;  // Exit early
     // Continue with expensive checks
   }
   ```

2. **Pre-Compiled Regex**:
   ```dart
   static final _featureNamePattern = RegExp(r'/features/(\w+)/');  // Compiled once
   ```

3. **Name-Based Filtering Before AST**:
   ```dart
   // Fast name check first
   if (!isRepositoryClass(className)) return;

   // Expensive AST analysis only if needed
   if (!isRepositoryInterface(classDeclaration)) { }
   ```

4. **Mixin Method Caching**:
   ```dart
   // Store parent class to avoid repeated traversal
   final classNode = findParentClass(node);
   if (classNode == null) return;
   ```

5. **String Operations Optimization**:
   ```dart
   // Normalize path once
   final normalized = _normalizePath(filePath);
   return normalized.contains('/domain/') || ...;
   ```

### Performance Benchmarks

- **File Exclusion**: <0.1ms per file
- **Layer Detection**: <0.5ms per file
- **AST Analysis**: 1-5ms per class
- **Mixin Validation**: 0.1-1ms per check

## Evolution and Refactoring

### Task 17: Mixin Refactoring Journey

**Phase 1: Analysis** (Task 16)
- Identified 1,384 lines across 10 rules
- Detected 3 main duplication patterns
- Created 3 mixins with 592 lines of logic

**Phase 2: Refactoring** (Task 17)
- Exception Rules: 496→390 lines (-21.4%)
- Repository Rules: 523→459 lines (-12.2%)
- Return Type Rules: 228→228 lines (0% - minimal duplication)
- Total: 1,247→1,077 lines (-13.6%, 170 lines saved)

**Phase 3: Quality Verification** (Task 18)
- Fixed 4 dart analyze warnings
- Fixed 6 deprecation warnings
- All 76 tests passing
- 0 errors, 0 warnings final state

**Phase 4: Documentation** (Task 19)
- Updated CLAUDE.md with new architecture
- Created ARCHITECTURE.md (this document)
- Documented all mixins and design decisions
- Added mixin usage guidelines

### Future Refactoring Opportunities

1. **Additional Mixins**:
   - `LayerBoundaryMixin` - Cross-layer import validation
   - `NamingConventionMixin` - Shared naming validation
   - `FreezedPatternMixin` - Freezed model validation

2. **Utility Enhancements**:
   - Extract feature detection to separate utility
   - Add caching for repeated path analysis
   - Improve type inference for generics

3. **Rule Consolidation**:
   - Merge similar cross-layer rules
   - Create configurable rule variants
   - Support custom naming patterns via config

### Version Evolution

- **v1.x**: Initial implementation with duplicated logic
- **v2.0**: Mixin-based architecture (current)
- **v3.0** (planned): Remove deprecated methods, add configuration system

---

## Summary

The Clean Architecture Linter uses a **mixin-based architecture** to eliminate code duplication while maintaining Clean Architecture principles:

1. **3 Core Mixins** provide reusable validation logic (592 lines)
2. **20 Lint Rules** compose mixins for specific checks
3. **CleanArchitectureUtils** offers comprehensive layer and type detection
4. **Base Class** handles test exclusion and plugin integration

**Key Benefits**:
- ✅ 13.6% code reduction (170 lines eliminated)
- ✅ Improved maintainability through composition
- ✅ Easier to add new rules (reuse existing mixins)
- ✅ Independent testing of validation logic
- ✅ Clear separation of concerns

This architecture ensures the linter remains maintainable, testable, and extensible as new Clean Architecture patterns emerge.
