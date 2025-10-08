# Contributing to Clean Architecture Linter

Thank you for considering contributing to Clean Architecture Linter! This document provides comprehensive guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Adding New Lint Rules](#adding-new-lint-rules)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to ensure a welcoming environment for all contributors.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/yourusername/clean_architecture_linter.git
   cd clean_architecture_linter
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/itae/clean_architecture_linter.git
   ```
4. Create a new branch for your feature or bugfix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Dart SDK 3.5.0 or higher
- Flutter (optional, for testing with Flutter projects)

### Installation

1. Install dependencies:
   ```bash
   dart pub get
   ```

2. Run tests to ensure everything is working:
   ```bash
   dart test
   ```

3. Test the linter on the example project:
   ```bash
   cd example
   dart pub get
   dart pub run custom_lint
   ```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug Fixes**: Fix issues reported in the issue tracker
- **New Lint Rules**: Add new rules for Clean Architecture validation
- **Documentation**: Improve README, API docs, or examples
- **Performance Improvements**: Optimize existing rules
- **Test Coverage**: Add missing tests
- **Examples**: Add more example code demonstrating rule violations

### Reporting Issues

Before creating a new issue:

1. Check if the issue already exists in the [issue tracker](https://github.com/itae/clean_architecture_linter/issues)
2. If reporting a bug, include:
   - Dart/Flutter version
   - Package version
   - Minimal reproduction code
   - Expected vs actual behavior
   - Error messages or stack traces

### Suggesting Features

1. Open an issue with the `enhancement` label
2. Describe the feature and its use case
3. Provide examples of how it would work
4. Discuss implementation approach if you have ideas

## Coding Standards

### Dart Style Guide

Follow the official [Dart Style Guide](https://dart.dev/effective-dart/style) with these specific requirements:

1. **Formatting**: Always run `dart format` before committing:
   ```bash
   dart format --line-length=120 .
   ```

2. **Analysis**: Ensure no analysis issues:
   ```bash
   dart analyze
   ```

3. **Naming Conventions**:
   - Files: `snake_case.dart`
   - Classes: `PascalCase`
   - Functions/Methods: `camelCase`
   - Constants: `lowerCamelCase` or `SCREAMING_CAPS` for global constants

4. **File Organization**:
   ```dart
   // 1. Dart imports
   import 'dart:async';

   // 2. Package imports
   import 'package:analyzer/dart/element/element.dart';

   // 3. Local imports
   import '../clean_architecture_linter_base.dart';

   // 4. Code
   ```

### Code Quality

1. **Documentation**:
   - Add dartdoc comments for all public APIs
   - Include examples in documentation when helpful
   ```dart
   /// Validates that entities don't depend on external layers.
   ///
   /// Example:
   /// ```dart
   /// // Bad: Entity depending on external package
   /// class User {
   ///   final http.Client client; // Violation
   /// }
   /// ```
   ```

2. **Error Messages**: Make them helpful and actionable:
   ```dart
   static const _code = LintCode(
     name: 'entities_no_external_dependencies',
     problemMessage: 'Entities should not depend on external packages or layers',
     correctionMessage: 'Remove external dependencies and keep entities pure with business logic only',
   );
   ```

3. **Performance**: Consider performance for large codebases:
   - Avoid unnecessary AST traversals
   - Cache results when appropriate
   - Use early returns to skip unnecessary checks

## Testing Guidelines

### Test Structure

1. **Unit Tests**: Test individual rule logic
2. **Integration Tests**: Test rules on example code
3. **Example Coverage**: Provide both valid and invalid examples

### Writing Tests

1. Create test files matching the source structure:
   ```
   lib/src/rules/domain_rules/entities_no_external_dependencies.dart
   test/rules/domain_rules/entities_no_external_dependencies_test.dart
   ```

2. Test both positive and negative cases:
   ```dart
   test('should detect external dependencies in entities', () {
     // Test that rule fires
   });

   test('should allow pure entities without dependencies', () {
     // Test that rule doesn't fire
   });
   ```

3. Add corresponding examples:
   ```
   example/lib/bad_examples/domain/entities/user_with_dependencies.dart
   example/lib/good_examples/domain/entities/user_pure.dart
   ```

### Running Tests

```bash
# Run all tests
dart test

# Run specific test file
dart test test/rules/domain_rules/entities_no_external_dependencies_test.dart

# Run with coverage
dart test --coverage=coverage
dart pub global activate coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info
```

## Commit Message Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature or rule
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, missing semicolons, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```bash
# New rule
feat(domain): add entities_implement_equality rule

# Bug fix
fix(data): correct repository abstract class detection

# Documentation
docs: update README with new configuration options

# Breaking change
feat(presentation)!: change bloc state management validation

BREAKING CHANGE: bloc_proper_state_management now requires different patterns
```

## Pull Request Process

### Before Submitting

1. **Update from upstream**:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks**:
   ```bash
   dart format --line-length=120 .
   dart analyze
   dart test
   cd example && dart pub run custom_lint
   ```

3. **Update documentation**:
   - Update README.md if adding features
   - Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/)
   - Add/update dartdoc comments

### PR Guidelines

1. **Title**: Use conventional commit format
2. **Description**: Include:
   - What changes were made
   - Why they were made
   - How to test the changes
   - Related issue numbers
3. **Size**: Keep PRs focused and reasonably sized
4. **Tests**: Include tests for new functionality
5. **Documentation**: Update relevant documentation

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] Added new tests
- [ ] Updated examples

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
```

## Adding New Lint Rules

### Step-by-Step Guide

1. **Determine the layer** (domain, data, or presentation)

2. **Create the rule file**:
   ```bash
   touch lib/src/rules/domain_rules/your_new_rule.dart
   ```

3. **Implement the rule**:
   ```dart
   import 'package:analyzer/dart/ast/ast.dart';
   import 'package:analyzer/error/listener.dart';
   import 'package:custom_lint_builder/custom_lint_builder.dart';

   class YourNewRule extends DartLintRule {
     const YourNewRule() : super(code: _code);

     static const _code = LintCode(
       name: 'your_new_rule',
       problemMessage: 'Description of the problem',
       correctionMessage: 'How to fix it',
     );

     @override
     void run(
       CustomLintResolver resolver,
       ErrorReporter reporter,
       CustomLintContext context,
     ) {
       // Implementation
     }
   }
   ```

4. **Register the rule** in `lib/clean_architecture_linter.dart`:
   ```dart
   @override
   List<LintRule> getLintRules(CustomLintConfigs configs) => [
     // ... existing rules
     const YourNewRule(),
   ];
   ```

5. **Add examples**:
   - Valid example: `example/lib/good_examples/...`
   - Invalid example: `example/lib/bad_examples/...`

6. **Write tests**:
   ```bash
   touch test/rules/domain_rules/your_new_rule_test.dart
   ```

7. **Update documentation**:
   - Add rule to README.md
   - Update rule count in package description

### Rule Implementation Best Practices

1. **Clear error messages**: Help developers understand and fix issues
2. **Performance**: Minimize AST traversals
3. **Accuracy**: Avoid false positives
4. **Configuration**: Consider if the rule needs configuration options

## Documentation

### Documentation Requirements

1. **Public API**: All public classes and methods need dartdoc comments
2. **Examples**: Include code examples in documentation
3. **README**: Keep the rules table updated
4. **CHANGELOG**: Document all changes

### Documentation Style

```dart
/// Brief description of what this does.
///
/// Longer description if needed, explaining when and why
/// to use this functionality.
///
/// Example:
/// ```dart
/// // Example code here
/// ```
///
/// See also:
/// - [RelatedClass] for related functionality
```

## Release Process

### Version Numbering

We use [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.0.1): Bug fixes, backwards compatible

### Release Checklist

1. **Update version** in `pubspec.yaml`
2. **Update CHANGELOG.md** with release notes
3. **Run all checks**:
   ```bash
   dart format --line-length=120 .
   dart analyze
   dart test
   dart pub publish --dry-run
   ```
4. **Create git tag**:
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```
5. **Publish to pub.dev**:
   ```bash
   dart pub publish
   ```

### Post-Release

1. Create GitHub release with changelog
2. Update documentation if needed
3. Announce in relevant channels

## Getting Help

- **Issues**: Use the [issue tracker](https://github.com/itae/clean_architecture_linter/issues)
- **Discussions**: Start a [discussion](https://github.com/itae/clean_architecture_linter/discussions)
- **Email**: contact@example.com (update with actual contact)

## Recognition

Contributors will be recognized in:
- The CHANGELOG.md file
- The project README
- GitHub contributors page

## License

By contributing, you agree that your contributions will be licensed under the project's MIT License.

---

Thank you for contributing to Clean Architecture Linter! Your efforts help make Flutter development more maintainable and scalable for everyone.