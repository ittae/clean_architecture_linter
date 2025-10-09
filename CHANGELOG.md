# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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


