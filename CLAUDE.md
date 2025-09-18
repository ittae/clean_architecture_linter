# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart package that provides custom lint rules for enforcing Clean Architecture principles in Flutter projects. It uses the `custom_lint_builder` framework to create static analysis rules that validate proper architectural boundaries and patterns.

## Common Commands

### Development
```bash
# Install dependencies
dart pub get

# Run tests
dart pub test

# Run the linter on example project
cd example && dart pub custom_lint

# Check linting on the package itself
dart pub custom_lint

# Analyze the package
dart analyze

# Format code
dart format .
```

### Publishing
```bash
# Check package health before publishing
dart pub publish --dry-run

# Publish package (when ready)
dart pub publish
```

## Architecture

The package is structured around the `custom_lint_builder` framework:

### Core Architecture
- **Entry Point**: `lib/clean_architecture_linter.dart` - Defines the plugin and registers all lint rules
- **Base Configuration**: `lib/src/clean_architecture_linter_base.dart` - Shared utilities and configuration options
- **Rule Categories**: Rules are organized by Clean Architecture layers:
  - `lib/src/rules/domain_rules/` - 7 rules for domain layer validation
  - `lib/src/rules/data_rules/` - 3 rules for data layer validation
  - `lib/src/rules/presentation_rules/` - 3 rules for presentation layer validation

### Rule Implementation Pattern
Each lint rule extends `DartLintRule` and follows this pattern:
1. Define a `LintCode` with name, problem message, and correction message
2. Implement the `run()` method to analyze AST nodes
3. Use visitors to traverse and validate specific code patterns
4. Report violations using the `ErrorReporter`

### Key Components
- **Plugin Registration**: `_CleanArchitectureLinterPlugin` class registers all 13 lint rules
- **AST Analysis**: Rules analyze Dart Abstract Syntax Trees to detect architectural violations
- **Error Reporting**: Standardized error messages guide developers toward Clean Architecture compliance

## Development Guidelines

### Adding New Rules
1. Create rule file in appropriate category directory (`domain_rules/`, `data_rules/`, `presentation_rules/`)
2. Extend `DartLintRule` and implement required methods
3. Register the rule in `lib/clean_architecture_linter.dart`
4. Add examples to `example/lib/` directories
5. Write tests in `test/` directory

### Testing Strategy
- Test files go in `test/` directory
- Examples for testing rules are in `example/lib/` with `good_examples/` and `bad_examples/` subdirectories
- Use `dart pub test` to run tests
- Use `dart pub custom_lint` in example directory to test rules manually

### Configuration
- Rules are configured in `analysis_options.yaml` under `custom_lint.rules`
- Each rule can be individually enabled/disabled
- The package uses standard Dart linting with `package:lints/recommended.yaml`

## File Organization

```
lib/
├── clean_architecture_linter.dart          # Main plugin entry point
├── src/
│   ├── clean_architecture_linter_base.dart # Shared configuration
│   └── rules/
│       ├── domain_rules/                   # Domain layer rules (7 rules)
│       ├── data_rules/                     # Data layer rules (3 rules)
│       └── presentation_rules/             # Presentation layer rules (3 rules)
example/
├── lib/
│   ├── good_examples/                      # Valid Clean Architecture examples
│   └── bad_examples/                       # Invalid examples that trigger rules
test/                                       # Test files
```

## Dependencies

- `analyzer: ^6.8.0` - Dart static analysis
- `custom_lint_builder: ^0.6.7` - Framework for creating custom lint rules
- `custom_lint: ^0.6.7` - Runtime for custom lint rules (dev dependency)