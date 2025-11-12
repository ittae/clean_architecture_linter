# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart package that provides custom lint rules for enforcing Clean Architecture principles in Flutter projects. It uses the `custom_lint_builder` framework to create static analysis rules that validate proper architectural boundaries and patterns.

## Clean Architecture Principles

This linter enforces the following Clean Architecture principles:

### Layer Dependencies
- ✅ **Allowed**: Presentation → Domain
- ✅ **Allowed**: Data → Domain
- ✅ **Allowed**: Domain can use `dart:io` for type references (File, Directory) in method signatures
- ❌ **Violation**: Presentation → Data
- ❌ **Violation**: Domain → Presentation
- ❌ **Violation**: Domain → Data

### Layer-Specific Patterns
- **Data Layer**: Use **Freezed Models** (contains Entity + metadata only) with extensions in same file
- **Domain Layer**: Use **Freezed Entities** with business logic extensions in same file
- **Presentation Layer**: Use **Freezed State** (Riverpod) with UI extensions in same file - NO ViewModels

**Key Rules**:
- Presentation layer should NEVER import from Data layer - Always use Domain Entities
- Models contain Entities (no duplicate data)
- Extensions in same file as the class
- NO separate extensions/ directories

For detailed examples and implementation patterns, see [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md).

## Common Lint Violations & Solutions

### ❌ Violation: Presentation imports Data Model

**Problem**:
```dart
// presentation/widgets/todo_list.dart
import 'package:app/features/todos/data/models/todo_model.dart';  // ❌ WRONG
```

**Solution**:
```dart
// presentation/widgets/todo_list.dart
import 'package:app/features/todos/domain/entities/todo.dart';  // ✅ CORRECT
```

### ✅ Allowed: Domain Layer with dart:io Types

**Allowed Usage** (Type references only):
```dart
// domain/repositories/profile_image_repository.dart
import 'dart:io';  // ✅ CORRECT - Used only for File type in method signature

abstract interface class ProfileImageRepository {
  Future<Result<ProfileImage, Failure>> saveProfileImage({
    required File imageFile,  // ✅ Type reference is allowed
    required String userId,
  });
}
```

**Why**: Domain layer can use `dart:io` types (File, Directory) in method signatures for abstraction purposes. The actual I/O operations are implemented in the data layer.

## Riverpod State Management Patterns

The linter enforces proper Riverpod state management using a **3-tier provider architecture** that separates entity data, UI state, and computed logic.

### 3-Tier Provider Architecture

```
┌─────────────────────────────────────┐
│  Tier 1: Entity Providers          │  ← AsyncNotifier + AsyncValue
│  (scheduleListProvider)             │     (Data from Domain/UseCases)
└─────────────┬───────────────────────┘
              │ ref.watch() / ref.listen()
              ↓
┌─────────────────────────────────────┐
│  Tier 2: UI State Providers        │  ← Notifier (UI-only state)
│  (scheduleDetailUIProvider)         │     (selection, dialogs, etc.)
└─────────────┬───────────────────────┘
              │
              ↓
┌─────────────────────────────────────┐
│  Tier 3: Computed Logic Providers  │  ← Functions combining
│  (canConfirmScheduleProvider)       │     Entity + UI state
└─────────────────────────────────────┘
```

### ✅ Tier 1: Entity Providers (AsyncNotifier)

Entity providers manage domain data using `AsyncNotifier` with `AsyncValue`.

```dart
@riverpod
class ScheduleDetail extends _$ScheduleDetail {
  @override
  Future<Schedule> build(String scheduleId) async {  // ✅ ID parameter, not entity
    final result = await ref.read(getScheduleDetailUseCaseProvider)(scheduleId);
    return result.when(
      success: (schedule) => schedule,
      failure: (failure) => throw failure,  // ✅ AsyncValue.error conversion
    );
  }
}

extension ScheduleUIX on Schedule {
  String get formattedDate => DateFormat('MMM dd, yyyy').format(startDate);
  Color get statusColor => isExpired ? Colors.grey : isConfirmed ? Colors.green : Colors.orange;
}
```

### ✅ Tier 2: UI State Providers (Depends on Entity)

```dart
@freezed
sealed class ScheduleDetailUIState with _$ScheduleDetailUIState {
  const factory ScheduleDetailUIState({
    @Default([]) List<String> selectedAttendeeIds,
    @Default(false) bool isSubmitting,
  }) = _ScheduleDetailUIState;
}

@riverpod
class ScheduleDetailUI extends _$ScheduleDetailUI {
  @override
  ScheduleDetailUIState build(String scheduleId) {
    ref.listen(scheduleDetailProvider(scheduleId), (prev, next) {
      next.whenData((_) {
        if (prev?.value?.id != next.value?.id) state = const ScheduleDetailUIState();
      });
    });
    return const ScheduleDetailUIState();
  }
}
```

### ✅ Tier 3: Computed Logic Providers

```dart
@riverpod
bool canConfirmSchedule(CanConfirmScheduleRef ref, String scheduleId) {
  final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));
  final uiState = ref.watch(scheduleDetailUIProvider(scheduleId));

  return scheduleAsync.when(
    data: (s) => uiState.selectedAttendeeIds.isNotEmpty && !s.isExpired,
    loading: () => false,
    error: (_, __) => false,
  );
}
```

### ✅ Widget Usage (AsyncValue.when Pattern)

```dart
class ScheduleDetailPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));

    return scheduleAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (e, s) => ErrorWidget(e),
      data: (schedule) => ScheduleContent(schedule),  // ✅ Non-nullable
    );
  }
}
```

### ❌ Common Violations

#### ❌ Violation: Manual isLoading/errorMessage in State

**Problem**:
```dart
// ❌ WRONG - Manual state management
@freezed
sealed class ScheduleState with _$ScheduleState {
  const factory ScheduleState({
    Schedule? schedule,
    @Default(false) bool isLoading,      // ❌ Manual loading
    @Default('') String errorMessage,    // ❌ Manual error
  }) = _ScheduleState;
}

@riverpod
class ScheduleNotifier extends _$ScheduleNotifier {
  @override
  ScheduleState build() => const ScheduleState();

  Future<void> loadSchedule(String id) async {
    state = state.copyWith(isLoading: true);  // ❌ Manual management
    // ...
  }
}
```

**Solution**:
```dart
// ✅ CORRECT - AsyncNotifier with AsyncValue
@riverpod
class Schedule extends _$Schedule {
  @override
  Future<entities.Schedule> build(String scheduleId) async {
    final result = await ref.read(getScheduleUseCaseProvider)(scheduleId);
    return result.when(
      success: (schedule) => schedule,
      failure: (failure) => throw failure,  // ✅ Auto AsyncValue.error
    );
  }
}

// Widget
final scheduleAsync = ref.watch(scheduleProvider(scheduleId));
scheduleAsync.when(
  loading: () => Loader(),      // ✅ Automatic
  error: (e, s) => Error(e),    // ✅ Automatic
  data: (schedule) => UI(),     // ✅ Automatic
);
```

#### ❌ Violation: Mixed Entity and UI State

**Problem**:
```dart
// ❌ WRONG - Entity and UI mixed
@freezed
class ScheduleState with _$ScheduleState {
  const factory ScheduleState({
    Schedule? schedule,                    // ❌ Entity
    @Default([]) List<String> selectedIds, // ❌ UI state
  }) = _ScheduleState;
}
```

**Solution**:
```dart
// ✅ CORRECT - Separated concerns

// Entity Provider
@riverpod
class Schedule extends _$Schedule {
  Future<entities.Schedule> build(String id) async { }
}

// UI State Provider
@freezed
class ScheduleUIState with _$ScheduleUIState {
  const factory ScheduleUIState({
    @Default([]) List<String> selectedIds,  // ✅ UI only
  }) = _ScheduleUIState;
}

@riverpod
class ScheduleUI extends _$ScheduleUI {
  ScheduleUIState build(String scheduleId) {
    ref.watch(scheduleProvider(scheduleId));  // ✅ Depends on entity
    return const ScheduleUIState();
  }
}
```

#### ❌ Violation: Family Provider with Entity Parameter

**Problem**:
```dart
// ❌ WRONG - Entity as family parameter
@riverpod
class ScheduleUI extends _$ScheduleUI {
  ScheduleUIState build(Schedule schedule) {  // ❌ Entity parameter
    // ...
  }
}
```

**Solution**:
```dart
// ✅ CORRECT - ID as family parameter
@riverpod
class ScheduleUI extends _$ScheduleUI {
  ScheduleUIState build(String scheduleId) {  // ✅ ID parameter
    final schedule = ref.watch(scheduleDetailProvider(scheduleId));
    // ...
  }
}
```

**Why**: IDs are immutable and stable, entities change. Using IDs enables proper caching, invalidation, and dependency tracking.

#### ❌ Violation: Incorrect ref.watch() / ref.read() Usage

**Problem**:
```dart
// ❌ WRONG - ref.read() for State provider in build() misses reactive updates
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final user = ref.read(currentUserProvider);  // ❌ Won't rebuild when user changes
    return getTodos(user.id);
  }
}

// ❌ WRONG - ref.watch() in method creates unwanted dependency
@riverpod
class TodoNotifier extends _$TodoNotifier {
  Future<void> createTodo(String title) async {
    final user = ref.watch(currentUserProvider);  // ❌ Creates unwanted dependency
    await repository.createTodo(user.id, title);
  }
}
```

**Solution**:
```dart
// ✅ CORRECT - ref.watch() for State provider in build()
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final user = ref.watch(currentUserProvider);  // ✅ Rebuilds when user changes
    return getTodos(user.id);
  }
}

// ✅ CORRECT - ref.read() for UseCase provider in build()
@riverpod
class ScheduleList extends _$ScheduleList {
  @override
  Future<List<Schedule>> build() async {
    final result = await ref.read(getScheduleListUseCaseProvider)();  // ✅ One-time UseCase call
    return result.when(
      success: (schedules) => schedules,
      failure: (failure) => throw failure,
    );
  }
}

// ✅ CORRECT - ref.read() in methods for one-time access
@riverpod
class TodoNotifier extends _$TodoNotifier {
  Future<void> createTodo(String title) async {
    final user = ref.read(currentUserProvider);  // ✅ One-time read
    await repository.createTodo(user.id, title);
  }
}

// ✅ CORRECT - ref.read() for .notifier access
@riverpod
class TodoUI extends _$TodoUI {
  void confirmSchedule() {
    ref.read(scheduleProvider.notifier).confirm();  // ✅ .notifier always uses ref.read()
  }
}
```

**Why**:
- `ref.watch()` creates reactive dependencies that rebuild when the provider changes
- `ref.read()` reads the current value without creating dependencies
- **State providers** (other Notifiers) need `ref.watch()` in `build()` to rebuild when data changes
- **UseCase providers** (one-time function calls) use `ref.read()` because they don't need reactive tracking
- Using `ref.read()` for State providers in `build()` means the provider won't rebuild (stale data)
- Using `ref.watch()` in methods creates unwanted dependencies and can cause unnecessary rebuilds

**Rules**:
- ✅ In `build()` methods: Use `ref.watch()` for **State providers** (reactive dependencies)
- ✅ In `build()` methods: Use `ref.read()` for **UseCase providers** (one-time function calls)
- ✅ In `build()` methods: Use `ref.read()` for **`.notifier` access**
- ✅ In other methods: Use `ref.read()` for all providers (one-time reads)
- ✅ Exception: `ref.listen()` can be used in `build()` for side effects without returning values

**UseCase Provider Identification**:
- Provider name ends with `UseCaseProvider` (e.g., `getTodosUseCaseProvider`)
- Provider name starts with action verbs: `get`, `create`, `update`, `delete`, `fetch`, `save`, `load`, `submit`, `send`, `retrieve`
- Followed by immediate function call: `ref.read(useCaseProvider)()`

#### ❌ Violation: Provider Function Missing Type Suffix

**Problem**:
```dart
// ❌ WRONG - Missing 'usecase' suffix
@riverpod
GetEventsUsecase getEvents(Ref ref) {
  return GetEventsUsecase(ref.watch(eventRepositoryProvider));
}
// Generates: getEventsProvider (ambiguous!)

// ❌ WRONG - Missing 'repository' suffix
@riverpod
EventRepository eventRepo(Ref ref) {
  return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
}
// Generates: eventRepoProvider (ambiguous!)

// ❌ WRONG - Missing 'datasource' suffix
@riverpod
EventDataSource eventData(Ref ref) {
  return EventRemoteDataSource();
}
// Generates: eventDataProvider (ambiguous!)
```

**Solution**:
```dart
// ✅ CORRECT - Includes 'usecase' suffix
@riverpod
GetEventsUsecase getEventsUsecase(Ref ref) {
  return GetEventsUsecase(ref.watch(eventRepositoryProvider));
}
// Generates: getEventsUsecaseProvider (clear!)

// ✅ CORRECT - Includes 'repository' suffix
@riverpod
EventRepository eventRepository(Ref ref) {
  return EventRepositoryImpl(ref.watch(eventDataSourceProvider));
}
// Generates: eventRepositoryProvider (clear!)

// ✅ CORRECT - Includes 'datasource' suffix
@riverpod
EventDataSource eventDataSource(Ref ref) {
  return EventRemoteDataSource();
}
// Generates: eventDataSourceProvider (clear!)
```

**Why**:
- Riverpod code generation creates provider names from function names
- Without proper suffix, generated provider names are ambiguous (e.g., `getEventsProvider`)
- With proper suffix, provider names are clear (e.g., `getEventsUsecaseProvider`)
- Proper naming enables automatic UseCase provider detection in `ref.watch()`/`ref.read()` rules
- Consistent naming improves codebase maintainability

**Rules**:
- ✅ Repository return type: function name must end with `repository`
- ✅ UseCase return type: function name must end with `usecase`
- ✅ DataSource return type: function name must end with `datasource`

### Key Principles

1. **Entity Providers**: Use `AsyncNotifier` with `Future<T> build()` for domain data
2. **UI State Providers**: Use `Notifier` with synchronous `build()` for UI-only state
3. **Family Pattern**: Always use IDs, never entity objects as parameters
4. **Dependencies**: Use `ref.watch()` or `ref.listen()` to depend on entity providers
5. **AsyncValue**: Let Riverpod manage loading/error/data states automatically
6. **Computed Logic**: Create separate providers for derived values
7. **Entity UI Extensions**: Keep formatting/display logic in extensions, not business logic

See [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md) for more comprehensive examples.

## Repository Pattern Violations

### Common Issues

**❌ Domain Repository Concrete**: Use `abstract interface class`
**❌ RepositoryImpl No Interface**: Must `implements` domain interface
**❌ Returns Model**: Must return `Result<Entity, Failure>`
**❌ No Result Type**: Wrap return in `Result<T, Failure>`
**❌ Throws Exceptions**: Return `Failure` instead
**❌ Direct `.entity` Access**: Use `.toEntity()` method

### Correct Pattern

```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {
  Future<Result<User, Failure>> getUser(String id);
}

// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  @override
  Future<Result<User, Failure>> getUser(String id) async {
    if (id.isEmpty) return Failure(UserFailure.invalidInput());

    try {
      final model = await dataSource.getUser(id);
      return Success(model.toEntity());  // ✅ Use method, not .entity
    } on DataException catch (e) {
      return Failure(UserFailure.fromException(e));
    }
  }
}

// Model with factory
factory TodoModel.fromEntity(Todo entity, {String? etag}) {
  return TodoModel(entity: entity, etag: etag);
}
```

### Repository Pattern Summary

**Domain Layer (Interfaces)**:
- ✅ Abstract classes or abstract interface classes
- ✅ Return `Result<Entity, Failure>` types
- ✅ Named `*Repository` (e.g., `UserRepository`, `TodoRepository`)
- ❌ No implementations or method bodies
- ❌ No Model types in signatures

**Data Layer (Implementations)**:
- ✅ Concrete classes implementing domain interfaces
- ✅ Named `*RepositoryImpl` (e.g., `UserRepositoryImpl`)
- ✅ Must use `implements` keyword
- ✅ Catch DataSource exceptions and convert to `Result`
- ✅ Use `.toEntity()` method instead of direct `.entity` access
- ❌ Never throw exceptions directly
- ❌ No Model types in return signatures (convert to Entity)
- ❌ Never access `.entity` property directly (use `.toEntity()` method)

## Instance Variables & Stateless Architecture

UseCase, Repository, and DataSource classes must be **stateless** and only contain **final** dependency injection fields.

### Allowed Instance Variables

**UseCase** - Only `final`/`const` Repository and Service dependencies:
```dart
// ✅ CORRECT
class GetTodoUseCase {
  final TodoRepository repository;  // ✅ Repository dependency
  final RankingService rankingService;  // ✅ Domain Service dependency

  const GetTodoUseCase(this.repository, this.rankingService);

  Future<Todo> call(String id) {
    return repository.getTodo(id);
  }
}
```

**Repository** - Only `final`/`const` DataSource and infrastructure dependencies:
```dart
// ✅ CORRECT - Both "DataSource" and "Datasource" are accepted
class TodoRepositoryImpl implements TodoRepository {
  final TodoRemoteDataSource remoteDataSource;  // ✅ DataSource (uppercase S)
  final TodoLocalDataSource localDataSource;    // ✅ DataSource
  final AuthDatasource authDatasource;          // ✅ Datasource (lowercase s)
  final StreamController<User> authStateController;  // ✅ Infrastructure
  final String userId;  // ✅ Configuration primitive

  const TodoRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.authDatasource,
    required this.authStateController,
    required this.userId,
  });
}
```

**DataSource** - Only `final`/`const` infrastructure dependencies:
```dart
// ✅ CORRECT
class TodoRemoteDataSource {
  final Dio client;       // ✅ HTTP client
  final String baseUrl;   // ✅ Configuration value

  // ✅ const fields for magic strings (best practice)
  static const String _todoCollection = 'todos';
  static const String _userIdField = 'userId';

  const TodoRemoteDataSource({
    required this.client,
    required this.baseUrl,
  });
}

// ✅ Mock/Fake can have mutable state for testing
class MockAuthDatasource implements AuthDatasource {
  User? _currentUser;  // ✅ Allowed in Mock/Fake

  void setUser(User user) {
    _currentUser = user;
  }
}
```

### Violations

**❌ Mutable State Variables**:
```dart
// ❌ WRONG - UseCase with mutable state
class GetTodoUseCase {
  final TodoRepository repository;
  int callCount = 0;  // ❌ Mutable state variable

  Future<Todo> call(String id) {
    callCount++;  // ❌ State mutation
    return repository.getTodo(id);
  }
}

// ❌ WRONG - Repository with cache state
class TodoRepositoryImpl implements TodoRepository {
  final TodoRemoteDataSource remoteDataSource;
  Todo? _cachedTodo;  // ❌ Mutable state variable

  Future<Result<Todo, Failure>> getTodo(String id) async {
    if (_cachedTodo?.id == id) return Success(_cachedTodo!);
    // ...
  }
}
```

**❌ Wrong Layer Dependencies**:
```dart
// ❌ WRONG - UseCase directly depending on DataSource
class GetTodoUseCase {
  final TodoRemoteDataSource dataSource;  // ❌ Should use Repository

  Future<Todo> call(String id) {
    return dataSource.getTodo(id);
  }
}

// ❌ WRONG - Repository depending on UseCase (wrong direction)
class TodoRepositoryImpl implements TodoRepository {
  final GetTodoUseCase useCase;  // ❌ Wrong dependency direction

  Future<Result<Todo, Failure>> getTodo(String id) {
    return useCase.call(id);
  }
}

// ❌ WRONG - DataSource depending on Domain layer
class TodoRemoteDataSource {
  final Dio client;
  final TodoRepository repository;  // ❌ Domain dependency in Data layer
}
```

### Summary

| Component | Allowed Variables | Disallowed |
|-----------|------------------|------------|
| **UseCase** | `final` Repository, Service (Domain) | Mutable state, DataSource dependencies |
| **Repository** | `final` DataSource, primitives (String, int), infrastructure (Stream, Firebase) | Mutable state, UseCase dependencies |
| **DataSource** | `final` primitives, infrastructure (HTTP, DB, Firebase, Stream), Mock/Fake can have mutable state | Domain dependencies (Repository, UseCase, Entity), Service, Manager, Controller |

**Why Stateless?**
- State management belongs in Presentation layer (Riverpod Notifiers)
- Enables testability and predictability
- Prevents hidden state bugs
- Supports concurrent operations

**Allowed Infrastructure Types:**
- Primitives: `String`, `int`, `double`, `bool`, `num`, `List`, `Map`, `Set`
- Async: `Stream`, `Future`, `Completer`, `StreamController`, `StreamSubscription`
- HTTP: `Dio`, `Client`, `Http`
- Firebase: `Firebase*`, `Firestore*`
- Database: `Database*`, `Cache*`, `Storage*`
- Messaging: `Messaging*`

**Mock/Fake Exception:**
- Classes starting with `Mock` or `Fake` can have mutable state for testing purposes

## Exception Naming & Layer Patterns

### Common Issues

**❌ Domain Exceptions No Prefix**: Use feature prefix (e.g., `TodoNotFoundException`)
**❌ DataSource Generic Exceptions**: Use defined exceptions (NetworkException, etc.)
**❌ Presentation Uses Data Exceptions**: Only handle domain Failure types

### Correct Pattern

```dart
// domain/exceptions/todo_exceptions.dart
class TodoNotFoundException implements Exception { }  // ✅ Feature prefix
class TodoValidationException implements Exception { }

// data/datasources/todo_remote_datasource.dart
class TodoRemoteDataSource {
  Future<Todo> getTodo(String id) async {
    if (response.statusCode == 404) throw NotFoundException();  // ✅
    if (response.statusCode >= 500) throw ServerException();  // ✅
    return Todo.fromJson(response.data);
  }
}

// presentation/widgets/todo_list.dart
result.when(
  success: (todos) => _showTodos(todos),
  failure: (failure) => _handleFailure(failure),  // ✅ Domain Failure
);
```

### Allowed Data Layer Exceptions
- `NotFoundException`, `UnauthorizedException`, `NetworkException`, `ServerException`, `CacheException`, `DatabaseException`, `DataSourceException`

## Error Message Guidelines

The linter provides concise error messages optimized for VS Code PROBLEMS panel:

### Message Structure
- **Problem Message**: Specific issue with context (class name, field name, type)
- **Correction Message**: Brief, actionable fix (1 line, no examples)

### Examples

**✅ Good (Concise)**:
```
Problem: UseCase "GetTodoUseCase" should only have Repository or Service dependencies. Found field "dataSource" of type "TodoDataSource"
Correction: UseCase should depend on Repository or Service only. Use final/const.
```

**❌ Bad (Verbose)**:
```
Problem: Field validation failed
Correction: UseCase classes should only depend on Repository interfaces or Domain Services.
Make the field final/const and use a Repository or Service type, or remove it if it's state management.
Examples:
  ❌ Bad:  final TodoDataSource dataSource
  ✅ Good: final TodoRepository repository
```

### Design Principles
1. **Problem messages**: Include specific details (class, field, type)
2. **Correction messages**: Brief, actionable (≤ 80 chars preferred)
3. **No examples**: Users understand from problem context
4. **Consistency**: Similar issues use similar wording

## Configuration

All Clean Architecture rules are **enabled by default**. No configuration needed in `analysis_options.yaml`.

### Optional: Test Coverage

The `clean_architecture_linter_require_test` rule is **disabled by default**. Enable it to enforce test files for critical components:

```yaml
# analysis_options.yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
      check_usecases: true       # Require tests for UseCases
      check_repositories: true   # Require tests for Repositories
      check_datasources: true    # Require tests for DataSources
      check_notifiers: true      # Require tests for Notifiers
```

To disable specific checks:

```yaml
custom_lint:
  rules:
    - clean_architecture_linter_require_test: true
      check_datasources: false   # Skip DataSource test checks
      check_notifiers: false     # Skip Notifier test checks
```

### Components Requiring Tests

1. **UseCase** (ERROR) - Core business logic must be tested
2. **Repository Implementation** (ERROR) - Data layer integration must be tested
3. **DataSource Implementation** (WARNING) - Either has tests OR abstract interface
4. **Riverpod Notifier** (ERROR) - State management logic must be tested

### Test File Naming Convention

```
lib/features/user/domain/usecases/get_user_usecase.dart
→ test/features/user/domain/usecases/get_user_usecase_test.dart

lib/features/user/data/repositories/user_repository_impl.dart
→ test/features/user/data/repositories/user_repository_impl_test.dart
```

### DataSource Special Case

DataSource can avoid the warning in two ways:
1. ✅ Have a test file (direct testing)
2. ✅ Have an abstract interface (mockable for repository tests)

```dart
// Option 1: With test file
class UserRemoteDataSource {
  Future<List<UserModel>> getUsers() { }
}
// ✅ test/data/datasources/user_remote_datasource_test.dart exists

// Option 2: With abstract interface
abstract class UserRemoteDataSource {
  Future<List<UserModel>> getUsers();
}
class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  // ✅ Mockable in repository tests
}
```

## Common Commands

### Development
```bash
# Install dependencies
dart pub get

# Run tests
dart pub test

# Run the linter on example project
cd example && dart run custom_lint

# Check linting on the package itself
dart run custom_lint

# Analyze the package
dart analyze

# Format code
dart format .
```

### Publishing
```bash
# Check package health before publishing
dart pub publish --dry-run

# Publish package (when ready)
dart pub publish
```

## Architecture

The package is structured around the `custom_lint_builder` framework with a mixin-based architecture for code reuse:

### Core Architecture
- **Entry Point**: `lib/clean_architecture_linter.dart` - Defines the plugin and registers all lint rules
- **Base Configuration**: `lib/src/clean_architecture_linter_base.dart` - Shared utilities and configuration options (1,014 lines)
- **Mixins**: `lib/src/mixins/` - Reusable validation logic (592 total lines)
  - `exception_validation_mixin.dart` (225 lines) - Exception naming and feature prefix validation
  - `repository_rule_visitor.dart` (238 lines) - Repository interface and implementation detection
  - `return_type_validation_mixin.dart` (129 lines) - Result type and return type validation
- **Rule Categories**: Rules are organized by Clean Architecture layers:
  - `lib/src/rules/domain_rules/` - 7 rules for domain layer validation
  - `lib/src/rules/data_rules/` - 8 rules for data layer validation
  - `lib/src/rules/presentation_rules/` - 3 rules for presentation layer validation
  - `lib/src/rules/cross_layer/` - 2 rules for cross-layer boundary enforcement

### Mixin-Based Architecture (v2.0)
The package uses mixins to eliminate code duplication across lint rules:

**Exception Validation Mixin** - Applied to exception-related rules:
- `isExceptionClass()` - Checks if class implements Exception
- `isAllowedWithoutPrefix()` - Validates allowed exception names
- `isGenericExceptionName()` - Detects generic exception names needing feature prefix
- `isDataLayerException()` - Identifies data layer exceptions
- `suggestFeaturePrefix()` - Generates feature-specific exception names
- `extractFeatureName()` - Extracts feature name from file path

**Repository Rule Visitor** - Applied to repository-related rules:
- `isRepositoryImplementation()` - Detects repository implementation classes
- `isRepositoryInterface()` - Validates abstract repository interfaces
- `shouldSkipMethod()` - Identifies methods to skip (private, test-only)
- `isAllowedRepositoryThrow()` - Checks if throw is allowed in repository

**Return Type Validation Mixin** - Applied to return type rules:
- `isResultReturnType()` - Detects Result/Either/Task return types
- `shouldSkipMethod()` - Common method skipping logic

### Rule Implementation Pattern
Each lint rule extends `CleanArchitectureLintRule` and can use mixins:
1. Define a `LintCode` with name, problem message, and correction message
2. Apply relevant mixins using `with` keyword
3. Implement `runRule()` method to analyze AST nodes
4. Use mixin methods instead of duplicating validation logic
5. Report violations using the `ErrorReporter`

**Example with Mixins**:
```dart
class ExceptionNamingConventionRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {

  @override
  void runRule(...) {
    if (!isExceptionClass(node)) return;  // From mixin
    if (isGenericExceptionName(className)) {  // From mixin
      final suggestedName = suggestFeaturePrefix(className, filePath);  // From mixin
      // Report violation
    }
  }
}
```

### Code Reduction Achievements (Task 17)
- **Before Refactoring**: 1,384 lines across 10 rules
- **After Refactoring**: 1,077 lines (170 lines eliminated, 13.6% reduction)
- **Mixin Implementation**: 592 lines of reusable validation logic
- **Net Benefit**: Eliminated duplication, improved maintainability, easier to add new rules

### Key Components
- **Plugin Registration**: `_CleanArchitectureLinterPlugin` class registers all lint rules
- **AST Analysis**: Rules analyze Dart Abstract Syntax Trees to detect architectural violations
- **Mixin Composition**: Shared validation logic composed via Dart mixins
- **Utility Class**: `CleanArchitectureUtils` provides layer detection, type checking, and path utilities
- **Error Reporting**: Standardized error messages guide developers toward Clean Architecture compliance

## Development Guidelines

### Adding New Rules
1. **Identify rule category** - Determine if it's domain, data, presentation, or cross-layer
2. **Check for reusable logic** - Review existing mixins in `lib/src/mixins/`:
   - Exception validation? Use `ExceptionValidationMixin`
   - Repository validation? Use `RepositoryRuleVisitor`
   - Return type checking? Use `ReturnTypeValidationMixin`
3. **Create rule file** in appropriate directory (`domain_rules/`, `data_rules/`, `presentation_rules/`, `cross_layer/`)
4. **Extend base class** with mixins:
   ```dart
   class MyNewRule extends CleanArchitectureLintRule
       with ExceptionValidationMixin, ReturnTypeValidationMixin {
     // Use mixin methods instead of duplicating logic
   }
   ```
5. **Register the rule** in `lib/clean_architecture_linter.dart`
6. **Add examples** to `example/lib/` directories (good and bad examples)
7. **Write tests** in `test/` directory

### Using Mixins for Code Reuse
**Before** (duplicated validation logic):
```dart
class MyRule extends CleanArchitectureLintRule {
  bool _isExceptionClass(ClassDeclaration node) {
    // 15 lines of duplicated logic
  }

  bool _isDataException(String typeName) {
    // 10 lines of duplicated logic
  }
}
```

**After** (mixin-based, no duplication):
```dart
class MyRule extends CleanArchitectureLintRule
    with ExceptionValidationMixin {

  @override
  void runRule(...) {
    if (!isExceptionClass(node)) return;  // From mixin
    if (isDataLayerException(typeName)) { // From mixin
      // Custom rule logic
    }
  }
}
```

### Creating New Mixins
If you find validation logic duplicated across 3+ rules:
1. Create new mixin in `lib/src/mixins/`
2. Extract common validation methods
3. Add comprehensive dartdoc comments
4. Write unit tests for the mixin
5. Update this documentation

### Testing Strategy
- Test files go in `test/` directory
- Examples for testing rules are in `example/lib/` with `good_examples/` and `bad_examples/` subdirectories
- Use `dart pub test` to run tests
- Use `dart pub custom_lint` in example directory to test rules manually

### Configuration
- Rules are configured in `analysis_options.yaml` under `custom_lint.rules`
- Each rule can be individually enabled/disabled
- The package uses standard Dart linting with `package:lints/recommended.yaml`

## File Organization

```
lib/
├── clean_architecture_linter.dart          # Main plugin entry point
├── src/
│   ├── clean_architecture_linter_base.dart # Shared configuration & utilities (1,014 lines)
│   ├── mixins/                             # Reusable validation mixins (592 lines total)
│   │   ├── exception_validation_mixin.dart # Exception validation (225 lines)
│   │   ├── repository_rule_visitor.dart    # Repository validation (238 lines)
│   │   ├── return_type_validation_mixin.dart # Return type validation (129 lines)
│   │   └── README.md                       # Mixin documentation
│   ├── rules/
│   │   ├── domain_rules/                   # Domain layer rules (7 rules)
│   │   ├── data_rules/                     # Data layer rules (8 rules)
│   │   ├── presentation_rules/             # Presentation layer rules (3 rules)
│   │   └── cross_layer/                    # Cross-layer rules (2 rules)
│   ├── utils/                              # Additional utilities
│   └── validators/                         # Custom validators
example/
├── lib/
│   ├── good_examples/                      # Valid Clean Architecture examples
│   └── bad_examples/                       # Invalid examples that trigger rules
test/
├── mixins/                                 # Mixin unit tests
├── utils/                                  # Utility tests
└── rules/                                  # Rule integration tests
```

## Dependencies

- `analyzer: ^6.8.0` - Dart static analysis
- `custom_lint_builder: ^0.6.7` - Framework for creating custom lint rules
- `custom_lint: ^0.6.7` - Runtime for custom lint rules (dev dependency)

## Task Master AI Instructions
**Import Task Master's development workflow commands and guidelines, treat as if import is in the main CLAUDE.md file.**
@./.taskmaster/CLAUDE.md
