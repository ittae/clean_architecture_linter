# Contributing to Clean Architecture Linter

Thank you for your interest in contributing! This guide will help you add new lint rules, fix bugs, and improve the package.

## Table of Contents

1. [Development Setup](#development-setup)
2. [Adding New Lint Rules](#adding-new-lint-rules)
3. [Using Mixins for Code Reuse](#using-mixins-for-code-reuse)
4. [Creating New Mixins](#creating-new-mixins)
5. [Testing Guidelines](#testing-guidelines)
6. [Code Style](#code-style)
7. [Pull Request Process](#pull-request-process)

## Development Setup

### Prerequisites
- Dart SDK 3.0.0 or higher
- Flutter 3.10.0 or higher (for testing with Flutter projects)
- Git

### Clone and Setup
```bash
# Clone the repository
git clone https://github.com/yourusername/clean_architecture_linter.git
cd clean_architecture_linter

# Install dependencies
dart pub get

# Run tests
dart pub test

# Run the linter on example project
cd example && dart run custom_lint
```

### Development Workflow
```bash
# Create a feature branch
git checkout -b feature/new-rule-name

# Make your changes
# ...

# Run tests
dart pub test

# Check code quality
dart analyze

# Format code (IMPORTANT: use 120 character line length)
dart format --line-length=120 .

# Test with example project
cd example && dart run custom_lint
```

## Adding New Lint Rules

### Step-by-Step Guide

#### 1. Identify the Rule Category
Determine which Clean Architecture layer your rule validates:
- **Domain Layer** (`lib/src/rules/domain_rules/`) - Business logic, entities, use cases
- **Data Layer** (`lib/src/rules/data_rules/`) - Repositories, data sources, models
- **Presentation Layer** (`lib/src/rules/presentation_rules/`) - UI, state management
- **Cross-Layer** (`lib/src/rules/cross_layer/`) - Boundary crossing, dependencies

#### 2. Check for Reusable Mixins
Review existing mixins in `lib/src/mixins/`:

| Mixin | Use When | Methods |
|-------|----------|---------|
| `ExceptionValidationMixin` | Validating exception naming, feature prefixes | `isExceptionClass()`, `isDataLayerException()`, `suggestFeaturePrefix()` |
| `RepositoryRuleVisitor` | Validating repository patterns | `isRepositoryImplementation()`, `isRepositoryInterface()`, `shouldSkipMethod()` |
| `ReturnTypeValidationMixin` | Checking return types (Result, Either) | `isResultReturnType()`, `shouldSkipMethod()` |

#### 3. Create the Rule File

**File naming convention**: `{rule_name}_rule.dart`

**Template**:
```dart
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../clean_architecture_linter_base.dart';
// Import mixins if needed
import '../../mixins/exception_validation_mixin.dart';

/// Brief description of what this rule enforces.
///
/// Detailed explanation with:
/// - What the rule checks
/// - Why it's important for Clean Architecture
/// - When it should be used
///
/// ✅ Good Example:
/// ```dart
/// // Show correct code
/// ```
///
/// ❌ Bad Example:
/// ```dart
/// // Show code that violates the rule
/// ```
class MyNewRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {  // Add mixins here

  const MyNewRule() : super(code: _code);

  static const _code = LintCode(
    name: 'my_new_rule',
    problemMessage: 'Clear description of what went wrong',
    correctionMessage: 'Actionable suggestion for fixing the issue',
  );

  @override
  void runRule(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final filePath = resolver.path;

    // Check layer (use CleanArchitectureUtils)
    if (!CleanArchitectureUtils.isDomainFile(filePath)) return;

    // Register AST visitors
    context.registry.addClassDeclaration((node) {
      _checkClass(node, reporter, resolver);
    });
  }

  void _checkClass(
    ClassDeclaration node,
    ErrorReporter reporter,
    CustomLintResolver resolver,
  ) {
    // Use mixin methods when possible
    if (!isExceptionClass(node)) return;  // From mixin

    // Custom validation logic
    final className = node.name.lexeme;
    if (_violatesRule(className)) {
      reporter.atNode(node, _code);
    }
  }

  bool _violatesRule(String className) {
    // Your validation logic
    return false;
  }
}
```

#### 4. Register the Rule

Add your rule to `lib/clean_architecture_linter.dart`:

```dart
import 'src/rules/domain_rules/my_new_rule.dart';

PluginBase createPlugin() => _CleanArchitectureLinterPlugin();

class _CleanArchitectureLinterPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
    // Existing rules...
    const MyNewRule(),  // Add here
  ];
}
```

#### 5. Add Good and Bad Examples

Create example files in `example/lib/`:

```dart
// example/lib/good_examples/my_new_rule_good.dart
/// ✅ Good: Demonstrates correct usage
class TodoException extends Exception {
  // Follows the rule
}

// example/lib/bad_examples/my_new_rule_bad.dart
/// ❌ Bad: Violates the rule
class Exception {  // Will be flagged
  // Violates the rule
}
```

#### 6. Write Tests

Create test file in `test/rules/`:

```dart
// test/rules/my_new_rule_test.dart
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  test('MyNewRule detects violations', () async {
    // Test implementation
  });

  test('MyNewRule allows valid code', () async {
    // Test implementation
  });
}
```

## Using Mixins for Code Reuse

### Example: Using Exception Validation Mixin

**Before** (duplicated logic):
```dart
class MyExceptionRule extends CleanArchitectureLintRule {
  void _checkClass(ClassDeclaration node, ...) {
    // ❌ Duplicated: Check if class extends Exception
    final extendsClause = node.extendsClause;
    if (extendsClause?.superclass.toString().contains('Exception') ?? false) {
      // Validation logic
    }

    // ❌ Duplicated: Suggest feature prefix
    final filePath = resolver.path;
    final match = RegExp(r'/features/(\w+)/').firstMatch(filePath);
    if (match != null) {
      final feature = match.group(1)!;
      // More duplicated logic...
    }
  }
}
```

**After** (using mixin):
```dart
class MyExceptionRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {

  void _checkClass(ClassDeclaration node, ...) {
    // ✅ Reuse mixin method
    if (!isExceptionClass(node)) return;

    // ✅ Reuse mixin method
    final className = node.name.lexeme;
    if (isGenericExceptionName(className)) {
      final suggestion = suggestFeaturePrefix(className, filePath);
      // Report violation with suggestion
    }
  }
}
```

### Available Mixin Methods

#### ExceptionValidationMixin
```dart
bool isExceptionClass(ClassDeclaration node)
bool isAllowedWithoutPrefix(String className)
bool isGenericExceptionName(String className)
bool isDataLayerException(String typeName)
String suggestFeaturePrefix(String className, String filePath)
String extractFeatureName(String filePath)
```

#### RepositoryRuleVisitor
```dart
bool isRepositoryImplementation(ClassDeclaration classNode)
bool isRepositoryInterface(ClassDeclaration classNode)
bool shouldSkipMethod(MethodDeclaration method)
bool isAllowedRepositoryThrow(ThrowExpression node)
```

#### ReturnTypeValidationMixin
```dart
bool isResultReturnType(TypeAnnotation? returnType)
bool shouldSkipMethod(MethodDeclaration method)
```

## Creating New Mixins

### When to Create a Mixin

Create a new mixin when:
1. **Validation logic is duplicated across 3+ rules**
2. **Logic is cohesive** (validates one specific concern)
3. **Logic is reusable** (not rule-specific)

### Mixin Template

```dart
// lib/src/mixins/my_validation_mixin.dart
import 'package:analyzer/dart/ast/ast.dart';
import '../clean_architecture_linter_base.dart';

/// Brief description of validation provided by this mixin.
///
/// This mixin provides:
/// - List of capabilities
/// - When to use it
/// - What it validates
///
/// Used by:
/// - `rule_one.dart`
/// - `rule_two.dart`
mixin MyValidationMixin {
  /// Validates specific aspect with detailed documentation.
  ///
  /// Parameters:
  /// - [node]: The AST node to validate
  ///
  /// Returns `true` if validation passes.
  ///
  /// Examples:
  /// ```dart
  /// if (myValidationMethod(node)) {
  ///   // Validation passed
  /// }
  /// ```
  bool myValidationMethod(AstNode node) {
    // Implementation
    return true;
  }

  /// Internal helper (private, don't expose)
  bool _helperMethod(String input) {
    return input.isNotEmpty;
  }
}
```

### Mixin Unit Tests

Create test file in `test/mixins/`:

```dart
// test/mixins/my_validation_mixin_test.dart
import 'package:test/test.dart';

// Create test harness
class TestClass with MyValidationMixin {}

void main() {
  late TestClass testClass;

  setUp(() {
    testClass = TestClass();
  });

  group('myValidationMethod', () {
    test('returns true for valid input', () {
      // Test implementation
    });

    test('returns false for invalid input', () {
      // Test implementation
    });
  });
}
```

### Mixin Documentation

Add README.md in `lib/src/mixins/`:

```markdown
# Mixins Documentation

## MyValidationMixin

**Purpose**: Brief description

**Methods**:
- `myValidationMethod()` - What it does

**Used By**:
- `rule_one.dart`
- `rule_two.dart`

**Example**:
\`\`\`dart
class MyRule extends CleanArchitectureLintRule
    with MyValidationMixin {
  // Use mixin methods
}
\`\`\`
```

## Testing Guidelines

### Test Structure

```
test/
├── mixins/                    # Mixin unit tests
│   ├── exception_validation_mixin_test.dart
│   └── repository_rule_visitor_test.dart
├── utils/                     # Utility tests
│   └── clean_architecture_utils_test.dart
└── rules/                     # Rule integration tests
    ├── domain_rules/
    ├── data_rules/
    └── presentation_rules/
```

### Writing Rule Tests

```dart
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';

void main() {
  group('MyNewRule', () {
    test('detects violation in bad code', () async {
      final rule = MyNewRule();
      // Create test resolver with bad code
      // Run rule
      // Assert violation detected
    });

    test('allows valid code', () async {
      final rule = MyNewRule();
      // Create test resolver with good code
      // Run rule
      // Assert no violations
    });

    test('provides helpful correction message', () async {
      // Test that correction message is actionable
    });
  });
}
```

### Running Tests

```bash
# Run all tests
dart pub test

# Run specific test file
dart pub test test/rules/my_new_rule_test.dart

# Run with coverage (if configured)
dart pub test --coverage

# Run tests in watch mode
dart pub test --watch
```

## Code Style

### Dart Style Guidelines

1. **Formatting**:
   - **Important**: This project uses 120 characters line length instead of the default 80
   - Use `dart format --line-length=120 .` before committing
   - Your IDE should be configured to use 120 characters (see `.vscode/settings.json`)
   - Follow naming conventions (camelCase, PascalCase)
   - Prefer expression bodies for simple functions

2. **Documentation**:
   - Add dartdoc comments to all public APIs
   - Include examples in documentation
   - Document parameters and return values

3. **Imports**:
   ```dart
   // 1. Dart imports
   import 'dart:async';

   // 2. Package imports
   import 'package:analyzer/dart/ast/ast.dart';

   // 3. Relative imports
   import '../../clean_architecture_linter_base.dart';
   import '../../mixins/exception_validation_mixin.dart';
   ```

4. **Error Messages**:
   - **problemMessage**: State what's wrong clearly
   - **correctionMessage**: Provide actionable fix

   ```dart
   static const _code = LintCode(
     name: 'repository_must_return_result',
     problemMessage: 'Repository methods must return Result<T, F> type',
     correctionMessage: 'Change return type to Result<T, Failure> and handle errors',
   );
   ```

### File Naming

- Rule files: `{rule_name}_rule.dart`
- Mixin files: `{mixin_name}_mixin.dart`
- Test files: `{file_name}_test.dart`

## Pull Request Process

### Before Submitting

1. **Run Quality Checks**:
   ```bash
   dart analyze
   dart format .
   dart pub test
   cd example && dart run custom_lint
   ```

2. **Update Documentation**:
   - Add rule to README.md
   - Update CLAUDE.md if architecture changed
   - Add entry to CHANGELOG.md

3. **Add Examples**:
   - Good examples in `example/lib/good_examples/`
   - Bad examples in `example/lib/bad_examples/`

### PR Template

```markdown
## Description
Brief description of the change

## Type of Change
- [ ] Bug fix
- [ ] New lint rule
- [ ] New mixin
- [ ] Documentation update
- [ ] Performance improvement

## Rule Details (if adding new rule)
- **Rule Name**: `my_new_rule`
- **Category**: Domain/Data/Presentation/Cross-Layer
- **What it checks**: ...
- **Why it matters**: ...

## Testing
- [ ] Unit tests added
- [ ] Integration tests added
- [ ] Tested with example project
- [ ] All existing tests pass

## Documentation
- [ ] Updated README.md
- [ ] Updated CLAUDE.md (if applicable)
- [ ] Added dartdoc comments
- [ ] Added examples

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] No warnings from `dart analyze`
- [ ] All tests passing
```

### Review Process

1. **Automated Checks**: CI runs tests and analysis
2. **Code Review**: Maintainers review changes
3. **Feedback**: Address review comments
4. **Approval**: Once approved, PR will be merged
5. **Release**: Changes included in next release

## Common Patterns

### Pattern 1: Class-Level Validation
```dart
context.registry.addClassDeclaration((node) {
  if (!CleanArchitectureUtils.isDomainFile(resolver.path)) return;
  // Validate class
});
```

### Pattern 2: Method-Level Validation
```dart
context.registry.addMethodDeclaration((method) {
  final classNode = CleanArchitectureUtils.findParentClass(method);
  if (classNode == null) return;
  // Validate method
});
```

### Pattern 3: Import Validation
```dart
context.registry.addImportDirective((node) {
  final importUri = node.uri.stringValue;
  if (importUri == null) return;
  // Validate import
});
```

### Pattern 4: Exception Handling
```dart
context.registry.addThrowExpression((node) {
  if (CleanArchitectureUtils.isRethrow(node)) return;  // Skip rethrows
  // Validate throw
});
```

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/yourusername/clean_architecture_linter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/clean_architecture_linter/discussions)
- **Documentation**: [ARCHITECTURE.md](ARCHITECTURE.md), [CLAUDE.md](CLAUDE.md)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Clean Architecture Linter! 🎉
