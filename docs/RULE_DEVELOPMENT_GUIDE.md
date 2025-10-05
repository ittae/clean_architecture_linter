# Rule Development Guide

A comprehensive guide for developing new lint rules in the Clean Architecture Linter package.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Mixin-Based Development](#mixin-based-development)
3. [Rule Categories](#rule-categories)
4. [AST Pattern Matching](#ast-pattern-matching)
5. [Testing Strategy](#testing-strategy)
6. [Performance Best Practices](#performance-best-practices)

## Quick Start

### 5-Minute Rule Template

```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
import '../../mixins/exception_validation_mixin.dart';  // If needed

/// Rule description and examples.
///
/// ✅ Good: [show correct code]
/// ❌ Bad: [show violation]
class MyNewRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {  // Add mixins

  const MyNewRule() : super(code: _code);

  static const _code = LintCode(
    name: 'my_new_rule',
    problemMessage: 'What went wrong',
    correctionMessage: 'How to fix it',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    // Layer check
    if (!CleanArchitectureUtils.isDomainFile(resolver.path)) return;

    // AST visitor
    context.registry.addClassDeclaration((node) {
      _checkClass(node, reporter);
    });
  }

  void _checkClass(ClassDeclaration node, ErrorReporter reporter) {
    // Use mixin methods
    if (!isExceptionClass(node)) return;

    // Validation logic
    if (_violates(node)) {
      reporter.atNode(node, _code);
    }
  }

  bool _violates(ClassDeclaration node) {
    // Your logic
    return false;
  }
}
```

## Mixin-Based Development

### Available Mixins

#### 1. ExceptionValidationMixin (225 lines)
**Use When**: Validating exception classes, naming, or layer-specific exceptions

**Methods**:
```dart
// Class checks
bool isExceptionClass(ClassDeclaration node)
bool isAllowedWithoutPrefix(String className)
bool isGenericExceptionName(String className)

// Layer detection
bool isDataLayerException(String typeName)

// Name generation
String suggestFeaturePrefix(String className, String filePath)
String extractFeatureName(String filePath)
```

**Example**:
```dart
class ExceptionNamingConventionRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {

  void _checkException(ClassDeclaration node, ...) {
    if (!isExceptionClass(node)) return;

    final className = node.name.lexeme;
    if (isGenericExceptionName(className)) {
      final suggestion = suggestFeaturePrefix(className, filePath);
      // Report violation with suggestion
    }
  }
}
```

#### 2. RepositoryRuleVisitor (238 lines)
**Use When**: Validating repository patterns, interfaces, or implementations

**Methods**:
```dart
// Class checks
bool isRepositoryImplementation(ClassDeclaration classNode)
bool isRepositoryInterface(ClassDeclaration classNode)

// Method checks
bool shouldSkipMethod(MethodDeclaration method)
bool isAllowedRepositoryThrow(ThrowExpression node)
```

**Example**:
```dart
class RepositoryNoThrowRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor {

  void _checkThrow(ThrowExpression node, ...) {
    final classNode = findParentClass(node);
    if (!isRepositoryImplementation(classNode)) return;

    if (!isAllowedRepositoryThrow(node)) {
      // Report violation
    }
  }
}
```

#### 3. ReturnTypeValidationMixin (129 lines)
**Use When**: Checking Result/Either return types

**Methods**:
```dart
bool isResultReturnType(TypeAnnotation? returnType)
bool shouldSkipMethod(MethodDeclaration method)
```

**Example**:
```dart
class RepositoryMustReturnResultRule extends CleanArchitectureLintRule
    with RepositoryRuleVisitor, ReturnTypeValidationMixin {

  void _checkMethod(MethodDeclaration method, ...) {
    if (shouldSkipMethod(method)) return;

    final returnType = method.returnType;
    if (!isResultReturnType(returnType)) {
      // Report violation
    }
  }
}
```

### Creating a New Mixin

**When to Create**:
- Logic duplicated across 3+ rules
- Cohesive validation concern (exceptions, repositories, etc.)
- Reusable across rule categories

**Template**:
```dart
/// Mixin description and usage examples.
///
/// Provides:
/// - List capabilities
/// - When to use
///
/// Used by:
/// - `rule_one.dart`
/// - `rule_two.dart`
mixin MyValidationMixin {
  /// Public validation method with examples.
  bool myCheck(AstNode node) {
    return _internalHelper(node.toString());
  }

  /// Private helper (not exposed to rules).
  bool _internalHelper(String input) {
    return input.isNotEmpty;
  }
}
```

## Rule Categories

### Domain Layer Rules
**Directory**: `lib/src/rules/domain_rules/`

**Common Patterns**:
- Check `isDomainFile(filePath)` first
- Validate entity immutability
- Check use case structure
- Validate repository abstractions

**Example Checks**:
```dart
// Entity must be immutable
context.registry.addFieldDeclaration((node) {
  if (node.fields.isFinal) return;  // ✅ Immutable
  reporter.atNode(node, _code);     // ❌ Mutable field
});

// UseCase must have single responsibility
if (classNode.members.whereType<MethodDeclaration>().length > 1) {
  // Multiple methods = multiple responsibilities
}
```

### Data Layer Rules
**Directory**: `lib/src/rules/data_rules/`

**Common Patterns**:
- Check `isDataFile(filePath)` first
- Validate repository implementations
- Check data source patterns
- Validate Result type usage

**Example Checks**:
```dart
// Repository must return Result
if (isRepositoryImplementation(classNode)) {
  for (final method in classNode.members.whereType<MethodDeclaration>()) {
    if (!isResultReturnType(method.returnType)) {
      reporter.atNode(method, _code);
    }
  }
}

// DataSource should not return Result
if (isDataSourceClass(className)) {
  if (isResultReturnType(method.returnType)) {
    reporter.atNode(method, _code);
  }
}
```

### Presentation Layer Rules
**Directory**: `lib/src/rules/presentation_rules/`

**Common Patterns**:
- Check `isPresentationFile(filePath)` first
- Validate state management patterns
- Check Freezed usage
- Validate AsyncValue usage

**Example Checks**:
```dart
// State must use AsyncValue
if (_isStateClass(node)) {
  for (final field in node.members.whereType<FieldDeclaration>()) {
    if (_isErrorField(field)) {
      reporter.atNode(field, _code);  // Don't store errors in state
    }
  }
}

// Must use Riverpod @riverpod annotation
if (_isNotifierClass(node)) {
  if (!_hasRiverpodAnnotation(node)) {
    reporter.atNode(node, _code);
  }
}
```

### Cross-Layer Rules
**Directory**: `lib/src/rules/cross_layer/`

**Common Patterns**:
- Check imports between layers
- Validate dependency direction
- Check circular dependencies

**Example Checks**:
```dart
// Check import direction
context.registry.addImportDirective((node) {
  final currentLayer = _getLayer(resolver.path);
  final importedLayer = _getLayer(node.uri.stringValue);

  if (_violatesDependencyRule(currentLayer, importedLayer)) {
    reporter.atNode(node, _code);
  }
});
```

## AST Pattern Matching

### Common AST Patterns

#### 1. Class Declaration
```dart
context.registry.addClassDeclaration((node) {
  final className = node.name.lexeme;
  final isAbstract = node.abstractKeyword != null;
  final extendsClause = node.extendsClause;
  final implementsClause = node.implementsClause;
  final members = node.members;

  // Validation
});
```

#### 2. Method Declaration
```dart
context.registry.addMethodDeclaration((method) {
  final methodName = method.name.lexeme;
  final returnType = method.returnType;
  final parameters = method.parameters?.parameters ?? [];
  final isAbstract = method.isAbstract;
  final isPrivate = methodName.startsWith('_');

  // Validation
});
```

#### 3. Field Declaration
```dart
context.registry.addFieldDeclaration((field) {
  final isFinal = field.fields.isFinal;
  final type = field.fields.type;

  for (final variable in field.fields.variables) {
    final name = variable.name.lexeme;
    // Validation
  }
});
```

#### 4. Import Directive
```dart
context.registry.addImportDirective((node) {
  final importUri = node.uri.stringValue;
  if (importUri == null) return;

  // Check for violations
  if (importUri.startsWith('package:flutter/')) {
    reporter.atNode(node, _code);
  }
});
```

#### 5. Throw Expression
```dart
context.registry.addThrowExpression((node) {
  if (CleanArchitectureUtils.isRethrow(node)) return;  // Skip rethrows

  final exceptionType = node.expression.toString();
  // Validation
});
```

#### 6. Constructor Declaration
```dart
context.registry.addConstructorDeclaration((constructor) {
  final className = constructor.parent?.name.lexeme;
  final parameters = constructor.parameters.parameters;

  for (final param in parameters) {
    final type = param.type;
    // Validation
  }
});
```

### Traversing AST

```dart
// Find parent class
final classNode = CleanArchitectureUtils.findParentClass(node);
if (classNode == null) return;  // Not inside a class

// Find parent method
final method = node.thisOrAncestorOfType<MethodDeclaration>();
if (method != null) {
  // Inside a method
}

// Find constructor
final constructor = node.thisOrAncestorOfType<ConstructorDeclaration>();
if (constructor != null) {
  // Inside a constructor
}

// Check if in try-catch
final tryCatch = node.thisOrAncestorOfType<TryStatement>();
if (tryCatch != null) {
  // Inside try-catch
}
```

## Testing Strategy

### Unit Tests for Mixins

```dart
// test/mixins/my_validation_mixin_test.dart
import 'package:test/test.dart';

class TestClass with MyValidationMixin {}

void main() {
  late TestClass testClass;

  setUp(() {
    testClass = TestClass();
  });

  test('validates correctly', () {
    expect(testClass.myCheck(validNode), isTrue);
    expect(testClass.myCheck(invalidNode), isFalse);
  });
}
```

### Integration Tests for Rules

```dart
// test/rules/my_new_rule_test.dart
void main() {
  group('MyNewRule', () {
    test('detects violations', () async {
      final rule = MyNewRule();
      // Setup test code with violation
      // Run rule
      // Assert violation detected
    });

    test('allows valid code', () async {
      final rule = MyNewRule();
      // Setup valid code
      // Run rule
      // Assert no violations
    });
  });
}
```

### Example-Based Testing

```dart
// example/lib/bad_examples/my_new_rule_bad.dart
/// ❌ This should trigger my_new_rule
class ViolatingClass {
  // Code that violates the rule
}

// example/lib/good_examples/my_new_rule_good.dart
/// ✅ This follows the rule correctly
class CompliantClass {
  // Code that follows the rule
}
```

## Performance Best Practices

### 1. Early Returns
```dart
// ✅ Good: Exit early
if (!CleanArchitectureUtils.isDomainFile(filePath)) return;
if (!isExceptionClass(node)) return;
// Expensive checks

// ❌ Bad: Nested conditions
if (CleanArchitectureUtils.isDomainFile(filePath)) {
  if (isExceptionClass(node)) {
    // Deep nesting
  }
}
```

### 2. Name-Based Filtering First
```dart
// ✅ Good: Fast name check first
if (!className.contains('Repository')) return;
if (!isRepositoryInterface(node)) return;  // Expensive AST check

// ❌ Bad: AST check first
if (isRepositoryInterface(node)) {  // Expensive
  // Then name check
}
```

### 3. Cache Computed Values
```dart
// ✅ Good: Compute once
final classNode = findParentClass(node);
if (classNode == null) return;
final className = classNode.name.lexeme;
// Use className multiple times

// ❌ Bad: Repeated computation
if (findParentClass(node)?.name.lexeme == 'Foo') { }
if (findParentClass(node)?.name.lexeme.endsWith('Impl')) { }
```

### 4. Use Pre-Compiled Regex
```dart
// ✅ Good: Compile once
static final _pattern = RegExp(r'/features/(\w+)/');

String extractFeature(String path) {
  return _pattern.firstMatch(path)?.group(1) ?? '';
}

// ❌ Bad: Compile every time
String extractFeature(String path) {
  return RegExp(r'/features/(\w+)/').firstMatch(path)?.group(1) ?? '';
}
```

### 5. Minimize String Operations
```dart
// ✅ Good: Normalize once
final normalized = _normalizePath(filePath);
return normalized.contains('/domain/') || normalized.contains('/usecases/');

// ❌ Bad: Multiple normalizations
return _normalizePath(filePath).contains('/domain/') ||
       _normalizePath(filePath).contains('/usecases/');
```

## Checklist for New Rules

- [ ] Rule file created in correct directory
- [ ] Extends `CleanArchitectureLintRule`
- [ ] Uses appropriate mixins (if applicable)
- [ ] Has comprehensive dartdoc with examples
- [ ] Registered in `lib/clean_architecture_linter.dart`
- [ ] Good examples in `example/lib/good_examples/`
- [ ] Bad examples in `example/lib/bad_examples/`
- [ ] Unit tests written
- [ ] Integration tests written
- [ ] Tested with `dart run custom_lint` in example
- [ ] All tests passing (`dart pub test`)
- [ ] No warnings (`dart analyze`)
- [ ] Formatted (`dart format .`)
- [ ] Documentation updated (README.md, CLAUDE.md)

## Common Pitfalls

### 1. Forgetting File Exclusion
```dart
// ❌ Bad: No file check
void runRule(...) {
  context.registry.addClassDeclaration(...);
}

// ✅ Good: Base class handles it automatically
void runRule(...) {
  // CleanArchitectureLintRule already excludes test files
  context.registry.addClassDeclaration(...);
}
```

### 2. Not Handling Null Types
```dart
// ❌ Bad: Assumes non-null
final returnType = method.returnType;
if (returnType.toString().contains('Result')) { }  // NPE!

// ✅ Good: Check for null
final returnType = method.returnType;
if (returnType == null) return;
if (returnType.toString().contains('Result')) { }
```

### 3. Over-Reporting Violations
```dart
// ❌ Bad: Report in test files
context.registry.addClassDeclaration((node) {
  reporter.atNode(node, _code);  // Will report in tests too!
});

// ✅ Good: Base class filters test files
// runRule() only called for non-test files
```

### 4. Vague Error Messages
```dart
// ❌ Bad: Not actionable
static const _code = LintCode(
  name: 'my_rule',
  problemMessage: 'This is wrong',
  correctionMessage: 'Fix it',
);

// ✅ Good: Clear and actionable
static const _code = LintCode(
  name: 'repository_must_return_result',
  problemMessage: 'Repository methods must return Result<T, F> type',
  correctionMessage: 'Change return type to Result<T, Failure> and handle errors with try-catch',
);
```

## Resources

- [Analyzer API Docs](https://pub.dev/documentation/analyzer/latest/)
- [Custom Lint Builder](https://pub.dev/packages/custom_lint_builder)
- [AST Node Reference](https://pub.dev/documentation/analyzer/latest/dart_ast_ast/dart_ast_ast-library.html)
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Design decisions
- [CLAUDE.md](../CLAUDE.md) - Project overview

---

Happy linting! 🎯
