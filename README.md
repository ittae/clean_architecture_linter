# Clean Architecture Linter

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 🇰🇷 [한국어 README](README_KO.md) | 🇺🇸 English README

A comprehensive custom lint package that enforces Clean Architecture principles in Flutter projects. This is the **first** and **only** lint tool specifically designed to maintain proper architectural boundaries and patterns in Flutter applications following Uncle Bob's Clean Architecture.

## 🚀 Features

- **39 Comprehensive Lint Rules** covering all aspects of Clean Architecture
- **Domain Layer Rules** (11 rules): Ensures business logic purity and proper abstractions
- **Data Layer Rules** (7 rules): Validates repository implementations and data models
- **Presentation Layer Rules** (3 rules): Enforces UI/business logic separation
- **Interface Adapter Rules** (3 rules): Validates proper data conversion patterns
- **Framework Rules** (4 rules): Ensures framework details stay in outer layer
- **Boundary Rules** (11 rules): Enforces proper boundary crossing patterns
- **Real-time feedback** in your IDE (VS Code, IntelliJ IDEA, Android Studio)
- **Configurable rules** - enable/disable specific rules as needed
- **Zero dependencies** on your app - works as a dev dependency

## 📋 Rules by Clean Architecture Layer

### 🎯 Domain Layer (Core Business Rules)
*The innermost layer containing business logic and rules*

**Entity & Business Rules (4 rules):**
- `entity_business_rules` - Ensures entities contain only enterprise business rules
- `entity_stability` - Validates entity stability and immutability
- `entity_immutability` - Enforces immutable domain entities
- `business_logic_isolation` - Prevents business logic leakage to outer layers

**Use Cases & Application Rules (4 rules):**
- `usecase_orchestration` - Validates use case orchestration patterns
- `usecase_application_rules` - Ensures use cases contain application-specific rules
- `usecase_independence` - Enforces use case independence
- `usecase_single_responsibility` - Validates single responsibility principle

**Domain Interfaces & Validation (3 rules):**
- `repository_interface` - Validates proper repository abstractions
- `domain_model_validation` - Ensures proper domain validation
- `domain_purity` - Prevents external framework dependencies
- `dependency_inversion` - Validates dependency direction

### 💾 Data Layer (Data Access & External Interfaces)
*Repository implementations and data source management*

**Repository & Data Source Rules (3 rules):**
- `repository_implementation` - Validates repository implementation patterns
- `datasource_naming` - Enforces proper naming conventions
- `model_structure` - Ensures data models have proper structure

**Boundary Data Rules (4 rules):**
- `data_boundary_crossing` - Validates proper data crossing boundaries
- `database_row_boundary` - Prevents database row structures crossing inward
- `dto_boundary_pattern` - Enforces DTO patterns for boundary crossing
- `entity_boundary_isolation` - Isolates entities from outer layers

### 🎨 Presentation Layer (UI & Delivery Mechanism)
*User interface and delivery mechanisms*

**UI & State Management (3 rules):**
- `ui_dependency_injection` - Prevents direct business logic instantiation
- `state_management` - Validates proper state management patterns
- `presentation_logic_separation` - Enforces UI/business logic separation

### 🔗 Interface Adapters (Data Format Conversion)
*Controllers, Presenters, and Gateways*

**Data Conversion & MVC (3 rules):**
- `data_conversion_adapter` - Validates data format conversions
- `mvc_architecture` - Enforces MVC patterns in adapters
- `external_service_adapter` - Validates external service adapter patterns

### ⚙️ Framework & Drivers (External Details)
*Web frameworks, databases, and external agencies*

**Framework Isolation (4 rules):**
- `framework_isolation` - Isolates framework details in outermost layer
- `database_detail` - Keeps database details in framework layer
- `web_framework_detail` - Isolates web framework specifics
- `glue_code` - Validates glue code patterns

### 🌐 Architectural Boundaries (Cross-Cutting Concerns)
*Rules that span multiple layers and enforce Uncle Bob's principles*

**Dependency & Layer Rules (5 rules):**
- `layer_dependency` - Enforces The Dependency Rule (inward only)
- `circular_dependency` - Prevents circular dependencies
- `core_dependency` - Validates core dependency patterns
- `abstraction_level` - Ensures proper abstraction levels
- `flexible_layer_detection` - Supports flexible layer architectures

**Boundary Crossing Patterns (6 rules):**
- `boundary_crossing` - Validates proper boundary crossing
- `dependency_inversion_boundary` - Enforces dependency inversion at boundaries
- `interface_boundary` - Validates interface boundary patterns
- `polymorphic_flow_control` - Ensures polymorphic flow control inversion
- `abstraction_progression` - Validates abstraction progression across layers
- `clean_architecture_benefits` - Ensures architecture provides expected benefits

> 📖 **Detailed Rules Guide**: See [RULES.md](RULES.md) for comprehensive documentation of all 39 rules, including examples, Uncle Bob quotes, and implementation guidance.
>
> 🇰🇷 **한글 가이드**: [RULES_KO.md](RULES_KO.md)에서 39개 규칙에 대한 한국어 설명과 실제 사용 시나리오를 확인하세요.

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
    # Domain Layer Rules (11 rules)
    - entity_business_rules
    - entity_stability
    - entity_immutability
    - business_logic_isolation
    - usecase_orchestration
    - usecase_application_rules
    - usecase_independence
    - usecase_single_responsibility
    - repository_interface
    - domain_model_validation
    - domain_purity
    - dependency_inversion

    # Data Layer Rules (7 rules)
    - repository_implementation
    - datasource_naming
    - model_structure
    - data_boundary_crossing
    - database_row_boundary
    - dto_boundary_pattern
    - entity_boundary_isolation

    # Presentation Layer Rules (3 rules)
    - ui_dependency_injection
    - state_management
    - presentation_logic_separation

    # Interface Adapter Rules (3 rules)
    - data_conversion_adapter
    - mvc_architecture
    - external_service_adapter

    # Framework Rules (4 rules)
    - framework_isolation
    - database_detail
    - web_framework_detail
    - glue_code

    # Boundary Rules (11 rules)
    - layer_dependency
    - circular_dependency
    - core_dependency
    - abstraction_level
    - flexible_layer_detection
    - boundary_crossing
    - dependency_inversion_boundary
    - interface_boundary
    - polymorphic_flow_control
    - abstraction_progression
    - clean_architecture_benefits
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
