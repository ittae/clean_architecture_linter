# Testing Guide for Clean Architecture

This guide explains the testing strategy enforced by the `test_coverage` lint rule.

## Overview

The `test_coverage` rule ensures that critical components in your Clean Architecture have corresponding test files. This helps maintain code quality and prevents regressions in business logic.

**Note**: This rule is **disabled by default**. You must explicitly enable it.

## Enabling the Rule

The `clean_architecture_linter_require_test` rule is **disabled by default**. Enable it in `analysis_options.yaml`:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
```

All component types are checked by default (UseCases, Repositories, DataSources, Notifiers).

## Selective Checking

To check only specific component types:

```yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
      check_usecases: true       # default: true
      check_repositories: true   # default: true
      check_datasources: false   # Skip DataSource checks
      check_notifiers: false     # Skip Notifier checks
```

## Disabling in Specific Files

You can ignore the rule in specific files:

```dart
// ignore_for_file: clean_architecture_linter_require_test

class MyUseCase {
  // This file won't trigger test coverage warnings
}
```

## Components Requiring Tests

### 1. UseCase (ERROR)

**Why**: UseCases contain core business logic and orchestration. They are critical to your application's functionality.

**Example**:
```dart
// lib/features/user/domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<User> call(String userId) async {
    final user = await repository.getUserById(userId);
    if (user == null) {
      throw UserNotFoundException();
    }
    return user;
  }
}
```

**Required test**:
```dart
// test/features/user/domain/usecases/get_user_usecase_test.dart
void main() {
  group('GetUserUseCase', () {
    late MockUserRepository mockRepository;
    late GetUserUseCase useCase;

    setUp(() {
      mockRepository = MockUserRepository();
      useCase = GetUserUseCase(mockRepository);
    });

    test('should return user when repository returns user', () async {
      // Arrange
      final expectedUser = User(id: '1', name: 'John');
      when(() => mockRepository.getUserById('1'))
          .thenAnswer((_) async => expectedUser);

      // Act
      final result = await useCase('1');

      // Assert
      expect(result, expectedUser);
      verify(() => mockRepository.getUserById('1')).called(1);
    });

    test('should throw UserNotFoundException when user not found', () async {
      // Arrange
      when(() => mockRepository.getUserById('1'))
          .thenAnswer((_) async => null);

      // Act & Assert
      expect(() => useCase('1'), throwsA(isA<UserNotFoundException>()));
    });
  });
}
```

### 2. Repository Implementation (ERROR)

**Why**: Repository implementations coordinate between data sources and domain layer. They need tests to ensure proper data conversion and error handling.

**Example**:
```dart
// lib/features/user/data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  final UserLocalDataSource localDataSource;

  @override
  Future<User?> getUserById(String id) async {
    try {
      final userModel = await remoteDataSource.getUserById(id);
      await localDataSource.cacheUser(userModel);
      return userModel.toEntity();
    } catch (e) {
      final cachedModel = await localDataSource.getCachedUser(id);
      return cachedModel?.toEntity();
    }
  }
}
```

**Required test**:
```dart
// test/features/user/data/repositories/user_repository_impl_test.dart
void main() {
  group('UserRepositoryImpl', () {
    late MockUserRemoteDataSource mockRemoteDataSource;
    late MockUserLocalDataSource mockLocalDataSource;
    late UserRepositoryImpl repository;

    setUp(() {
      mockRemoteDataSource = MockUserRemoteDataSource();
      mockLocalDataSource = MockUserLocalDataSource();
      repository = UserRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        localDataSource: mockLocalDataSource,
      );
    });

    test('should return entity from remote and cache it', () async {
      // Arrange
      final model = UserModel(entity: User(id: '1', name: 'John'));
      when(() => mockRemoteDataSource.getUserById('1'))
          .thenAnswer((_) async => model);
      when(() => mockLocalDataSource.cacheUser(model))
          .thenAnswer((_) async {});

      // Act
      final result = await repository.getUserById('1');

      // Assert
      expect(result, model.entity);
      verify(() => mockLocalDataSource.cacheUser(model)).called(1);
    });

    test('should return cached entity when remote fails', () async {
      // Arrange
      final cachedModel = UserModel(entity: User(id: '1', name: 'John'));
      when(() => mockRemoteDataSource.getUserById('1'))
          .thenThrow(ServerException());
      when(() => mockLocalDataSource.getCachedUser('1'))
          .thenAnswer((_) async => cachedModel);

      // Act
      final result = await repository.getUserById('1');

      // Assert
      expect(result, cachedModel.entity);
    });
  });
}
```

### 3. DataSource Implementation (WARNING)

**Why**: DataSources handle external data access. They should either have tests OR an abstract interface for mocking.

**Option A: Direct Testing**:
```dart
// lib/features/user/data/datasources/user_remote_datasource.dart
class UserRemoteDataSource {
  final http.Client client;

  Future<UserModel> getUserById(String id) async {
    final response = await client.get(Uri.parse('/users/$id'));
    return UserModel.fromJson(jsonDecode(response.body));
  }
}

// ✅ test/features/user/data/datasources/user_remote_datasource_test.dart
```

**Option B: Abstract Interface (no test needed)**:
```dart
// lib/features/user/data/datasources/user_remote_datasource.dart
abstract class UserRemoteDataSource {
  Future<UserModel> getUserById(String id);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final http.Client client;

  @override
  Future<UserModel> getUserById(String id) async {
    final response = await client.get(Uri.parse('/users/$id'));
    return UserModel.fromJson(jsonDecode(response.body));
  }
}

// ✅ No test needed - mockable in repository tests
```

### 4. Riverpod Notifier (ERROR)

**Why**: Notifiers manage UI state and coordinate UseCase calls. They need tests to ensure proper state management.

**Example**:
```dart
// lib/features/user/presentation/providers/user_provider.dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  UserState build() => const UserState();

  Future<void> loadUser(String userId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final getUserUseCase = ref.read(getUserUseCaseProvider);
      final user = await getUserUseCase(userId);
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }
}
```

**Required test**:
```dart
// test/features/user/presentation/providers/user_provider_test.dart
void main() {
  group('UserNotifier', () {
    late ProviderContainer container;
    late MockGetUserUseCase mockGetUserUseCase;

    setUp(() {
      mockGetUserUseCase = MockGetUserUseCase();
      container = ProviderContainer(
        overrides: [
          getUserUseCaseProvider.overrideWithValue(mockGetUserUseCase),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('should update state with user when load succeeds', () async {
      // Arrange
      final user = User(id: '1', name: 'John');
      when(() => mockGetUserUseCase('1')).thenAnswer((_) async => user);

      // Act
      await container.read(userNotifierProvider.notifier).loadUser('1');

      // Assert
      final state = container.read(userNotifierProvider);
      expect(state.user, user);
      expect(state.isLoading, false);
      expect(state.error, null);
    });

    test('should update state with error when load fails', () async {
      // Arrange
      when(() => mockGetUserUseCase('1'))
          .thenThrow(Exception('Network error'));

      // Act
      await container.read(userNotifierProvider.notifier).loadUser('1');

      // Assert
      final state = container.read(userNotifierProvider);
      expect(state.user, null);
      expect(state.isLoading, false);
      expect(state.error, isNotNull);
    });
  });
}
```

## Test File Naming Convention

Follow this pattern for test files:

```
lib/path/to/component.dart → test/path/to/component_test.dart
```

Examples:
- `lib/features/user/domain/usecases/get_user_usecase.dart`
  - → `test/features/user/domain/usecases/get_user_usecase_test.dart`
- `lib/features/user/data/repositories/user_repository_impl.dart`
  - → `test/features/user/data/repositories/user_repository_impl_test.dart`
- `lib/features/user/data/datasources/user_remote_datasource.dart`
  - → `test/features/user/data/datasources/user_remote_datasource_test.dart`
- `lib/features/user/presentation/providers/user_provider.dart`
  - → `test/features/user/presentation/providers/user_provider_test.dart`

## Testing Tools

### Recommended Packages

```yaml
dev_dependencies:
  test: ^1.24.0
  mocktail: ^1.0.0  # For mocking
  flutter_test:
    sdk: flutter
```

### Mocking with Mocktail

```dart
import 'package:mocktail/mocktail.dart';

// Create mock
class MockUserRepository extends Mock implements UserRepository {}

// Setup mock
setUp(() {
  mockRepository = MockUserRepository();
  when(() => mockRepository.getUserById(any()))
      .thenAnswer((_) async => User(id: '1', name: 'John'));
});

// Verify calls
verify(() => mockRepository.getUserById('1')).called(1);
```

## Best Practices

### 1. Test Business Logic, Not Framework Code

Focus tests on business logic and data transformations, not framework boilerplate:

✅ **Good**:
```dart
test('should filter out inactive users', () {
  final users = [
    User(id: '1', isActive: true),
    User(id: '2', isActive: false),
  ];
  final result = useCase.filterActiveUsers(users);
  expect(result.length, 1);
  expect(result.first.id, '1');
});
```

❌ **Bad** (testing framework):
```dart
test('should create instance', () {
  final useCase = GetUserUseCase(mockRepository);
  expect(useCase, isNotNull);
});
```

### 2. Use AAA Pattern (Arrange-Act-Assert)

Structure tests clearly:

```dart
test('should return user when repository returns user', () {
  // Arrange - Setup
  final expectedUser = User(id: '1', name: 'John');
  when(() => mockRepository.getUserById('1'))
      .thenAnswer((_) async => expectedUser);

  // Act - Execute
  final result = await useCase('1');

  // Assert - Verify
  expect(result, expectedUser);
});
```

### 3. Test Edge Cases

Don't just test happy paths:

```dart
group('GetUserUseCase', () {
  test('should return user when found');
  test('should throw when user not found');
  test('should throw when repository throws');
  test('should handle network timeout');
  test('should validate userId is not empty');
});
```

### 4. Keep Tests Independent

Each test should be able to run independently:

```dart
setUp(() {
  // Reset state before each test
  mockRepository = MockUserRepository();
  useCase = GetUserUseCase(mockRepository);
});
```

## Disabling the Rule

If you need to temporarily disable the rule for a specific file:

```dart
// ignore_for_file: test_coverage

class MyUseCase {
  // This won't trigger test_coverage warning
}
```

Or disable in `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    - test_coverage:
        require_tests: false  # Disable
```

## Summary

| Component | Severity | Why Test? | Alternative |
|-----------|----------|-----------|-------------|
| UseCase | ERROR | Core business logic | None |
| Repository Impl | ERROR | Data coordination | None |
| DataSource | WARNING | External data access | Abstract interface |
| Notifier | ERROR | State management | None |

**Remember**: Tests are not just for catching bugs—they document expected behavior and enable confident refactoring.
