# Clean Architecture Linter

[![pub package](https://img.shields.io/pub/v/clean_architecture_linter.svg)](https://pub.dev/packages/clean_architecture_linter)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> 🇰🇷 [한국어 README](README_KO.md) | 🇺🇸 English README

A comprehensive custom lint package that **automatically enforces Clean Architecture principles** in Flutter/Dart projects with **Riverpod state management**. Write code naturally while the linter guides you toward perfect Clean Architecture compliance with real-time feedback and actionable corrections.

> ⚠️ **Note**: This package is designed for projects using [Riverpod](https://pub.dev/packages/riverpod) for state management. Some presentation layer rules specifically validate Riverpod patterns.

## ✨ Key Features

- 🛡️ **Automatic Clean Architecture Protection** - Write code freely, linter catches violations
- 🎯 **33 Specialized Rules** - Comprehensive coverage of all Clean Architecture layers
- 🚀 **Flutter-Optimized** - Built specifically for Flutter development patterns
- 🎨 **Riverpod State Management** - Enforces 3-tier provider architecture (Entity → UI → Computed)
- 📚 **Educational** - Learn Clean Architecture through guided corrections
- ⚡ **Real-time Feedback** - Immediate warnings with actionable solutions
- 🔧 **Zero Configuration** - Works out of the box with sensible defaults
- 🧪 **Test-Aware** - Smart exceptions for test files and development contexts

## 📋 Rules Overview (33 Rules)

### 🌐 Core Clean Architecture Principles (6 rules)
1. **Layer Dependency** - Enforces dependency direction (inward only)
2. **Domain Purity** - Prevents external framework dependencies in domain layer
3. **Dependency Inversion** - Validates abstraction-based dependencies
4. **Repository Interface** - Ensures proper repository abstractions
5. **Circular Dependency** - Prevents circular dependencies between layers
6. **Boundary Crossing** - Validates proper layer boundary crossing

### 🎯 Domain Layer Rules (2 rules)
7. **UseCase No Result Return** - UseCases should return entities directly (pass-through pattern)
8. **Exception Naming Convention** - Feature prefix for domain exceptions

### 💾 Data Layer Rules (10 rules)
9. **Model Structure** - Freezed models with entity composition
10. **Model Field Duplication** - No duplicate entity fields in models
11. **Model Conversion Methods** - Required `toEntity()` method in extensions
12. **Model Naming Convention** - Models must end with `Model` suffix
13. **DataSource Abstraction** - Abstract interfaces for data sources
14. **DataSource No Result Return** - DataSources throw exceptions
15. **Repository Implementation** - RepositoryImpl must implement domain interface
16. **Repository Pass Through** - Repositories return `Future<Entity>` (warns on Result pattern)
17. **Repository No Throw** - Repositories use pass-through pattern (AppException types allowed)
18. **DataSource Exception Types** - Use defined data layer exceptions only
19. **Model Entity Direct Access** - Use `.toEntity()` instead of direct `.entity` access

### 🎨 Presentation Layer Rules (13 rules)
20. **No Presentation Models** - Use Freezed State instead of ViewModels
21. **Extension Location** - Extensions in same file as the class
22. **Freezed Usage** - Use Freezed instead of Equatable
23. **Riverpod Generator** - Use `@riverpod` annotation
24. **Presentation No Data Exceptions** - Use domain exceptions only
25. **Presentation Use AsyncValue** - Use AsyncValue for error handling (3-tier architecture)
26. **Presentation No Throw** - No exception throwing in Presentation layer
27. **Widget No UseCase Call** - Widgets should not call UseCases directly (use Providers)
28. **Widget Ref Read Then When** - Avoid using .when() after ref.read() (anti-pattern)
29. **Riverpod Ref Usage** - Use ref.watch() in build(), ref.read() in methods (with UseCase detection)
30. **Riverpod Provider Naming** - Provider functions must include type suffix (repository/usecase/datasource)
31. **Ref Mounted Usage** - Avoid `ref.mounted` (use AsyncValue or complete async before navigation)
32. **Riverpod Keep Alive** - Only use `keepAlive: true` for global state (auth, settings, cache)

### 🔧 Cross-Layer Rules (1 rule)
33. **Allowed Instance Variables** - Enforces stateless architecture (UseCase/Repository/DataSource)

### 🧪 Optional: Test Coverage Rule
**Test Coverage** - Enforces test files for UseCases, Repositories, DataSources, and Notifiers (disabled by default)

> 📖 **Implementation Guide**: See [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md) for detailed patterns and examples.
>
> 🎨 **Riverpod State Management**: See [CLAUDE.md § Riverpod State Management Patterns](CLAUDE.md#riverpod-state-management-patterns) for 3-tier provider architecture guide.

## 🚀 Quick Start

> 🚀 **v2.0**: Starting with `2.0.0-dev.1`, this package runs on the official [`analysis_server_plugin`](https://pub.dev/packages/analysis_server_plugin) — no `custom_lint` dependency, no `pubspec_overrides.yaml` workaround. Lint runs directly via `dart analyze` / `flutter analyze`. Upgrading from a v1 (`custom_lint`) setup? Follow [MIGRATION.md](MIGRATION.md).

### 📋 Requirements

- **Dart SDK**: 3.10.0+
- **Flutter**: 3.0+ (optional, for Flutter projects)
- **Riverpod**: Required for presentation layer rules (riverpod_generator recommended)

### 1. Add to your project

```yaml
# pubspec.yaml
dev_dependencies:
  clean_architecture_linter: ^2.0.0-dev.1
```

### 2. Enable the plugin

```yaml
# analysis_options.yaml
plugins:
  clean_architecture_linter: ^2.0.0-dev.1

analyzer:
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
dart analyze        # Flutter projects: flutter analyze
```

That's it! The 33 rules are reported directly in your `dart analyze` / `flutter analyze` output.

### Recommended team profile
- Local: `docs/config/lint_profile_balanced.yaml`
- CI: `docs/config/lint_profile_strict.yaml`

See `docs/config/RECOMMENDED_SETUP.md` for details.

## 🧩 Compatibility — analyzer 13 / Riverpod 3+

v2.0 runs on the official `analysis_server_plugin` (`^0.3.15`), which pins `analyzer ^13.0.0`. This matches the analyzer bundled with **Dart 3.10+**, so the plugin loads inside your project's analysis server with no `pubspec_overrides.yaml` workaround. It resolves cleanly alongside the latest `riverpod_generator 4.x`, `riverpod_lint 3.1.x`, `freezed 3.x`, and `json_serializable 6.13+`.

> The v1 `custom_lint` upstream ([invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint)) was archived in May 2026. v2.0 moves fully to the official plugin, so the old `pubspec_overrides.yaml` bridge is no longer needed — delete it when upgrading.

## 🎛️ Configuration

### Optional: Test Coverage

In v2.0, rule severity is controlled with the standard analyzer `errors:` map, keyed by each rule's diagnostic name. Promote a rule to an error, downgrade it to a hint, or silence it:

```yaml
# analysis_options.yaml
analyzer:
  errors:
    repository_interface: error   # treat as build-breaking
    riverpod_keep_alive: ignore   # silence
```

> The opt-in `clean_architecture_linter_require_test` (test coverage) rule is **not bundled** in `2.0.0-dev.1`. It will be re-introduced in a later v2 pre-release; track the CHANGELOG.

## 🚦 Usage

### Folder Structure

Organize your Flutter project following Clean Architecture:

```
lib/
├── {feature_name}/
│   ├── domain/
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── data/
│   │   ├── datasources/
│   │   ├── models/
│   │   └── repositories/
│   └── presentation/
│       ├── providers/
│       ├── widgets/
│       └── pages/
```

### Running the Linter

```bash
# Run the linter (rules are included in the analyzer output)
dart analyze        # Flutter projects: flutter analyze
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

**Data Model with Database (ObjectBox Example)**
```dart
// lib/data/models/user_model.dart
import 'package:objectbox/objectbox.dart';  // ✅ Allowed

@Entity()  // ✅ Database annotation instead of @freezed
class UserModel {
  @Id()
  int id = 0;

  String name;
  String email;

  UserModel({required this.name, required this.email});

  // ✅ Private database access is allowed
  static Box<UserModel> get _box => objectBoxService.store.box<UserModel>();

  // Conversion method
  UserEntity toEntity() => UserEntity(
    id: id.toString(),
    name: name,
    email: email,
  );
}
```

> **Note**: When using database libraries (ObjectBox, Realm, Isar, Drift), Models are **mutable** and use database-specific annotations instead of `@freezed`. This is an exception to the standard Freezed pattern.

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

**Repository Using Result Pattern**
```dart
// ❌ This will be flagged - use pass-through pattern instead
class UserRepositoryImpl implements UserRepository {
  @override
  Future<Result<UserEntity, Failure>> getUser(String id) async {
    try {
      final model = await dataSource.getUser(id);
      return Success(model.toEntity());
    } catch (e) {
      return Failure(UserFailure.fromException(e));
    }
  }
}

// ✅ Correct: Pass-through pattern
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    final model = await dataSource.getUser(id);  // Errors pass through
    return model.toEntity();
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

**Pass-through Error Handling (Recommended)**
```dart
// ✅ Good: Pass-through pattern
// DataSource throws AppException
class UserRemoteDataSource {
  Future<UserModel> getUser(String id) async {
    try {
      final response = await client.get('/users/$id');
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw e.toAppException();  // Convert to AppException
    }
  }
}

// Repository passes through (no try-catch)
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    final model = await dataSource.getUser(id);  // Errors pass through
    return model.toEntity();
  }
}

// UseCase adds business validation
class GetUserUseCase {
  Future<UserEntity> call(String id) {
    if (id.isEmpty) {
      throw const InvalidInputException.withCode('errorValidationIdRequired');
    }
    return repository.getUser(id);  // Pass-through
  }
}

// Presentation uses AsyncValue.guard()
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  Future<User> build(String id) => ref.read(getUserUseCaseProvider)(id);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(getUserUseCaseProvider)(id));
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
