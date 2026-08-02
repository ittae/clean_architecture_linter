@AGENTS.md

## Project Why (Read First)

> **Org Vision:** Help people turn their plans into reality. *(원문: 사람들의 계획이 현실이 되도록 돕는 것입니다.)*
> **Org Mission:** Help people cherish yesterday, dream of tomorrow, and live today. *(원문: 어제를 소중히 여기고, 내일을 꿈꾸며, 오늘을 살아갈 수 있도록 돕는 것입니다.)*

**This project's role:** Auto-enforces Riverpod-based Clean Architecture via lints — so good architecture does not depend on a PR reviewer's memory, sustaining the Vision.

> Note: This package is also published to external users. The Org Vision is the *internal working standard for the maintainer (ittae)* and is not imposed on external users. External users only see "Automatic Clean Architecture enforcement" in the README.

Every change here must *reinforce* the Vision and this project's role. If a change would dilute them, stop and ask the human first.

### Decision Filter (ask before starting)

1. Does this change *reinforce* or *dilute* the Vision and this project's role?
2. Does this change conflict with this project's How (consistency across 33 rules, Riverpod 3-tier assumptions, Domain Purity, etc.)?
3. If it conflicts — is the principle worth changing, or should this change be dropped?

### Mandatory First Step (before any code/file changes)

When a new issue arrives, post the following as your first response (if a comment channel exists, publish it there) before starting work:

1. **Why restatement (1 sentence):** describe how this issue reinforces the Vision (사람들의 계획이 현실이 되도록 돕는 것입니다) and this project's role.
2. If you conclude it does not reinforce them → stop and ask the human.
3. If it does → state your How (approach principles) in 1–3 bullets, then begin.

> This step is a gate to catch misunderstandings early. Keep it brief and to the point.

---

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

For error handling patterns, see [UNIFIED_ERROR_GUIDE.md](doc/UNIFIED_ERROR_GUIDE.md).

For state management patterns (Riverpod + Freezed), see [STATE_MANAGEMENT_GUIDE.md](doc/STATE_MANAGEMENT_GUIDE.md).

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
    // UseCase throws AppException on error, AsyncValue catches automatically
    return ref.read(getScheduleDetailUseCaseProvider)(scheduleId);
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
    // UseCase throws AppException on error, AsyncValue catches automatically
    return ref.read(getScheduleUseCaseProvider)(scheduleId);
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
    // ✅ One-time UseCase call - throws AppException on error
    return ref.read(getScheduleListUseCaseProvider)();
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

See [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md) and [STATE_MANAGEMENT_GUIDE.md](doc/STATE_MANAGEMENT_GUIDE.md) for more comprehensive examples.

## Repository Pattern

### Error Handling Strategy

> **Note**: For detailed error handling patterns, see [UNIFIED_ERROR_GUIDE.md](doc/UNIFIED_ERROR_GUIDE.md).

The linter supports a **simplified pass-through pattern** for Repository error handling:
- DataSource throws `AppException` (defined in `app_exception.dart`)
- Repository returns `Future<Entity>` directly (no Result pattern, pass-through errors)
- UseCase calls Repository, may add business validation (throws `AppException`)
- Presentation uses `AsyncValue.guard()` to catch all exceptions

### Correct Pattern

```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {
  Future<User> getUser(String id);  // ✅ Returns Entity directly
}

// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource dataSource;

  @override
  Future<User> getUser(String id) async {
    // ✅ Pass-through: Let DataSource exceptions bubble up
    final model = await dataSource.getUser(id);
    return model.toEntity();
  }
}

// data/datasources/user_remote_datasource.dart
class UserRemoteDataSource {
  Future<UserModel> getUser(String id) async {
    try {
      final response = await client.get('/users/$id');
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      throw e.toAppException();  // ✅ Convert to AppException
    }
  }
}

// domain/usecases/get_user_usecase.dart
class GetUserUseCase {
  final UserRepository repository;

  Future<User> call(String id) async {
    if (id.isEmpty) {
      throw const InvalidInputException.withCode('errorValidationIdRequired');
    }
    return repository.getUser(id);  // ✅ Pass-through
  }
}
```

### Repository Pattern Summary

**Domain Layer (Interfaces)**:
- ✅ Abstract classes or abstract interface classes
- ✅ Return `Future<Entity>` directly (no Result pattern)
- ✅ Named `*Repository` (e.g., `UserRepository`, `TodoRepository`)
- ❌ No implementations or method bodies
- ❌ No Model types in signatures

**Data Layer (Implementations)**:
- ✅ Concrete classes implementing domain interfaces
- ✅ Named `*RepositoryImpl` (e.g., `UserRepositoryImpl`)
- ✅ Must use `implements` keyword
- ✅ Pass-through pattern: Let DataSource exceptions bubble up
- ✅ Use `.toEntity()` method instead of direct `.entity` access
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

  Future<Todo> getTodo(String id) async {
    if (_cachedTodo?.id == id) return _cachedTodo!;
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

  Future<Todo> getTodo(String id) {
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
- Async: `Stream`, `Future`, `Completer`, `StreamController`, `StreamSubscription`, `Subscription`
- HTTP: `Dio`, `Client`, `Http`
- Firebase: `Firebase*`, `Firestore*`
- Database: `Database*`, `Cache*`, `Storage*`
- Messaging: `Messaging*`
- Google Mobile Ads: `BannerAd`, `InterstitialAd`, `RewardedAd`, `NativeAd`, `AppOpenAd`, `AdWidget`
- In-App Purchase: `InAppPurchase`, `ProductDetails`, `PurchaseDetails`

**Mock/Fake Exception:**
- Classes starting with `Mock` or `Fake` can have mutable state for testing purposes
