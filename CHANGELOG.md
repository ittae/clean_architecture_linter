# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2025-10-28

### 🔧 Changed

- **Upgraded custom_lint_builder** from `0.7.6` to `0.8.0`
  - Ensures compatibility with riverpod_generator 3.0.0
  - Upgraded custom_lint dev dependency to `0.8.0`
  - All 527 tests pass successfully
  - No breaking API changes required
  - Maintains backward compatibility

### 📦 Dependencies

- `custom_lint_builder`: ^0.7.6 → ^0.8.0
- `custom_lint`: ^0.7.6 → ^0.8.0 (dev dependency)

## [Unreleased]

### ✨ Added (2 new rules)

- **riverpod_ref_usage rule** - Enforce proper ref.watch() vs ref.read() usage in Riverpod providers
  - Validates State providers in build(): use `ref.watch()` for reactive dependencies
  - Validates UseCase providers in build(): use `ref.read()` for one-time calls
  - Validates all providers in methods: use `ref.read()` for one-time reads
  - Smart UseCase provider detection by naming convention and immediate function calls
  - Allows `.notifier` access with `ref.read()`
  - Comprehensive error messages explaining State vs UseCase provider distinction
  - 34 unit tests with 100% pass rate
  - Severity: WARNING

- **riverpod_provider_naming rule** - Enforce provider function naming conventions for code generation
  - Repository return type → function name must end with "repository"
  - UseCase return type → function name must end with "usecase"
  - DataSource return type → function name must end with "datasource"
  - Ensures clear provider name generation (e.g., `getEventsUsecaseProvider` vs `getEventsProvider`)
  - Enables automatic UseCase provider detection in ref usage rules
  - Auto-suggests corrected function names
  - 24 unit tests with 100% pass rate
  - Severity: WARNING

### 🔄 Changed

- **Total rules: 33** (was 31 in v1.0.4)
  - Added: 2 new Riverpod validation rules
  - Presentation layer rules: 11 (was 9)

### 📝 Documentation

- **README.md**
  - Added Riverpod dependency note at the top
  - Updated requirements section to mention Riverpod
  - Updated rule count from 29 to 33
  - Added descriptions for new Riverpod rules

- **CLAUDE.md**
  - Added "Incorrect ref.watch() / ref.read() Usage" violation section
  - Added "Provider Function Missing Type Suffix" violation section
  - Comprehensive examples for both good and bad patterns
  - Explained UseCase vs State provider distinction
  - Provider naming conventions and code generation impact
  - UseCase provider identification patterns

- **pubspec.yaml**
  - Updated description to mention Riverpod state management
  - Added "riverpod" and "flutter" to topics

### 🧪 Testing

- Added 58 new unit tests (34 + 24) for Riverpod rules
- All tests passing with comprehensive coverage
- Test files:
  - `test/src/rules/presentation_rules/riverpod_ref_usage_rule_test.dart`
  - `test/src/rules/presentation_rules/riverpod_provider_naming_rule_test.dart`

## [1.0.4] - 2025-10-22

### ✨ Added (2 new rules)

- **widget_no_usecase_call rule** - Enforce proper Riverpod architecture: Widget → Provider → UseCase
  - Prevents widgets from directly importing or calling UseCases
  - Enforces proper separation: Widgets should only interact with Providers
  - Detects UseCase imports in widget/page files
  - Detects direct UseCase provider calls via `ref.read()` or `ref.watch()`
  - Provides comprehensive correction messages with proper Riverpod patterns
  - Severity: WARNING

- **widget_ref_read_then_when rule** - Prevent anti-pattern of using `.when()` after `ref.read()`
  - Detects `ref.read()` followed by `.when()` in the same function
  - Enforces proper patterns: `ref.watch()` + `.when()` for UI, `ref.listen()` for side effects
  - Prevents misuse of AsyncValue state management
  - Explains why this pattern is incorrect (state is already settled after operation)
  - Provides three correct alternatives based on use case
  - Severity: WARNING

### 🔄 Changed

- **presentation_no_throw rule** - Enhanced detection capabilities
  - Now checks `/providers/` directory in addition to `/states/` and `/state/`
  - Improved State/Notifier class detection with three methods:
    1. Detects `@riverpod` annotation (Riverpod Generator pattern)
    2. Detects `extends AsyncNotifier/Notifier/StateNotifier/ChangeNotifier`
    3. Detects generated classes with `_$` prefix
  - More robust validation of Riverpod-based state management classes
  - Better coverage of modern Riverpod code generation patterns

- **Total rules: 31** (was 29 in v1.0.3)
  - Added: 2 new presentation layer rules
  - Modified: 1 rule (presentation_no_throw)

### 📝 Documentation

- Enhanced CLAUDE.md with comprehensive Riverpod state management patterns
  - Added 3-tier provider architecture documentation
  - Documented Entity Providers (AsyncNotifier), UI State Providers (Notifier), and Computed Logic Providers
  - Added detailed examples of AsyncValue.when() pattern usage
  - Included common violations and their solutions
  - Comprehensive Widget usage examples with proper error handling

### 📊 Statistics

- **Files changed**: 5 files
  - 2 new rule implementations
  - 1 rule enhancement
  - 1 test file
  - 1 main registration file
- **Lines added**: ~600+ lines
  - widget_no_usecase_call_rule.dart: 265 lines
  - widget_ref_read_then_when_rule.dart: 301 lines
  - Enhanced presentation_no_throw_rule.dart
- **Test coverage**: Comprehensive unit tests for widget_no_usecase_call rule

## [1.0.3] - 2025-10-17

### ✨ Added (3 new rules)

- **model_entity_direct_access rule** - Enforce `.toEntity()` method usage instead of direct `.entity` property access in Data layer
  - Prevents direct `.entity` access in Repository and DataSource implementations
  - Allows direct access inside extension methods (where conversion logic is implemented)
  - Allows direct access in test files
  - Provides clear architectural boundaries for Model → Entity conversion

- **model_naming_convention rule** - Enforce naming conventions for Models in Data layer
  - Models must end with `Model` suffix
  - Validates proper naming in `data/models/` directories
  - Helps maintain consistent codebase structure

- **presentation_no_throw rule** - Enforce no exception throwing in Presentation layer
  - Presentation layer should use AsyncValue for error handling
  - No direct exception throws in widgets, states, or notifiers
  - Aligns with Riverpod best practices

### 🔄 Changed

- **model_conversion_methods rule** - Updated to align with Dart/Freezed best practices
  - Now only requires `toEntity()` method in extensions (mandatory)
  - `fromEntity()` implementation is optional and should use factory constructors in the Model class
  - Removed extension static method pattern (not idiomatic in Dart)
  - Updated error messages to guide users toward factory constructor pattern

- **Total rules: 29** (was 26 in v1.0.2)
  - Added: 3 new rules
  - Modified: 1 rule (model_conversion_methods)

### 🐛 Bug Fixes

- Fixed `exception_naming_convention` rule to skip `core/` directory (framework-level exceptions)
- Fixed `failure_naming_convention` rule to skip `core/` directory
- Fixed data file detection to correctly exclude `domain/repositories/` from data layer
- Fixed `model_conversion_methods` rule incorrectly requiring extension static methods
- Improved error severity levels across multiple rules

### 📝 Documentation

- Updated CLAUDE.md with comprehensive `.entity` access control guidelines
- Updated Data Layer rules README with all 3 new rules documentation
- Enhanced Model conversion pattern examples with factory constructor approach
- Added 48 new lines of documentation in CLAUDE.md
- Added 55 new lines in Data Layer README
- Updated README.md with accurate rule count

### 📊 Statistics

- **Files changed**: 23 files
- **Lines added**: ~1,237 lines
- **New test coverage**: 398+ lines of new tests for new rules
- **Documentation improvements**: 100+ lines across multiple files

## [1.0.2] - 2025-10-09

### 🗑️ Removed

- **entity_business_logic rule** - Removed overly strict rule requiring all entities to have business logic methods
  - Not all entities need business logic (e.g., events, DTOs, value objects)
  - Users reported this as too restrictive for practical use cases
  - Total rules: 27 → 26

### 📝 Documentation

- Fixed incomplete code snippet in README.md examples section
- Synchronized README_KO.md structure with README.md (removed inconsistent sections)
- Updated rule count from 27 to 26 in both English and Korean READMEs

## [1.0.1] - 2025-10-09

### 📝 Documentation

- Updated README.md with accurate rule count (27 rules instead of 16+)
- Updated README_KO.md with accurate rule count and simplified structure
- Simplified configuration section, removed non-existent Core/Strict modes
- Reorganized rules documentation with clear categorization
- Removed unnecessary documentation files (VALIDATION_REPORT.md, ERROR_HANDLING_RULES_TODO.md)

### 🔧 CI/CD

- Improved publish workflow to use official OIDC-based authentication
- Added quality checks (tests, analyzer, format) before publishing
- Aligned publish workflow with CI workflow for consistency

## [1.0.0] - 2025-10-09

### 🎉 Initial Release

A comprehensive custom lint package that automatically enforces Clean Architecture principles in Flutter/Dart projects.

### ✨ Added

#### New Utility Infrastructure
- **CleanArchitectureUtils** - Centralized utility class for common Clean Architecture validations
  - File path detection (isDomainFile, isDataFile, isPresentationFile)
  - Component detection (isUseCaseFile, isDataSourceFile, isRepositoryFile)
  - Class name validation (isUseCaseClass, isDataSourceClass, isRepositoryClass)
  - Type checking (isVoidType, isResultType)
  - Exception pattern recognition (isDataException, isDomainException)
  - AST utilities (findParentClass, isPrivateMethod, isRethrow)
  - Feature extraction (extractFeatureName)

#### New Mixin System
- **ExceptionValidationMixin** - Exception naming and validation logic
- **ReturnTypeValidationMixin** - Return type validation for methods
- **RepositoryRuleVisitor** - Repository-specific validation

### 🔄 Changed

#### Code Organization
- **170 lines removed** (13.6% code reduction) through deduplication
- Consolidated 13 rules to use shared mixins and utilities
- Improved consistency across all validation logic
- Enhanced test coverage with **76 comprehensive tests**

#### Refactored All 24 Rules
All lint rules were refactored to leverage the new utility and mixin infrastructure:

**Cross-Layer Rules (4)**
- LayerDependencyRule
- CircularDependencyRule
- BoundaryCrossingRule
- TestCoverageRule

**Domain Layer Rules (4)**
- DomainPurityRule
- DependencyInversionRule
- RepositoryInterfaceRule
- UseCaseNoResultReturnRule
- UseCaseMustConvertFailureRule
- ExceptionNamingConventionRule
- ExceptionMessageLocalizationRule

**Data Layer Rules (7)**
- ModelStructureRule
- DataSourceAbstractionRule
- DataSourceNoResultReturnRule
- RepositoryMustReturnResultRule
- RepositoryNoThrowRule
- DataSourceExceptionTypesRule
- FailureNamingConventionRule

**Presentation Layer Rules (6)**
- NoPresentationModelsRule
- ExtensionLocationRule
- FreezedUsageRule
- RiverpodGeneratorRule
- PresentationNoDataExceptionsRule
- PresentationUseAsyncValueRule

### 📈 Improved

#### Documentation
- Added comprehensive ARCHITECTURE.md with system overview
- Created CONTRIBUTING.md with development guidelines
- Added RULE_DEVELOPMENT_GUIDE.md for contributors
- Enhanced inline documentation across all files

#### Testing
- **76 comprehensive tests** covering all utilities and mixins
- 100% coverage of utility methods
- Extensive mixin behavior validation

#### Code Quality
- Eliminated 170 lines of duplicate code
- Consistent validation patterns across all rules
- Improved error messages with better context
- Enhanced maintainability through shared components

### 🔧 Technical Details

#### Dependencies
- Dart SDK: ^3.6.0
- analyzer: ^7.6.0
- custom_lint_builder: ^0.7.6
- path: ^1.9.1


