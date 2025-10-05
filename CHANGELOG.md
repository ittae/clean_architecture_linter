# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-10-05

### 🎯 Major Refactoring - Mixin-Based Architecture

This release represents a comprehensive refactoring of the entire codebase to improve maintainability, reduce code duplication, and enhance consistency across all lint rules.

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

#### Dependency Updates
- analyzer: ^7.4.5
- custom_lint_builder: ^0.7.6
- All dev dependencies updated to latest versions

#### Breaking Changes
None - Full backward compatibility with v1.x maintained.

### 📦 Migration Guide

No migration needed. All existing configurations and rule behaviors remain unchanged. The refactoring is entirely internal and transparent to users.

---

## [1.0.0] - 2024-01-20

### 🎉 Initial Stable Release

The first stable release of Clean Architecture Linter - a comprehensive custom lint package that automatically enforces Clean Architecture principles in Flutter/Dart projects.

### ✨ Features Added

#### 🎯 Domain Layer Rules (5 rules)
- **`domain_purity`** - Ensures domain layer independence from external frameworks
- **`consolidated_entity_rule`** - Validates entity immutability, business rules, and stability
- **`consolidated_usecase_rule`** - Enforces UseCase patterns, single responsibility, and independence
- **`repository_interface_rule`** - Validates proper repository abstractions
- **`dependency_inversion_rule`** - Ensures dependency direction follows Clean Architecture

#### 📊 Data Layer Rules (3 rules)
- **`datasource_naming_rule`** - Enforces proper DataSource patterns and external communication
- **`repository_implementation_rule`** - Validates repository implementations and domain interface compliance
- **`model_structure_rule`** - Ensures data models have proper serialization, domain conversion, and business logic separation

#### 🎨 Presentation Layer Rules (4 rules)
- **`business_logic_isolation_rule`** - Prevents business logic in UI components
- **`state_management_rule`** - Validates proper Flutter state management patterns (Provider, Bloc, Riverpod)
- **`presentation_logic_separation_rule`** - Enforces separation of complex presentation logic
- **`ui_dependency_injection_rule`** - Ensures proper dependency injection patterns in UI

#### 🔧 Framework Layer Rules (4 rules)
- **`glue_code_rule`** - Validates framework layer simplicity and glue code patterns
- **`web_framework_detail_rule`** - Isolates web framework concerns to framework layer
- **`database_detail_rule`** - Isolates database concerns to framework layer
- **`framework_isolation_rule`** - Prevents framework leakage into inner layers

### 🎛️ Configuration System
- **Core Mode** - Essential rules only (5 rules)
- **Standard Mode** - Recommended rules (16 rules)
- **Strict Mode** - Maximum enforcement (16 rules as errors)

### 🚀 Framework Support
- **UI**: Flutter, Angular Dart
- **Web**: Shelf, Dart Frog, Conduit, Angel3
- **Database**: Sqflite, Drift, Floor, Hive, Isar, Realm, ObjectBox
- **HTTP**: Dio, Http, Retrofit
- **State Management**: Provider, Riverpod, Bloc, GetX

### 🧪 Test-Aware Features
- **Test File Exceptions** - Relaxed rules for test files
- **Integration Test Support** - Special handling for `integration_test/`
- **Migration Files** - Database rules relaxed for migration files
- **Flutter Test** - Allows `flutter_test` package usage

### 📚 Educational Features
- **Specific Error Messages** - Clear violation descriptions
- **Actionable Corrections** - Step-by-step fix guidance
- **Layer Guidance** - Explains which layer code belongs in
- **Pattern Suggestions** - Recommends Clean Architecture patterns

### 🛠️ Platform Support
- **Dart SDK**: Compatible with Dart 3.0.0+
- **Platforms**: Linux, macOS, Windows
- **IDE Integration**: VS Code, IntelliJ IDEA, Android Studio

### 📖 Documentation
- Comprehensive README with quick start guide
- Complete rule reference documentation
- Configuration options for different team needs
- Real-world examples and best practices
