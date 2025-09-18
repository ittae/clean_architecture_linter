# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-18

### Added

#### Domain Layer Rules (7 rules)
- **Domain Purity Rule**: Prevents domain layer from depending on external frameworks (Flutter, HTTP clients, etc.)
- **Entity Immutability Rule**: Enforces immutable entities with final fields and no setters
- **Repository Interface Rule**: Validates that domain layer only depends on repository interfaces, not implementations
- **UseCase Single Responsibility Rule**: Ensures UseCase classes have only one call() or execute() method
- **Business Logic Isolation Rule**: Prevents business logic from leaking into UI components
- **Domain Model Validation Rule**: Encourages proper validation and business rules in domain entities
- **Dependency Inversion Rule**: Validates that domain layer depends on abstractions, not concretions

#### Data Layer Rules (3 rules)
- **DataSource Naming Rule**: Enforces proper naming conventions for data sources (DataSource, RemoteDataSource, LocalDataSource suffixes)
- **Repository Implementation Rule**: Validates that repository implementations properly implement domain interfaces and use data sources
- **Model Structure Rule**: Ensures data models have proper serialization methods (fromJson constructor and toJson method)

#### Presentation Layer Rules (3 rules)
- **UI Dependency Injection Rule**: Prevents direct instantiation of business logic classes in UI components
- **State Management Rule**: Validates proper state management patterns and prevents business logic in build methods
- **Presentation Logic Separation Rule**: Enforces separation of presentation logic from UI components

#### Package Features
- Custom lint integration with `custom_lint_builder`
- Real-time IDE feedback (VS Code, IntelliJ IDEA, Android Studio)
- Comprehensive documentation and examples
- MIT License for open source usage
- Example files demonstrating good and bad patterns

### Infrastructure
- Initial package structure with organized rule categories
- Comprehensive README with installation and usage instructions
- MIT License
- Example project with good and bad code patterns
- Unit test structure prepared

### Documentation
- Detailed README with feature overview
- Installation and configuration instructions
- Code examples for each rule
- Project structure guidelines
- Contributing guidelines
