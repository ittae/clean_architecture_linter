# Clean Architecture Linter Examples

이 문서는 Clean Architecture 원칙을 따르는 좋은 예제와 피해야 할 나쁜 예제들을 보여줍니다.

## 📁 프로젝트 구조

```
lib/
├── {feature_name}/
│   ├── data/           # 데이터 레이어
│   │   ├── datasources/
│   │   ├── models/
│   │   └── repositories/
│   ├── domain/         # 도메인 레이어
│   │   ├── entities/
│   │   ├── repositories/
│   │   └── usecases/
│   ├── presentation/   # 프레젠테이션 레이어
│   │   ├── providers/
│   │   ├── widgets/
│   │   └── pages/
```

## ✅ Good Examples

### 1. Domain Layer - Immutable Entity

```dart
// ✅ lib/domain/entities/user_entity.dart
class UserEntity {
  final String id;
  final String name;
  final String email;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
  });

  // ✅ Business logic in domain
  bool isValidEmail() {
    return email.contains('@') && email.length > 5;
  }

  // ✅ Immutable updates
  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
    );
  }
}
```

### 2. Repository Interface (Domain)

```dart
// ✅ lib/domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<Result<UserEntity, UserException>> getUser(String id);
  Future<Result<void, UserException>> saveUser(UserEntity user);
  Future<Result<List<UserEntity>, UserException>> getAllUsers();
}

// ✅ Result pattern for error handling
sealed class Result<T, E> {}
class Success<T, E> extends Result<T, E> {
  final T value;
  Success(this.value);
}
class Failure<T, E> extends Result<T, E> {
  final E error;
  Failure(this.error);
}
```

### 3. UseCase Implementation

```dart
// ✅ lib/domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository _repository;

  GetUserUseCase(this._repository);

  Future<Result<UserEntity, UserException>> call(String userId) async {
    // ✅ Input validation
    if (userId.isEmpty) {
      return Failure(UserValidationException('User ID cannot be empty'));
    }

    // ✅ Delegate to repository
    return await _repository.getUser(userId);
  }
}
```

### 4. Data Model with Composition

```dart
// ✅ lib/data/models/user_model.dart
import '../../domain/entities/user_entity.dart';

class UserModel {
  final UserEntity entity;
  final String? etag;           // ✅ Data layer metadata
  final DateTime? lastUpdated;  // ✅ Data layer metadata

  const UserModel({
    required this.entity,
    this.etag,
    this.lastUpdated,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      entity: UserEntity(
        id: json['id'],
        name: json['name'],
        email: json['email'],
      ),
      etag: json['etag'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': entity.id,
      'name': entity.name,
      'email': entity.email,
      'etag': etag,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }
}

extension UserModelX on UserModel {
  UserEntity toEntity() => entity;
  
  static UserModel fromEntity(UserEntity entity) {
    return UserModel(
      entity: entity,
      lastUpdated: DateTime.now(),
    );
  }
}
```

### 5. Repository Implementation

```dart
// ✅ lib/data/repositories/user_repository_impl.dart
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource _remoteDataSource;

  UserRepositoryImpl(this._remoteDataSource);

  @override
  Future<Result<UserEntity, UserException>> getUser(String id) async {
    try {
      final userModel = await _remoteDataSource.getUser(id);
      return Success(userModel.toEntity());
    } on NetworkException catch (e) {
      return Failure(UserNetworkException(e.message));
    } on ServerException catch (e) {
      return Failure(UserServerException(e.message));
    } catch (e) {
      return Failure(UserUnknownException(e.toString()));
    }
  }

  @override
  Future<Result<void, UserException>> saveUser(UserEntity user) async {
    try {
      final userModel = UserModel.fromEntity(user);
      await _remoteDataSource.saveUser(userModel);
      return Success(null);
    } catch (e) {
      return Failure(UserDataException(e.toString()));
    }
  }
}
```

### 6. Proper Exception Naming

```dart
// ✅ lib/domain/exceptions/user_exceptions.dart

// ✅ Proper prefix naming
abstract class UserException implements Exception {
  final String message;
  UserException(this.message);
}

class UserNotFoundException extends UserException {
  UserNotFoundException(String message) : super(message);
}

class UserValidationException extends UserException {
  UserValidationException(String message) : super(message);
}

class UserNetworkException extends UserException {
  UserNetworkException(String message) : super(message);
}

class UserServerException extends UserException {
  UserServerException(String message) : super(message);
}

class UserDataException extends UserException {
  UserDataException(String message) : super(message);
}

class UserUnknownException extends UserException {
  UserUnknownException(String message) : super(message);
}
```

### 7. Presentation Layer with Proper State Management

```dart
// ✅ lib/presentation/providers/user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/get_user_usecase.dart';

@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  AsyncValue<UserEntity?> build() {
    return const AsyncValue.data(null);
  }

  Future<void> loadUser(String userId) async {
    state = const AsyncValue.loading();
    
    final getUserUseCase = ref.read(getUserUseCaseProvider);
    final result = await getUserUseCase(userId);
    
    switch (result) {
      case Success(value: final user):
        state = AsyncValue.data(user);
      case Failure(error: final error):
        state = AsyncValue.error(error, StackTrace.current);
    }
  }
}

// ✅ Provider setup
final getUserUseCaseProvider = Provider<GetUserUseCase>((ref) {
  final repository = ref.read(userRepositoryProvider);
  return GetUserUseCase(repository);
});
```

## ❌ Bad Examples

### 1. Layer Dependency Violation
```dart
// ❌ BAD: Domain layer depending on data layer
import 'package:app/data/models/user_model.dart'; // Wrong!

class User extends UserModel { // Domain should not know about data models
  // ...
}
```

### 2. Repository Throwing Exceptions
```dart
// ❌ BAD: Repository throwing exceptions instead of returning Result
class BadUserRepository implements UserRepository {
  @override
  Future<User> getUser(String id) async {
    throw Exception('User not found'); // Wrong! Should return Result
  }
}
```

## ❌ Bad Examples

### 1. Mutable Entity (entity_immutability 위반)

```dart
// ❌ lib/domain/entities/user_entity.dart
class UserEntity {
  String name;  // ❌ Non-final field
  String email; // ❌ Non-final field

  UserEntity(this.name, this.email);

  // ❌ Setter methods in entity
  void setName(String newName) {
    name = newName;
  }

  void setEmail(String newEmail) {
    email = newEmail;
  }
}
```

### 2. Domain with External Dependencies (domain_purity 위반)

```dart
// ❌ lib/domain/entities/user_entity.dart
import 'package:http/http.dart' as http; // ❌ External framework import

class UserEntity {
  final String name;
  final String email;

  UserEntity(this.name, this.email);

  // ❌ HTTP logic in domain entity
  Future<void> saveToServer() async {
    await http.post(Uri.parse('/api/users'), body: {'name': name});
  }
}
```

### 3. Layer Dependency Violation (avoid_layer_dependency_violation 위반)

```dart
// ❌ lib/domain/entities/user_entity.dart
import '../../data/models/user_model.dart'; // ❌ Domain importing Data!

class UserEntity extends UserModel { // ❌ Wrong dependency direction
  UserEntity(String id, String name) : super(id: id, name: name);
}
```

### 4. Repository Throwing Exceptions (avoid_exception_throwing_in_repository 위반)

```dart
// ❌ lib/data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  @override
  Future<UserEntity> getUser(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('ID cannot be empty'); // ❌ Should return Result
    }
    
    try {
      final userData = await dataSource.getUser(id);
      return userData.toEntity();
    } catch (e) {
      throw Exception('Failed to get user'); // ❌ Should return Result
    }
  }
}
```

### 5. Missing Exception Prefix (ensure_exception_prefix 위반)

```dart
// ❌ lib/domain/exceptions/exceptions.dart
class NetworkException extends Exception { // ❌ Should be UserNetworkException
  final String message;
  NetworkException(this.message);
}

class ValidationException extends Exception { // ❌ Should be UserValidationException
  final String message;
  ValidationException(this.message);
}
```

### 6. Business Logic in UI (business_logic_isolation 위반)

```dart
// ❌ lib/presentation/widgets/user_widget.dart
class UserWidget extends StatelessWidget {
  final String email;

  const UserWidget({required this.email});

  @override
  Widget build(BuildContext context) {
    // ❌ Business logic in UI layer
    final isValid = email.contains('@') && 
                   email.split('@')[1].contains('.') &&
                   email.length > 5;
    
    return Text(
      isValid ? 'Valid Email' : 'Invalid Email',
      style: TextStyle(
        color: isValid ? Colors.green : Colors.red,
      ),
    );
  }
}
```

### 7. Circular Dependencies (avoid_circular_dependency 위반)

```dart
// ❌ lib/domain/usecases/user_usecase.dart
import '../repositories/user_repository.dart';
import 'order_usecase.dart'; // ❌ This will create circular dependency

class UserUseCase {
  final UserRepository repository;
  final OrderUseCase orderUseCase; // ❌ Circular reference
  
  UserUseCase(this.repository, this.orderUseCase);
}

// ❌ lib/domain/usecases/order_usecase.dart
import 'user_usecase.dart'; // ❌ This creates circular dependency

class OrderUseCase {
  final UserUseCase userUseCase; // ❌ Circular reference
  
  OrderUseCase(this.userUseCase);
}
```

### 8. UseCase Without Proper Data Conversion (usecase_orchestration 위반)

```dart
// ❌ lib/domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<UserModel> call(String userId) async { // ❌ Returning Model instead of Entity
    final result = await repository.getUser(userId);
    return result; // ❌ No conversion, wrong return type
  }
}
```

### 9. keepAlive Outside App-Wide State (riverpod_keep_alive 위반)

```dart
// ❌ lib/features/todo/presentation/providers/todo_provider.dart
@Riverpod(keepAlive: true) // ❌ Feature-scoped list kept alive "to avoid dispose errors"
Future<List<Todo>> todoList(Ref ref) => ref.watch(getTodosUseCaseProvider)();
```

```dart
// ✅ lib/features/iap/presentation/providers/iap_providers.dart
/// 구매 스트림 구독은 앱 세션에 정확히 1개여야 하므로 화면 수명과 분리한다.
@Riverpod(keepAlive: true) // ✅ Name carries an app-lifetime keyword ("listener")
void purchaseStreamListener(Ref ref) { /* subscribe once, cancel in onDispose */ }
```

The rule is a name/path heuristic. It accepts names containing an app-wide
state keyword (auth, user, session, settings, preferences, config, theme,
locale, cache, analytics, notification, connectivity, permission, account), an
app-lifetime keyword (startup, bootstrap, listener, manager, storage,
timezone), an infrastructure keyword (datasource, repository, usecase, service,
client, api), or any file under an `auth/` path. Matching is a case-insensitive
substring test on the declaration name, so `apiKey` passes via `api`.

A global cache whose name is a plain noun (for example `palettes`) is still
reported. Do not rename it to game the heuristic; keep the ignore together with
the reason so reviewers can challenge it:

```dart
// ✅ lib/core/providers/palette_providers.dart
/// 에셋 팔레트는 앱 전역 캐시라 세션 동안 1회만 로드해 유지한다.
// ignore: clean_architecture_linter/riverpod_keep_alive
@Riverpod(keepAlive: true)
Future<List<Palette>> palettes(Ref ref) => loadPalettes();
```

Runnable counterpart: `example/lib/good_examples/features/iap/presentation/providers/purchase_stream_listener_provider.dart`.

## 📋 Common Issues and Solutions

| Issue | Problem | Solution | Related Rule |
|-------|---------|----------|--------------|
| Mutable Entities | Non-final fields, setters | Use final fields, copyWith | `entity_immutability` |
| Layer Violations | Domain importing Data | Use abstractions, dependency injection | `avoid_layer_dependency_violation` |
| Exception Handling | Throwing exceptions in Repository | Return Result<Success, Failure> types | `avoid_exception_throwing_in_repository` |
| Circular Dependencies | A imports B, B imports A | Restructure dependencies, use interfaces | `avoid_circular_dependency` |
| Wrong Exception Names | Generic Exception names | Create specific exceptions with prefixes | `ensure_exception_prefix` |
| Business Logic in UI | Validation/computation in widgets | Move to UseCases or Entities | `business_logic_isolation` |
| External Dependencies | Framework imports in Domain | Keep Domain pure, use abstractions | `domain_purity` |

## 🚀 Quick Start

1. Add to your `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
      - clean_architecture_linter_require_test: true
```

2. Run the linter:
```bash
dart run custom_lint
```

## 📚 More Resources

- [Clean Architecture Guide](CLEAN_ARCHITECTURE_GUIDE.md)
- [Rule Development Guide](RULE_DEVELOPMENT_GUIDE.md)
- [Configuration Guide](CONFIGURATION.md)