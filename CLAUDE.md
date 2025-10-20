# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart package that provides custom lint rules for enforcing Clean Architecture principles in Flutter projects. It uses the `custom_lint_builder` framework to create static analysis rules that validate proper architectural boundaries and patterns.

## Clean Architecture Principles

This linter enforces the following Clean Architecture principles:

### Layer Dependencies
- ✅ **Allowed**: Presentation → Domain
- ✅ **Allowed**: Data → Domain
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

Entity providers manage domain data using `AsyncNotifier` with `AsyncValue` for automatic loading/error/data state management.

```dart
// presentation/providers/schedule_providers.dart

/// Entity Provider: Schedule List (with date range parameters)
@riverpod
class ScheduleList extends _$ScheduleList {
  @override
  Future<List<Schedule>> build({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await ref.read(getScheduleListUseCaseProvider)(
      startDate: startDate,
      endDate: endDate,
    );

    return result.when(
      success: (schedules) => schedules,
      failure: (failure) => throw failure,  // ✅ AsyncValue.error conversion
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Entity Provider: Schedule Detail (Family pattern with ID)
@riverpod
class ScheduleDetail extends _$ScheduleDetail {
  @override
  Future<Schedule> build(String scheduleId) async {  // ✅ ID parameter, not entity
    final result = await ref.read(getScheduleDetailUseCaseProvider)(scheduleId);

    return result.when(
      success: (schedule) => schedule,
      failure: (failure) => throw failure,
    );
  }

  Future<void> confirmSchedule(List<String> attendeeIds) async {
    final currentSchedule = state.value;
    if (currentSchedule == null) return;

    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final result = await ref.read(confirmScheduleUseCaseProvider)(
        currentSchedule.id,
        attendeeIds,
      );

      return result.when(
        success: (updatedSchedule) => updatedSchedule,
        failure: (failure) => throw failure,
      );
    });
  }
}

/// Entity UI Extensions (formatting only)
extension ScheduleUIX on Schedule {
  String get formattedDate => DateFormat('MMM dd, yyyy').format(startDate);
  String get formattedTimeRange =>
      '${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}';
  Color get statusColor {
    if (isExpired) return Colors.grey;
    if (isConfirmed) return Colors.green;
    return Colors.orange;
  }
  IconData get statusIcon {
    if (isExpired) return Icons.event_busy;
    if (isConfirmed) return Icons.check_circle;
    return Icons.pending;
  }
}
```

### ✅ Tier 2: UI State Providers (Depends on Entity)

UI State providers manage presentation-specific state and depend on entity providers via `ref.watch()` or `ref.listen()`.

```dart
// presentation/providers/schedule_ui_providers.dart

/// UI State (Freezed)
@freezed
sealed class ScheduleDetailUIState with _$ScheduleDetailUIState {
  const factory ScheduleDetailUIState({
    @Default([]) List<String> selectedAttendeeIds,
    @Default(false) bool isConfirmationDialogOpen,
    @Default(false) bool isSubmitting,
  }) = _ScheduleDetailUIState;
}

extension ScheduleDetailUIStateX on ScheduleDetailUIState {
  int get selectedCount => selectedAttendeeIds.length;
  bool get hasSelection => selectedAttendeeIds.isNotEmpty;
}

/// UI State Provider (depends on Entity Provider)
@riverpod
class ScheduleDetailUI extends _$ScheduleDetailUI {
  @override
  ScheduleDetailUIState build(String scheduleId) {
    // ✅ Listen to entity changes
    ref.listen(
      scheduleDetailProvider(scheduleId),
      (previous, next) {
        // Reset UI state when entity changes
        next.whenData((_) {
          if (previous?.value?.id != next.value?.id) {
            state = const ScheduleDetailUIState();
          }
        });
      },
    );

    return const ScheduleDetailUIState();
  }

  void toggleAttendee(String attendeeId) {
    final updated = state.selectedAttendeeIds.contains(attendeeId)
        ? state.selectedAttendeeIds.where((id) => id != attendeeId).toList()
        : [...state.selectedAttendeeIds, attendeeId];

    state = state.copyWith(selectedAttendeeIds: updated);
  }

  void openConfirmationDialog() {
    state = state.copyWith(isConfirmationDialogOpen: true);
  }

  void closeConfirmationDialog() {
    state = state.copyWith(isConfirmationDialogOpen: false);
  }

  Future<void> confirmSchedule() async {
    if (!state.hasSelection || state.isSubmitting) return;

    state = state.copyWith(isSubmitting: true);

    try {
      await ref.read(scheduleDetailProvider(scheduleId).notifier)
          .confirmSchedule(state.selectedAttendeeIds);

      // Success: reset UI state
      state = const ScheduleDetailUIState();
    } catch (e) {
      state = state.copyWith(isSubmitting: false);
      rethrow;
    }
  }
}
```

### ✅ Tier 3: Computed Logic Providers (Entity + UI Combination)

Computed providers derive values from entity and UI state.

```dart
// presentation/providers/schedule_computed_providers.dart

/// Can confirm schedule? (combines entity + UI state)
@riverpod
bool canConfirmSchedule(CanConfirmScheduleRef ref, String scheduleId) {
  final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));
  final uiState = ref.watch(scheduleDetailUIProvider(scheduleId));

  return scheduleAsync.when(
    data: (schedule) =>
        uiState.hasSelection &&
        !schedule.isExpired &&
        !schedule.isConfirmed &&
        uiState.selectedCount <= schedule.maxAttendees,
    loading: () => false,
    error: (_, __) => false,
  );
}

/// Remaining slots
@riverpod
int remainingSlots(RemainingSlotsRef ref, String scheduleId) {
  final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));
  final uiState = ref.watch(scheduleDetailUIProvider(scheduleId));

  return scheduleAsync.when(
    data: (schedule) => schedule.maxAttendees - uiState.selectedCount,
    loading: () => 0,
    error: (_, __) => 0,
  );
}
```

### ✅ Widget Usage (AsyncValue.when Pattern)

```dart
// presentation/pages/schedule_detail_page.dart

class ScheduleDetailPage extends ConsumerWidget {
  final String scheduleId;

  const ScheduleDetailPage({required this.scheduleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Watch entity provider (AsyncValue)
    final scheduleAsync = ref.watch(scheduleDetailProvider(scheduleId));

    // ✅ Watch UI state provider
    final uiState = ref.watch(scheduleDetailUIProvider(scheduleId));
    final uiNotifier = ref.read(scheduleDetailUIProvider(scheduleId).notifier);

    // ✅ Watch computed providers
    final canConfirm = ref.watch(canConfirmScheduleProvider(scheduleId));
    final remainingSlots = ref.watch(remainingSlotsProvider(scheduleId));

    // ✅ AsyncValue.when() pattern
    return scheduleAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),

      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text('Error: $error'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(scheduleDetailProvider(scheduleId)),
              child: Text('Retry'),
            ),
          ],
        ),
      ),

      data: (schedule) {  // ✅ schedule is non-nullable here
        return Column(
          children: [
            // ✅ Entity UI Extensions
            Card(
              child: ListTile(
                leading: Icon(schedule.statusIcon, color: schedule.statusColor),
                title: Text(schedule.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(schedule.formattedDate),
                    Text(schedule.formattedTimeRange),
                  ],
                ),
              ),
            ),

            // ✅ Computed logic
            Text('Remaining: $remainingSlots slots'),

            // ✅ Attendee list
            Expanded(
              child: ListView.builder(
                itemCount: schedule.attendees.length,
                itemBuilder: (context, index) {
                  final attendee = schedule.attendees[index];
                  final isSelected = uiState.selectedAttendeeIds.contains(attendee.id);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (_) => uiNotifier.toggleAttendee(attendee.id),
                    title: Text(attendee.name),
                  );
                },
              ),
            ),

            // ✅ Confirm button
            ElevatedButton(
              onPressed: canConfirm && !uiState.isSubmitting
                  ? uiNotifier.openConfirmationDialog
                  : null,
              child: uiState.isSubmitting
                  ? CircularProgressIndicator()
                  : Text('Confirm Schedule'),
            ),
          ],
        );
      },
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

### Key Principles

1. **Entity Providers**: Use `AsyncNotifier` with `Future<T> build()` for domain data
2. **UI State Providers**: Use `Notifier` with synchronous `build()` for UI-only state
3. **Family Pattern**: Always use IDs, never entity objects as parameters
4. **Dependencies**: Use `ref.watch()` or `ref.listen()` to depend on entity providers
5. **AsyncValue**: Let Riverpod manage loading/error/data states automatically
6. **Computed Logic**: Create separate providers for derived values
7. **Entity UI Extensions**: Keep formatting/display logic in extensions, not business logic

See [CLEAN_ARCHITECTURE_GUIDE.md](doc/CLEAN_ARCHITECTURE_GUIDE.md) for more comprehensive examples.

### ❌ Violation: Domain Repository is Concrete (Not Abstract)

**Problem**:
```dart
// domain/repositories/user_repository.dart
class UserRepository {  // ❌ WRONG - Concrete class in domain
  Future<User?> getUser(String id) {
    // Implementation in domain layer
  }
}
```

**Solution**:
```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {  // ✅ CORRECT - Abstract interface
  Future<Result<User, Failure>> getUser(String id);
}

// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {  // ✅ Implementation in data layer
  @override
  Future<Result<User, Failure>> getUser(String id) async {
    try {
      final model = await dataSource.getUser(id);
      return Success(model.toEntity());
    } on DataException catch (e) {
      return Failure(UserFailure.notFound(message: e.message));
    }
  }
}
```

### ❌ Violation: RepositoryImpl Missing Interface Implementation

**Problem**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl {  // ❌ WRONG - No implements clause
  Future<Result<User, Failure>> getUser(String id) async { }
}
```

**Solution**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {  // ✅ CORRECT
  final UserDataSource dataSource;

  UserRepositoryImpl({required this.dataSource});

  @override
  Future<Result<User, Failure>> getUser(String id) async {
    try {
      final model = await dataSource.getUser(id);
      return Success(model.toEntity());
    } on DataException catch (e) {
      return Failure(UserFailure.fromDataException(e));
    }
  }
}
```

### ❌ Violation: Repository Method Returns Model Instead of Entity

**Problem**:
```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {
  Future<Result<UserModel, Failure>> getUser(String id);  // ❌ WRONG - Returns Model
  Future<List<UserModel>> getUsers();  // ❌ WRONG - Returns Model
}
```

**Solution**:
```dart
// domain/repositories/user_repository.dart
abstract interface class UserRepository {
  Future<Result<User, Failure>> getUser(String id);  // ✅ CORRECT - Returns Entity
  Future<Result<List<User>, Failure>> getUsers();  // ✅ CORRECT - Returns Entity
}
```

### ❌ Violation: Repository Method Doesn't Return Result Type

**Problem**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  Future<User?> getUser(String id) async {  // ❌ WRONG - No Result wrapper
    final model = await dataSource.getUser(id);
    return model.toEntity();
  }
}
```

**Solution**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  Future<Result<User, Failure>> getUser(String id) async {  // ✅ CORRECT
    try {
      final model = await dataSource.getUser(id);
      return Success(model.toEntity());
    } on DataException catch (e) {
      return Failure(UserFailure.fromDataException(e));
    }
  }
}
```

### ❌ Violation: Repository Throws Exceptions

**Problem**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  Future<Result<User, Failure>> getUser(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('ID required');  // ❌ WRONG - Repository throwing
    }
    // ...
  }
}
```

**Solution**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  Future<Result<User, Failure>> getUser(String id) async {
    if (id.isEmpty) {
      return Failure(UserFailure.invalidInput(message: 'ID required'));  // ✅ CORRECT
    }

    try {
      final model = await dataSource.getUser(id);  // DataSource throws
      return Success(model.toEntity());
    } on DataException catch (e) {
      return Failure(UserFailure.fromDataException(e));  // ✅ Convert to Failure
    }
  }
}
```

### ❌ Violation: Direct .entity Property Access in Data Layer

**Problem**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  Future<Result<List<User>, Failure>> getUsers() async {
    try {
      final models = await dataSource.getUsers();
      return Success(models.map((m) => m.entity).toList());  // ❌ WRONG - Direct access
    } on DataException catch (e) {
      return Failure(UserFailure.fromDataException(e));
    }
  }
}
```

**Solution**:
```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  Future<Result<List<User>, Failure>> getUsers() async {
    try {
      final models = await dataSource.getUsers();
      return Success(models.map((m) => m.toEntity()).toList());  // ✅ CORRECT - Use method
    } on DataException catch (e) {
      return Failure(UserFailure.fromDataException(e));
    }
  }
}
```

**Why**: Using `.toEntity()` method instead of direct `.entity` access:
- Provides explicit conversion boundary between Model and Entity
- Allows future conversion logic changes in one place
- Makes architectural boundaries clear in code
- Exception: Direct `.entity` access is allowed inside extension methods where conversion is implemented

**Note on fromEntity()**: While `toEntity()` is required in extensions, `fromEntity()` should be implemented as a factory constructor in the Model class:
```dart
factory TodoModel.fromEntity(Todo entity, {String? etag}) {
  return TodoModel(entity: entity, etag: etag);
}
```
This is the Dart/Freezed way and allows calling `TodoModel.fromEntity(entity)` naturally.

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

## Exception Naming & Layer Patterns

### ❌ Violation: Domain Exception Missing Feature Prefix

**Problem**:
```dart
// domain/exceptions/todo_exceptions.dart
class NotFoundException implements Exception {  // ❌ WRONG - Too generic
  final String message;
  NotFoundException(this.message);
}

class ValidationException implements Exception {  // ❌ WRONG - Missing feature prefix
  final String message;
  ValidationException(this.message);
}
```

**Solution**:
```dart
// domain/exceptions/todo_exceptions.dart
class TodoNotFoundException implements Exception {  // ✅ CORRECT - Feature prefix
  final String message;
  TodoNotFoundException(this.message);
}

class TodoValidationException implements Exception {  // ✅ CORRECT - Feature prefix
  final String message;
  TodoValidationException(this.message);
}
```

**Why**: Feature prefixes prevent naming conflicts and clearly indicate which feature the exception belongs to.

### ❌ Violation: DataSource Using Generic Exceptions

**Problem**:
```dart
// data/datasources/todo_remote_datasource.dart
class TodoRemoteDataSource {
  Future<Todo> getTodo(String id) async {
    throw Exception('Custom error');  // ❌ WRONG - Generic Exception
  }

  Future<List<Todo>> getTodos() async {
    throw StateError('Invalid state');  // ❌ WRONG - Dart built-in
  }

  Future<void> deleteTodo(String id) async {
    throw CustomApiException('API error');  // ❌ WRONG - Custom exception
  }
}
```

**Solution**:
```dart
// data/datasources/todo_remote_datasource.dart
class TodoRemoteDataSource {
  Future<Todo> getTodo(String id) async {
    final response = await client.get('/todos/$id');

    if (response.statusCode == 404) {
      throw NotFoundException('Todo not found: $id');  // ✅ CORRECT
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException('Auth required');  // ✅ CORRECT
    }

    if (response.statusCode >= 500) {
      throw ServerException('Server error');  // ✅ CORRECT
    }

    return Todo.fromJson(response.data);
  }

  Future<List<Todo>> getTodos() async {
    try {
      return await client.get('/todos');
    } catch (e) {
      throw NetworkException('Connection failed: $e');  // ✅ CORRECT
    }
  }

  Future<void> deleteTodo(String id) async {
    throw DataSourceException('Delete operation failed');  // ✅ CORRECT
  }
}
```

**Allowed Data Layer Exceptions**:
- ✅ `NotFoundException` - For 404 errors
- ✅ `UnauthorizedException` - For 401/403 errors
- ✅ `NetworkException` - For connection errors
- ✅ `ServerException` - For 5xx server errors
- ✅ `CacheException` - For cache errors
- ✅ `DatabaseException` - For database errors
- ✅ `DataSourceException` - For generic data source errors

### ❌ Violation: Presentation Layer Using Data Exceptions

**Problem**:
```dart
// presentation/widgets/todo_list.dart
class TodoList extends StatelessWidget {
  void _loadTodos() {
    try {
      // ...
    } on NetworkException catch (e) {  // ❌ WRONG - Data exception in Presentation
      showError(e.message);
    } on CacheException catch (e) {  // ❌ WRONG - Data exception in Presentation
      showError(e.message);
    }
  }
}
```

**Solution**:
```dart
// presentation/widgets/todo_list.dart
class TodoList extends StatelessWidget {
  void _loadTodos() {
    try {
      // UseCase returns Result, unwrap it
      final result = await getTodosUseCase();

      result.when(
        success: (todos) => _showTodos(todos),
        failure: (failure) => _handleFailure(failure),  // ✅ Handle domain Failure
      );
    } on TodoNotFoundException catch (e) {  // ✅ CORRECT - Domain exception
      showError('Todos not found');
    } on TodoNetworkFailure catch (e) {  // ✅ CORRECT - Domain Failure type
      showError('Network error');
    }
  }
}
```

**Why**: Presentation layer should only handle domain-level exceptions/failures. Data layer exceptions (NetworkException, CacheException) should be caught by Repository and converted to domain Failures.

### Exception Handling Layer Pattern Summary

**Domain Layer**:
- ✅ Feature-prefixed exceptions (e.g., `TodoNotFoundException`, `UserValidationException`)
- ✅ Domain-specific Failure types
- ❌ No generic exception names without prefix
- ❌ No data layer exceptions

**Data Layer**:
- ✅ DataSource throws defined Data exceptions (NetworkException, CacheException, etc.)
- ✅ Repository catches Data exceptions and converts to `Result<T, Failure>`
- ❌ No generic `Exception`, `StateError`, or custom exception types in DataSource
- ❌ Repository never throws exceptions (returns Result instead)

**Presentation Layer**:
- ✅ Handle domain exceptions and Failure types only
- ✅ Unwrap Result from UseCases
- ❌ Never catch or handle Data layer exceptions (NetworkException, CacheException, etc.)
- ❌ No direct DataSource or Repository usage

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
