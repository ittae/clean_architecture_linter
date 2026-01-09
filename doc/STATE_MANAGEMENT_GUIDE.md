# State Management Guide

Complete guide for state management with Riverpod + Freezed in this Clean Architecture project.

## Table of Contents

1. [Pattern Selection](#pattern-selection)
2. [AsyncValue Pattern](#asyncvalue-pattern)
3. [Freezed State Pattern](#freezed-state-pattern)
4. [Extensions](#extensions)
5. [Performance Optimization](#performance-optimization)
6. [Common Mistakes](#common-mistakes)

## Pattern Selection

### When to Use What

| Use Case | Pattern | Example |
|----------|---------|------------|
| Async data fetch | `AsyncValue<T>` | User list, single entity |
| Complex UI with flags | `AsyncValue<Freezed State>` | Form with validation |
| Multiple operations | `AsyncValue<Freezed State>` | Multi-step wizard |
| Error handling | `AsyncValue` | **All errors managed by AsyncValue** |

> **Important**: Error handling is always managed by `AsyncValue`.
> Do not add `errorMessage` fields to Freezed State.
> See [UNIFIED_ERROR_GUIDE.md](./UNIFIED_ERROR_GUIDE.md) for details.

### Decision Tree

```
Need UI flags (isEditing, selectedFilter, etc)? → YES → AsyncValue<Freezed State>
     ↓ NO
Need multiple related data fields? → YES → AsyncValue<Freezed State>
     ↓ NO
Simple entity fetch? → YES → AsyncValue<Entity>
```

### Error Handling Note

```dart
// ❌ WRONG: Do not use errorMessage field
@freezed
class UserState with _$UserState {
  const factory UserState({
    User? user,
    String? errorMessage,  // ❌ AsyncValue manages this
  }) = _UserState;
}

// ✅ CORRECT: AsyncValue manages errors
asyncValue.when(
  data: (state) => ContentWidget(state),
  loading: () => LoadingWidget(),
  error: (error, _) => AppErrorWidget(
    error: error,
    onRetry: () => ref.invalidate(provider),
  ),
);

// ✅ CORRECT: Convert error message in UI (using toMessage)
class AppErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? error.toMessage(context)  // i18n
        : AppLocalizations.of(context)?.errorUnknown ?? 'Unknown error';

    return Center(
      child: Column(
        children: [
          Text(message),
          FilledButton(onPressed: onRetry, child: Text('Retry')),
        ],
      ),
    );
  }
}
```

## AsyncValue Pattern

### Basic Structure

```dart
@riverpod
class Users extends _$Users {
  @override
  FutureOr<List<User>> build() async {
    // Simple fetch - returns data directly
    return await ref.read(userRepositoryProvider).fetchUsers();
  }

  // Refresh
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await ref.read(userRepositoryProvider).fetchUsers();
    });
  }
}
```

### UI Usage

```dart
// Watch the provider
final usersAsync = ref.watch(usersProvider);

// Pattern match
return usersAsync.when(
  data: (users) => ListView.builder(...),
  loading: () => CircularProgressIndicator(),
  error: (error, stack) => Text('Error: $error'),
);

// Or use conditional
if (usersAsync.isLoading) return CircularProgressIndicator();
if (usersAsync.hasError) return Text('Error');
if (usersAsync.hasValue) {
  final users = usersAsync.value!;
  return ListView.builder(...);
}
```

### Advantages

- ✅ Built-in loading/error states
- ✅ Minimal boilerplate
- ✅ Perfect for simple CRUD

### Limitations

- ❌ Can't customize error messages
- ❌ Can't add UI flags (isEditing, isSearching, etc.)
- ❌ Harder to manage multiple related operations

## Freezed State Pattern

> **Recommended Pattern Change**: Instead of Freezed State + manual isLoading/errorMessage,
> use **AsyncNotifier + AsyncValue.guard()** pattern.
> See [UNIFIED_ERROR_GUIDE.md](./UNIFIED_ERROR_GUIDE.md) for details.

### Recommended Pattern: AsyncNotifier + UI State Separation

```dart
// 1. Domain Entity
@freezed
sealed class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
  }) = _User;
}

extension UserX on User {
  // Business logic
  bool get isNameValid => name.length >= 2;
  bool get isEmailValid => email.contains('@');
}

// 2. Entity Provider (AsyncNotifier) - Data + auto loading/error management
@riverpod
class UserList extends _$UserList {
  @override
  FutureOr<List<User>> build() async {
    // Call UseCase directly, errors auto-managed by AsyncValue
    return ref.read(getUsersUseCaseProvider)();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(getUsersUseCaseProvider)(),
    );
  }

  Future<void> updateUser(User updatedUser) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(updateUserUseCaseProvider)(updatedUser);
      return ref.read(getUsersUseCaseProvider)();
    });
  }
}

// 3. UI State Provider (Notifier) - UI-only state
@freezed
sealed class UserUIState with _$UserUIState {
  const factory UserUIState({
    @Default(false) bool isEditing,
    User? selectedUser,
    // ❌ No errorMessage - AsyncValue manages this
  }) = _UserUIState;
}

extension UserUIStateX on UserUIState {
  bool get canSave => selectedUser != null && selectedUser!.isNameValid;
}

@riverpod
class UserUI extends _$UserUI {
  @override
  UserUIState build() {
    // Listen to entity changes and reset UI state
    ref.listen(userListProvider, (prev, next) {
      next.whenData((_) {
        if (prev?.value != next.value) {
          state = state.copyWith(selectedUser: null, isEditing: false);
        }
      });
    });
    return const UserUIState();
  }

  void selectUser(User user) {
    state = state.copyWith(selectedUser: user, isEditing: true);
  }

  void cancelEditing() {
    state = state.copyWith(selectedUser: null, isEditing: false);
  }
}
```

### UI Usage

```dart
class UserListPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Entity Provider (AsyncValue auto-manages loading/error/data)
    final usersAsync = ref.watch(userListProvider);
    // UI State Provider
    final uiState = ref.watch(userUIProvider);

    // ✅ AsyncValue.when() handles all states
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorWidget(
        error: error,
        onRetry: () => ref.invalidate(userListProvider),
      ),
      data: (users) => Column(
        children: [
          Text('Total: ${users.length} users'),
          Expanded(
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user.name),
                  onTap: () {
                    ref.read(userUIProvider.notifier).selectUser(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Editing dialog
class UserEditDialog extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(userListProvider);
    final uiState = ref.watch(userUIProvider);
    final selectedUser = uiState.selectedUser;

    if (selectedUser == null) return const SizedBox.shrink();

    return AlertDialog(
      title: const Text('Edit User'),
      content: Column(
        children: [
          TextField(
            initialValue: selectedUser.name,
            onChanged: (value) {
              // Update selected user
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(userUIProvider.notifier).cancelEditing();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          // ✅ Check isLoading using AsyncValue.isLoading
          onPressed: uiState.canSave && !usersAsync.isLoading
              ? () async {
                  await ref.read(userListProvider.notifier)
                      .updateUser(selectedUser);
                  // Check success via usersAsync.hasError
                  if (!ref.read(userListProvider).hasError) {
                    ref.read(userUIProvider.notifier).cancelEditing();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User updated')),
                    );
                  }
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
```

## Extensions

### Why Extensions?

```dart
// ❌ BAD: Private constructor
@freezed
class User with _$User {
  const User._();  // ❌ Breaks Freezed's generated code

  bool get isValid => name.isNotEmpty;  // ❌ Can't access fields
}

// ✅ GOOD: Extension
@freezed
class User with _$User {
  const factory User({required String name}) = _User;
}

extension UserX on User {
  bool get isValid => name.isNotEmpty;  // ✅ Clean and simple
}
```

### Exception: Freezed Unions

```dart
// ✅ EXCEPTION: Unions with common fields
@freezed
sealed class EventFailure with _$EventFailure {
  const EventFailure._();  // ✅ Required for abstract getter

  const factory EventFailure.notFound({required String message}) = _NotFound;
  const factory EventFailure.serverError({required String message}) = _ServerError;

  // Abstract getter - Freezed generates this
  @override
  String get message;  // ✅ Common field across all variants
}
```

### Extension Organization

```dart
// In same file as class definition

// Entity extension: Business logic
extension UserX on User {
  bool get isNameValid => name.length >= 2;
  bool get isEmailValid => email.contains('@');
  String get displayName => '$name ($email)';
}

// UI State extension: UI-only logic (NO errorMessage)
extension UserUIStateX on UserUIState {
  bool get canSave => selectedUser?.isNameValid ?? false;
}

// Widget-specific extension: Use _ prefix
extension _UserListX on User {
  Color get statusColor => isNameValid ? Colors.green : Colors.red;
  IconData get statusIcon => isNameValid ? Icons.check : Icons.error;
}
```

## Performance Optimization

### Select vs Watch

```dart
// ✅ GOOD: Select single field (rebuilds only when isLoading changes)
final isLoading = ref.watch(
  userNotifierProvider.select((s) => s.isLoading),
);

// ✅ GOOD: Watch entire state when using 3+ fields
final state = ref.watch(userNotifierProvider);
if (state.isLoading) return LoadingWidget();
if (state.hasError) return ErrorWidget();
return UserList(state.users);

// ❌ BAD: Select 3+ fields separately (more rebuilds)
final isLoading = ref.watch(userNotifierProvider.select((s) => s.isLoading));
final hasError = ref.watch(userNotifierProvider.select((s) => s.hasError));
final users = ref.watch(userNotifierProvider.select((s) => s.users));
```

### Memoization

```dart
// ✅ GOOD: Memoize expensive computations
extension UserStateX on UserState {
  List<User> get validUsers => users.where((u) => u.isNameValid).toList();

  // Expensive computation
  Map<String, List<User>> get usersByDomain {
    return users.fold<Map<String, List<User>>>({}, (map, user) {
      final domain = user.email.split('@').last;
      map.putIfAbsent(domain, () => []).add(user);
      return map;
    });
  }
}

// In UI: Cache the result
final usersByDomain = useMemoized(
  () => state.usersByDomain,
  [state.users],  // Recompute only when users change
);
```

## Common Mistakes

### ❌ Don't Mix AsyncValue and State

```dart
// ❌ BAD: AsyncValue inside State
@freezed
class UserState with _$UserState {
  const factory UserState({
    AsyncValue<List<User>>? users,  // ❌ Don't wrap AsyncValue
  }) = _UserState;
}

// ✅ GOOD: Use AsyncNotifier directly
@riverpod
class UserList extends _$UserList {
  @override
  FutureOr<List<User>> build() async {
    return ref.read(getUsersUseCaseProvider)();
  }
}
```

### ❌ Don't Use errorMessage in State

```dart
// ❌ BAD: Manual error handling
@freezed
class UserState with _$UserState {
  const factory UserState({
    @Default([]) List<User> users,
    @Default(false) bool isLoading,
    String? errorMessage,  // ❌ AsyncValue should manage this
  }) = _UserState;
}

// ✅ GOOD: AsyncValue manages errors
@riverpod
class UserList extends _$UserList {
  @override
  FutureOr<List<User>> build() async {
    return ref.read(getUsersUseCaseProvider)();  // Errors auto-handled as AsyncValue.error
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(getUsersUseCaseProvider)(),
    );
  }
}
```

### ❌ Don't Use Null for Empty Lists

```dart
// ❌ BAD: Null for empty state
@Default(null) List<User>? users

// ✅ GOOD: Empty list as default
@Default([]) List<User> users

// ✅ GOOD: Null only for "not loaded yet"
User? selectedUser  // null = nothing selected
```

### ❌ Don't Create Presentation Models

```dart
// ❌ BAD: Presentation model wrapping entity
class UserPresentation {
  final User entity;
  final bool isSelected;
  UserPresentation(this.entity, this.isSelected);
}

@freezed
class UserState with _$UserState {
  const factory UserState({
    @Default([]) List<UserPresentation> users,  // ❌ Presentation model
  }) = _UserState;
}

// ✅ GOOD: Domain entity + UI state separately
@freezed
class UserState with _$UserState {
  const factory UserState({
    @Default([]) List<User> users,  // ✅ Domain entity
    @Default({}) Set<String> selectedUserIds,  // ✅ UI state
  }) = _UserState;
}

extension UserStateX on UserState {
  bool isSelected(User user) => selectedUserIds.contains(user.id);
}
```

## Summary

**Recommended Patterns:**
1. **Entity Provider**: `AsyncNotifier` + `FutureOr<T> build()` → Data + auto loading/error management
2. **UI State Provider**: `Notifier` + `State build()` → UI-only state (selection, editing, etc.)
3. **Error Handling**: `AsyncValue.guard()` + `asyncValue.when()` → **No errorMessage field**
4. **i18n**: Call `error.toMessage(context)` in UI

**Key Rules:**
- ❌ No `errorMessage` field in State
- ❌ No `isLoading` field in State (AsyncValue manages this)
- ✅ Use AsyncValue.when() for loading/error/data handling
- ✅ Separate Entity Provider and UI State Provider

For detailed error handling patterns: [UNIFIED_ERROR_GUIDE.md](./UNIFIED_ERROR_GUIDE.md)
