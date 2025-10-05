# Mixins - Reusable Rule Components

This directory contains reusable mixins and base classes that eliminate code duplication across lint rules by providing common validation patterns.

## Overview

These mixins consolidate shared logic for:
- **Return type validation**: Checking Result/Either types and void methods
- **Exception handling validation**: Detecting Data vs Domain exceptions
- **Repository identification**: Finding Repository interfaces and implementations

## Available Mixins

### 1. ReturnTypeValidationMixin

**Purpose**: Standardizes return type validation across rules that check method signatures.

**Use Cases**:
- Validating Result type presence/absence
- Skipping void methods from validation
- Filtering private methods and constructors

**Methods**:
```dart
bool isResultReturnType(TypeAnnotation returnType)
bool isVoidReturnType(TypeAnnotation returnType)
bool shouldSkipMethod(MethodDeclaration method)
TypeAnnotation? getMethodReturnType(MethodDeclaration method)
```

**Rules Using This**:
- `datasource_no_result_return_rule` - DataSource should not return Result
- `repository_must_return_result_rule` - Repository must return Result
- `usecase_no_result_return_rule` - UseCase should not return Result

**Example**:
```dart
class MyLintRule extends CleanArchitectureLintRule with ReturnTypeValidationMixin {
  void _checkMethod(MethodDeclaration method, ErrorReporter reporter) {
    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (returnType == null) return;

    if (isResultReturnType(returnType)) {
      reporter.atNode(returnType, myLintCode);
    }
  }
}
```

---

### 2. ExceptionValidationMixin

**Purpose**: Provides exception identification and naming convention validation.

**Use Cases**:
- Detecting Data layer vs Domain layer exceptions
- Validating feature-prefixed exception names
- Suggesting exception name improvements

**Key Constants**:
```dart
static const exceptionSuffixes        // Generic exception types needing prefix
static const dataLayerExceptions      // Data layer infrastructure exceptions
static const dartBuiltInExceptions    // Dart built-in exception types
```

**Methods**:
```dart
bool isExceptionClass(ClassDeclaration node)
bool isGenericExceptionName(String className)
bool isAllowedWithoutPrefix(String className)
bool isDataLayerException(String className)
String suggestFeaturePrefix(String className, String filePath)
bool throwsDataException(ThrowExpression throwExpression)
bool catchesDataException(CatchClause catchClause)
```

**Rules Using This**:
- `exception_naming_convention_rule` - Domain exception naming validation
- `exception_message_localization_rule` - Exception message language validation
- `presentation_no_data_exceptions_rule` - Presentation layer exception validation

**Example**:
```dart
class MyExceptionRule extends CleanArchitectureLintRule with ExceptionValidationMixin {
  void _checkException(ClassDeclaration node, ErrorReporter reporter) {
    if (!isExceptionClass(node)) return;

    final className = node.name.lexeme;

    if (isGenericExceptionName(className)) {
      final suggestion = suggestFeaturePrefix(className, resolver.path);
      reporter.atNode(node, LintCode(
        problemMessage: 'Exception "$className" needs feature prefix',
        correctionMessage: 'Rename to: $suggestion',
      ));
    }
  }
}
```

---

### 3. RepositoryRuleVisitor

**Purpose**: Standardizes Repository interface and implementation identification.

**Use Cases**:
- Distinguishing Repository interfaces from implementations
- Filtering Repository methods for validation
- Checking Repository naming conventions

**Methods**:
```dart
bool isRepositoryInterface(ClassDeclaration node)
bool isRepositoryImplementation(ClassDeclaration node)
bool implementsRepositoryInterface(ClassDeclaration node)
bool shouldValidateRepositoryMethod(MethodDeclaration method)
bool isAllowedRepositoryThrow(ThrowExpression throwNode)
String? getImplementedRepositoryInterface(ClassDeclaration node)
bool isValidRepositoryName(String className)
```

**Rules Using This**:
- `repository_interface_rule` - Repository interface validation
- `repository_must_return_result_rule` - Repository return type validation
- `repository_no_throw_rule` - Repository error handling validation
- `dependency_inversion_rule` - UseCase dependency validation

**Example**:
```dart
class MyRepositoryRule extends CleanArchitectureLintRule with RepositoryRuleVisitor {
  void _checkRepository(ClassDeclaration node, ErrorReporter reporter) {
    if (!isRepositoryImplementation(node)) return;

    final methods = node.members.whereType<MethodDeclaration>();
    for (final method in methods) {
      if (shouldValidateRepositoryMethod(method)) {
        // Validate Repository method patterns
      }
    }
  }
}
```

---

## Benefits of Using Mixins

### 1. **Code Duplication Elimination**
- **Before**: Each rule duplicates return type checking logic
- **After**: Single implementation in `ReturnTypeValidationMixin`
- **Impact**: 30-40% code reduction in affected rules

### 2. **Consistency**
- All rules use identical validation logic
- Changes propagate to all consumers automatically
- Reduces bugs from inconsistent implementations

### 3. **Maintainability**
- Single source of truth for common patterns
- Easier to add new validation methods
- Simplified debugging and testing

### 4. **Testability**
- Mixins can be tested independently
- Rule tests focus on rule-specific logic
- Higher test coverage with less code

### 5. **Clarity**
- Descriptive method names improve readability
- Self-documenting code through well-named helpers
- Easier onboarding for new contributors

---

## Design Principles

### Mixin Composition
```dart
// Multiple mixins can be combined
class MyRule extends CleanArchitectureLintRule
    with ReturnTypeValidationMixin, ExceptionValidationMixin {
  // Inherits methods from both mixins
}
```

### Naming Conventions
- Mixins end with `Mixin` suffix
- Base classes end with `Visitor` or `Base` suffix
- Methods use clear, descriptive names
- Constants use `UPPER_SNAKE_CASE`

### Documentation Standards
- Comprehensive dartdoc for all public members
- Usage examples in class-level documentation
- Clear parameter and return type descriptions
- Related rules listed in class documentation

---

## Testing

All mixins have corresponding test files in `test/src/mixins/`:
- `return_type_validation_mixin_test.dart` - 19 tests
- `exception_validation_mixin_test.dart` - 11 tests
- `repository_rule_visitor_test.dart` - 7 tests

Run mixin tests:
```bash
dart test test/src/mixins/
```

---

## Future Enhancements

Potential mixins to add:
- **FreezedValidationMixin**: Freezed class detection and validation
- **RiverpodValidationMixin**: Riverpod provider and notifier validation
- **LayerBoundaryMixin**: Cross-layer import detection
- **TestCoverageMixin**: Test file existence validation

---

## Related Documentation

- [Clean Architecture Guide](../../../docs/CLEAN_ARCHITECTURE_GUIDE.md)
- [Error Handling Guide](../../../docs/ERROR_HANDLING_GUIDE.md)
- [CleanArchitectureUtils](../utils/clean_architecture_utils.dart)
- [Rule Categories](../rules/README.md)
