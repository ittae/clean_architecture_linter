# Clean Architecture Linter

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive custom lint package that enforces Clean Architecture principles in Flutter projects. This is the **first** and **only** lint tool specifically designed to maintain proper architectural boundaries and patterns in Flutter applications following Clean Architecture.

## 🚀 Features

- **13 Specialized Lint Rules** across all layers of Clean Architecture
- **Domain Layer Rules** (7 rules): Ensures business logic purity and proper abstractions
- **Data Layer Rules** (3 rules): Validates repository implementations and data models
- **Presentation Layer Rules** (3 rules): Enforces UI/business logic separation
- **Real-time feedback** in your IDE (VS Code, IntelliJ IDEA, Android Studio)
- **Configurable rules** - enable/disable specific rules as needed
- **Zero dependencies** on your app - works as a dev dependency

### Domain Layer Rules

- **Domain Purity**: Prevents domain layer from depending on external frameworks
- **Entity Immutability**: Ensures domain entities are immutable
- **Repository Interface**: Validates proper repository abstraction usage
- **UseCase Single Responsibility**: Enforces single responsibility in use cases
- **Business Logic Isolation**: Prevents business logic leakage to UI layer
- **Domain Model Validation**: Ensures proper validation in domain entities
- **Dependency Inversion**: Validates dependency direction in domain layer

### Data Layer Rules

- **DataSource Naming**: Enforces proper naming conventions for data sources
- **Repository Implementation**: Validates repository implementation patterns
- **Model Structure**: Ensures data models have proper serialization methods

### Presentation Layer Rules

- **UI Dependency Injection**: Prevents direct instantiation of business logic in UI
- **State Management Pattern**: Validates proper state management usage
- **Presentation Logic Separation**: Enforces separation of presentation logic from UI

## 📦 Installation

Add `clean_architecture_linter` as a dev dependency in your `pubspec.yaml`:

```yaml
dev_dependencies:
  clean_architecture_linter: ^0.1.0
  custom_lint: ^0.6.7
```

## ⚙️ Configuration

Create or update your `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    # Enable all Clean Architecture rules
    - domain_purity
    - entity_immutability
    - repository_interface
    - usecase_single_responsibility
    - business_logic_isolation
    - domain_model_validation
    - dependency_inversion
    - datasource_naming
    - repository_implementation
    - model_structure
    - ui_dependency_injection
    - state_management_pattern
    - presentation_logic_separation
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
    // Business logic in UI layer
    final user = UserRepository().getUser('123');
    return Text(user.name);
  }
}
```

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
4. Ensure all tests pass
5. Submit a pull request

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

**Made with ❤️ for the Flutter Clean Architecture community**
