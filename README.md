# Clean Architecture Linter

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 🇰🇷 [한국어 README](README_KO.md) | 🇺🇸 English README

A comprehensive custom lint package that **automatically enforces Clean Architecture principles** in Flutter/Dart projects. Write code naturally while the linter guides you toward perfect Clean Architecture compliance with real-time feedback and actionable corrections.

## ✨ Key Features

- 🛡️ **Automatic Clean Architecture Protection** - Write code freely, linter catches violations
- 🎯 **29 Specialized Rules** - Comprehensive coverage of all Clean Architecture layers
- 🚀 **Flutter-Optimized** - Built specifically for Flutter development patterns
- 🎨 **Riverpod State Management** - Enforces 3-tier provider architecture (Entity → UI → Computed)
- 📚 **Educational** - Learn Clean Architecture through guided corrections
- ⚡ **Real-time Feedback** - Immediate warnings with actionable solutions
- 🔧 **Zero Configuration** - Works out of the box with sensible defaults
- 🧪 **Test-Aware** - Smart exceptions for test files and development contexts

## 📋 Rules Overview (29 Rules)

### 🌐 Core Clean Architecture Principles (6 rules)
1. **Layer Dependency** - Enforces dependency direction (inward only)
2. **Domain Purity** - Prevents external framework dependencies in domain layer
3. **Dependency Inversion** - Validates abstraction-based dependencies
4. **Repository Interface** - Ensures proper repository abstractions
5. **Circular Dependency** - Prevents circular dependencies between layers
6. **Boundary Crossing** - Validates proper layer boundary crossing

### 🎯 Domain Layer Rules (4 rules)
7. **UseCase No Result Return** - UseCases should unwrap Result types
8. **UseCase Must Convert Failure** - UseCases convert Failures to Exceptions
9. **Exception Naming Convention** - Feature prefix for domain exceptions
10. **Exception Message Localization** - Consistent exception messages

### 💾 Data Layer Rules (13 rules)
11. **Model Structure** - Freezed models with entity composition
12. **Model Field Duplication** - No duplicate entity fields in models
13. **Model Conversion Methods** - Required `toEntity()` method in extensions
14. **Model Entity Direct Access** - Use `.toEntity()` instead of direct `.entity` access
15. **Model Naming Convention** - Models must end with `Model` suffix
16. **DataSource Abstraction** - Abstract interfaces for data sources
17. **DataSource No Result Return** - DataSources throw exceptions
18. **Repository Implementation** - RepositoryImpl must implement domain interface
19. **Repository Must Return Result** - Repositories wrap results in Result type
20. **Repository No Throw** - Repositories convert exceptions to Result
21. **DataSource Exception Types** - Use defined data layer exceptions only
22. **Failure Naming Convention** - Feature prefix for Failure classes

### 🎨 Presentation Layer Rules (9 rules)
23. **No Presentation Models** - Use Freezed State instead of ViewModels
24. **Extension Location** - Extensions in same file as the class
25. **Freezed Usage** - Use Freezed instead of Equatable
26. **Riverpod Generator** - Use `@riverpod` annotation
27. **Presentation No Data Exceptions** - Use domain exceptions only
28. **Presentation Use AsyncValue** - Use AsyncValue for error handling (3-tier architecture)
29. **Presentation No Throw** - No exception throwing in Presentation layer
30. **Widget No UseCase Call** - Widgets should not call UseCases directly (use Providers)
31. **Widget Ref Read Then When** - Avoid using .when() after ref.read() (anti-pattern)

### 🧪 Optional: Test Coverage Rule
**Test Coverage** - Enforces test files for UseCases, Repositories, DataSources, and Notifiers (disabled by default)

> 📖 **Implementation Guide**: See [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md) for detailed patterns and examples.
>
> 🎨 **Riverpod State Management**: See [CLAUDE.md § Riverpod State Management Patterns](CLAUDE.md#riverpod-state-management-patterns) for 3-tier provider architecture guide.

## 🚀 Quick Start

### 📋 Requirements

- **Dart SDK**: 3.6.0+
- **Flutter**: 3.0+ (optional, for Flutter projects)

### 1. Add to your project

```yaml
# pubspec.yaml
dev_dependencies:
  clean_architecture_linter: ^1.0.4
  custom_lint: ^0.7.6
```

### 2. Enable custom lint

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
  exclude:
    - test/**               
    - "**/*.test.dart"    # Exclude test files
    - "**/*.g.dart"       # Exclude generated files
    - "**/*.freezed.dart" # Exclude Freezed files
    - "**/*.mocks.dart"   # Exclude mock files
```

### 3. Run the linter

```bash
dart pub get
dart run custom_lint
```

That's it! The linter will now automatically enforce Clean Architecture principles in your codebase.

## 🎛️ Configuration

### Optional: Test Coverage

The `clean_architecture_linter_require_test` rule is **disabled by default**.  
Enable it to enforce test files for critical components:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
```

## 🚦 Usage

### Folder Structure

Organize your Flutter project following Clean Architecture:

```
lib/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
└── presentation/
    ├── providers/
    ├── widgets/
    └── pages/
```

### Running the Linter

```bash
# Activate custom_lint if not already done
dart pub global activate custom_lint

# Run the linter
dart pub custom_lint
```

### IDE Integration

The linter works automatically in:
- **VS Code** with the Dart/Flutter extensions
- **IntelliJ IDEA** / **Android Studio** with Flutter plugin

## 📚 Examples

### ✅ Good Examples

**Domain Entity (Immutable)**
```dart
// lib/domain/entities/user_entity.dart
class UserEntity {
  final String id;
  final String name;
  final String email;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
  });

  bool isValidEmail() {
    return email.contains('@');
  }
}
```

**Repository Interface**
```dart
// lib/domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<UserEntity> getUser(String id);
  Future<void> saveUser(UserEntity user);
}
```

**UseCase with Single Responsibility**
```dart
// lib/domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<UserEntity> call(String userId) {
    return repository.getUser(userId);
  }
}
```

### ❌ Bad Examples (Will be flagged)

**Mutable Domain Entity**
```dart
// ❌ This will be flagged by entity_immutability
class UserEntity {
  String name; // Non-final field

  void setName(String newName) { // Setter in entity
    name = newName;
  }
}
```

**Domain Layer with External Dependencies**
```dart
// ❌ This will be flagged by domain_purity
import 'package:http/http.dart'; // External framework import

class UserEntity {
  final String name;
}
```

**UI with Direct Business Logic**
```dart
// ❌ This will be flagged by business_logic_isolation
class UserWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Business logic in UI layer - WRONG!
    final isValid = email.contains('@') && email.length > 5;
    return Text(isValid ? 'Valid' : 'Invalid');
  }
}
```

**Repository Throwing Exceptions**
```dart
// ❌ This will be flagged by avoid_exception_throwing_in_repository
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('ID cannot be empty'); // Should return Result instead
    }
    // ...
  }
}
```

**Layer Dependency Violation**
```dart
// ❌ This will be flagged by avoid_layer_dependency_violation
// In domain layer file:
import 'package:myapp/data/models/user_model.dart'; // Domain importing Data!

class UserEntity extends UserModel { // Wrong dependency direction
  // ...
}
```

**Missing Exception Prefix**
```dart
// ❌ This will be flagged by ensure_exception_prefix
class NetworkException extends Exception { // Should be UserNetworkException
  // ...
}
```

### 🔄 Common Patterns

**Proper Error Handling with Result Type**
```dart
// ✅ Good: Using Result pattern
sealed class Result<T, E> {}
class Success<T, E> extends Result<T, E> {
  final T value;
  Success(this.value);
}
class Failure<T, E> extends Result<T, E> {
  final E error;
  Failure(this.error);
}

// Repository implementation
class UserRepositoryImpl implements UserRepository {
  @override
  Future<Result<UserEntity, UserException>> getUser(String id) async {
    try {
      final userData = await dataSource.getUser(id);
      return Success(userData.toEntity());
    } catch (e) {
      return Failure(UserDataException(e.toString()));
    }
  }
}
```

**Proper Exception Naming**
```dart
// ✅ Good: Proper exception prefixes
class UserNetworkException extends Exception {
  final String message;
  UserNetworkException(this.message);
}

class UserValidationException extends Exception {
  final String field;
  UserValidationException(this.field);
}
```

For more detailed examples and explanations, see our comprehensive [Examples Guide](doc/EXAMPLES.md).

## 🛠️ Development

### Project Structure

```
clean_architecture_linter/
├── lib/
│   ├── src/
│   │   └── rules/
│   │       ├── domain_rules/
│   │       ├── data_rules/
│   │       └── presentation_rules/
│   └── clean_architecture_linter.dart
├── example/
├── test/
└── README.md
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new rules
4. Format your code: `dart format .`
5. Ensure all tests pass
6. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Support

- ⭐ Star this repository if it helped you!
- 🐛 [Report bugs](https://github.com/ittae/clean_architecture_linter/issues)
- 💡 [Request features](https://github.com/ittae/clean_architecture_linter/issues)
- 📖 [Read the documentation](https://github.com/ittae/clean_architecture_linter)

## 🎯 Roadmap

- [ ] Configuration system for custom naming patterns
- [ ] Support for multiple state management solutions
- [ ] Integration with CI/CD workflows
- [ ] Custom rule creation guide
- [ ] Performance optimizations

---

**Made with ❤️ for the Flutter community**
