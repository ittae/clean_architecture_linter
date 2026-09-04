# Presentation Layer Rules

This directory contains lint rules that enforce Clean Architecture principles **within the Presentation layer**.

## Presentation Layer Responsibilities

The Presentation layer contains:
- **Pages/Screens**: Top-level UI screens
- **Widgets**: Reusable UI components
- **States**: Freezed state classes for Riverpod
- **Notifiers**: Riverpod state management logic
- **UI Extensions**: Entity/State extensions for UI-specific logic

The Presentation layer must:
- ✅ Use **Freezed** for State classes (NO ViewModels or Presentation Models)
- ✅ Use **Riverpod Generator** (`@riverpod`) for state management
- ✅ Handle only **Domain exceptions** (NOT Data exceptions)
- ✅ Use **AsyncValue** for error handling (NOT error fields in State)
- ✅ Keep UI extensions **in the same file** as State classes
- ❌ Never import from Data layer directly

---

## Rules in this Category

### 1. No Presentation Models Rule (`no_presentation_models_rule.dart`)
**Purpose**: Enforces using Freezed State instead of Presentation Models or ViewModels.

**What it checks**:
- ❌ No classes ending in `ViewModel`, `PresentationModel`, or `Presenter`
- ✅ Use Freezed State classes with Riverpod instead

**Architecture**:
```
❌ OLD (Forbidden):
Presentation Model / ViewModel → separate UI logic class

✅ NEW (Required):
Freezed State + Riverpod Notifier + UI Extensions in same file
```

**Example**:
```dart
// ❌ BAD: Using ViewModel
class TodoViewModel {
  final List<Todo> todos;
  final bool isLoading;
}

// ✅ GOOD: Using 3-Tier Provider Architecture

// Tier 1: Entity Provider (AsyncNotifier)
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final result = await ref.read(getTodosUseCaseProvider)();
    return result.when(
      success: (todos) => todos,
      failure: (failure) => throw failure,
    );
  }
}

// Tier 2: UI State Provider (UI-only state)
@freezed
class TodoUIState with _$TodoUIState {
  const factory TodoUIState({
    @Default([]) List<String> selectedIds,
  }) = _TodoUIState;
}

@riverpod
class TodoUI extends _$TodoUI {
  @override
  TodoUIState build() {
    ref.watch(todoListProvider);
    return const TodoUIState();
  }
}

// Entity UI Extensions
extension TodoUIX on Todo {
  int get completedCount => isCompleted ? 1 : 0;
}
```

---

### 2. Extension Location Rule (`extension_location_rule.dart`)
**Purpose**: Enforces that extensions are defined in the same file as the class they extend.

**What it checks**:
- ✅ Extensions on Entities, Models, or States must be in the same file
- ❌ No separate `extensions/` directory
- ⚠️ Warns about extensions that might belong elsewhere

**Why**: Keeps related code together and prevents the need to hunt for extension definitions.

**Example**:
```dart
// ✅ GOOD: Extension in same file as State
// lib/features/todos/presentation/states/todo_state.dart

@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
  }) = _TodoState;
}

// UI-specific extensions in same file
extension TodoStateX on TodoState {
  int get completedCount => todos.where((t) => t.isCompleted).length;
  double get completionRate => todos.isEmpty ? 0.0 : completedCount / todos.length;
}

extension TodoUIX on Todo {
  String get formattedDueDate => dueDate != null
    ? DateFormat('MMM dd').format(dueDate!)
    : 'No due date';
}

// ❌ BAD: Extension in separate file
// lib/features/todos/presentation/extensions/todo_extensions.dart
extension TodoUIX on Todo { ... } // Should be in state file
```

---

### 3. Freezed Usage Rule (`freezed_usage_rule.dart`)
**Purpose**: Enforces using Freezed instead of Equatable for data classes.

**What it checks**:
- ✅ Use `@freezed` annotation for Models, Entities, and States
- ❌ Don't use `Equatable` package
- ✅ Freezed provides: immutability, copyWith, equality, JSON serialization

**Example**:
```dart
// ❌ BAD: Using Equatable
class TodoState extends Equatable {
  final List<Todo> todos;
  final bool isLoading;

  const TodoState({
    this.todos = const [],
    this.isLoading = false,
  });

  @override
  List<Object?> get props => [todos, isLoading];
}

// ✅ GOOD: Using Freezed (for UI State)
@freezed
class TodoUIState with _$TodoUIState {
  const factory TodoUIState({
    @Default([]) List<String> selectedIds,
    @Default(false) bool isEditMode,
  }) = _TodoUIState;
}

// Note: For entity data, use AsyncNotifier instead of storing in State
// See CLAUDE.md § Riverpod State Management Patterns
```

---

### 4. Riverpod Generator Rule (`riverpod_generator_rule.dart`)
**Purpose**: Enforces using Riverpod Generator (`@riverpod`) for state management.

**What it checks**:
- ✅ Use `@riverpod` annotation for Notifiers
- ❌ Don't use manual Provider definitions
- ✅ Riverpod Generator provides: type safety, code generation, auto-dispose

**Example**:
```dart
// ❌ BAD: Manual Provider definition
final todoNotifierProvider = StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  return TodoNotifier(ref.watch(todoRepositoryProvider));
});

// ✅ GOOD: Using @riverpod with AsyncNotifier
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final result = await ref.read(getTodosUseCaseProvider)();

    return result.when(
      success: (todos) => todos,
      failure: (failure) => throw failure,
    );
  }

  Future<void> addTodo(Todo todo) async {
    final result = await ref.read(createTodoUseCaseProvider)(todo);

    result.when(
      success: (_) => ref.invalidateSelf(),
      failure: (failure) => throw failure,
    );
  }
}

// See CLAUDE.md § Riverpod State Management Patterns for complete 3-tier architecture
```

---

### 5. Presentation No Data Exceptions Rule (`presentation_no_data_exceptions_rule.dart`)
**Purpose**: Ensures Presentation layer only handles Domain exceptions, not Data exceptions.

**What it checks**:
- ❌ Don't catch Data exceptions (`NotFoundException`, `NetworkException`, etc.)
- ✅ Only catch Domain exceptions (`TodoNotFoundException`, `TodoNetworkException`, etc.)

**Why**: Presentation should not know about Data layer implementation details. UseCases convert Data exceptions to Domain exceptions.

**Example**:
```dart
// ❌ BAD: Catching Data exceptions
Future<void> loadTodos() async {
  try {
    await getTodosUseCase();
  } on NotFoundException catch (e) { // ❌ Data exception
    // Handle error
  }
}

// ✅ GOOD: Catching Domain exceptions
Future<void> loadTodos() async {
  try {
    await getTodosUseCase();
  } on TodoNotFoundException catch (e) { // ✓ Domain exception
    // Handle error
  }
}

// ✅ BETTER: Using AsyncValue (no try-catch needed)
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    final result = await ref.read(getTodosUseCaseProvider)();
    // Riverpod automatically wraps exceptions in AsyncValue.error
    return result.when(
      success: (todos) => todos,
      failure: (failure) => throw failure,
    );
  }
}
```

---

### 6. Presentation Use AsyncValue Rule (`presentation_use_async_value_rule.dart`)
**Purpose**: Enforces using AsyncValue for error handling instead of error fields in State.

**What it checks**:
- ❌ Don't add error fields / loading flags to Freezed State classes
- ✅ Use Riverpod's `AsyncValue<T>` for error/loading handling
- ✅ Notifier/Provider `catch` must map the exception into UI state

**Error/loading field name matching** (exact, case-insensitive):
- ❌ Error (exact): `error`, `errorMessage`, `errorMsg`, `errorText`, `errorDescription`, `failure`, `failureMessage`, `exception`, `exceptionMessage`, `hasError`, `isError`, `lastError`, `lastErrorMessage`, `hasFailure`, `isFailure`, `lastFailure`, `lastFailureMessage`
- ❌ Loading (exact): `isLoading`, `loading`, `isSubmitting`, `submitting`, `isFetching`, `fetching`, `isProcessing`, `processing`
- ✅ Names that merely embed those words are allowed: `errorBoundaryEnabled`, `hasErrorPermission`
- Substring `contains` matching was removed to cut consumer FP noise

**Catch acceptance criteria** (AST-based):
- ✅ `AsyncValue.guard(...)` / `AsyncValue.error(...)` / `AsyncError(...)`
- ✅ `when(error: ...)` UI handler
- ✅ `state = ...` whose RHS uses a catch parameter (exception/stackTrace)
- ✅ `state = ...` whose RHS includes a `uiEffect:` named argument (partial failure: keep data, toast the error)
- ❌ Logging-only catch, empty catch, `state = AsyncValue.loading()`, or `state = AsyncData(latest)` without `uiEffect:` / catch param

**Example**:
```dart
// ❌ BAD: Error field in State
@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    String? errorMessage, // ❌ Don't store errors in State
  }) = _TodoState;
}

// ✅ GOOD: AsyncValue handles errors
@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    // No error field needed!
  }) = _TodoState;
}

@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  FutureOr<TodoState> build() async {
    // If this throws, Riverpod wraps it in AsyncValue.error
    final todos = await getTodosUseCase();
    return TodoState(todos: todos);
  }

  // ✅ GOOD: full failure → AsyncValue.error
  Future<void> reload() async {
    try {
      state = AsyncData(await fetch());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  // ✅ GOOD: partial failure → keep data, surface toast via uiEffect
  Future<void> deleteOne(String id) async {
    final latest = state.requireValue;
    try {
      await delete(id);
    } catch (error) {
      state = AsyncData(
        latest.copyWith(uiEffect: toastFor(error)),
      );
    }
  }
}

// UI automatically gets AsyncValue
class TodoPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(todoNotifierProvider);

    return asyncState.when(
      data: (state) => TodoList(todos: state.todos),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error), // ✓ Error handling
    );
  }
}
```

---

### 7. Riverpod Ref After Async Gap Rule (`riverpod_ref_after_async_gap_rule.dart`)
**Purpose**: Advises against accessing Riverpod `ref` after an async gap in provider/notifier methods. Unguarded `state` writes are handled by the opt-in rule 7b below.

**What it checks**:
- ❌ `ref.read`, `ref.watch`, `ref.listen`, `ref.invalidate`, `ref.refresh` after `await`
- ✅ Provider/usecase capture before `await`
- ✅ Post-gap access guarded by `if (!ref.mounted) return;` or `if (ref.mounted) { … }`
- ✅ Generated files, tests, non-provider files, and private helper methods are skipped

**Example**:
```dart
@riverpod
class TodoNotifier extends _$TodoNotifier {
  Future<void> refresh() async {
    final getTodos = ref.read(getTodosUseCaseProvider); // ✅ Capture before await
    await getTodos();
  }

  Future<void> unsafeRefresh() async {
    await saveTodo();
    ref.refresh(todoProvider); // ❌ ref access after async gap
  }
}
```

### 7b. Riverpod State After Async Gap Rule (`riverpod_state_after_async_gap_rule.dart`, opt-in)
**Purpose**: Advises against writing `state` after an async gap in provider/notifier methods. Riverpod 3 throws `UnmountedRefException` when `state` is written after disposal.

**Opt-in**: registered with `registerLintRule`, so it is off until enabled:

```yaml
plugins:
  clean_architecture_linter:
    diagnostics:
      riverpod_state_after_async_gap: true
```

**What it checks**:
- ❌ unguarded `state = …` / `this.state = …` after `await`
- ❌ same-statement `state = await …` (store runs after RHS await; a preceding `ref.mounted` guard does not protect it)
- ✅ Assignment guarded by `if (!ref.mounted) return;` or `if (ref.mounted) { … }`
- ✅ Generated files, tests, non-provider files, and private helper methods are skipped

**Example**:
```dart
@riverpod
class TodoNotifier extends _$TodoNotifier {
  Future<void> unsafeLoad() async {
    final todo = await fetchTodo();
    state = AsyncData(todo); // ❌ state write after async gap
  }

  Future<void> unsafeLoadRhsAwait() async {
    state = await fetchTodo(); // ❌ same-statement RHS await; split then guard
  }

  Future<void> safeLoad() async {
    final todo = await fetchTodo();
    if (!ref.mounted) return;
    state = AsyncData(todo); // ✅ disposal-guarded
  }
}
```

---

## Best Practices

1. **Use Freezed State**: NO ViewModels or Presentation Models
2. **Use Riverpod Generator**: `@riverpod` for type-safe state management
3. **Use AsyncValue**: Let Riverpod handle error states
4. **Keep Extensions Together**: UI extensions in same file as State
5. **Handle Domain Exceptions Only**: Never catch Data exceptions
6. **Capture Riverpod dependencies before await**: Avoid lifecycle-sensitive `ref` access after async gaps
7. **Test Notifiers**: State management logic should be tested

---

## Error Handling Architecture

```
Domain Exception (thrown by UseCase)
   ↓
Riverpod Notifier (throws exception in build/methods)
   ↓
AsyncValue.error (automatically wrapped by Riverpod)
   ↓
UI Widget (asyncValue.when displays error state)
```

---

## Testing

Presentation layer rules are tested in the example project:

```bash
# Analyze this package
dart analyze

# Run tests
dart test

# Test with example project
cd example && dart run custom_lint
```

---

## Related Documentation

- [Clean Architecture Guide](../../../../doc/CLEAN_ARCHITECTURE_GUIDE.md)
- [Error Handling Guide](../../../../doc/ERROR_HANDLING_GUIDE.md)
- [Cross-Layer Rules](../cross_layer/README.md)
- [Domain Layer Rules](../domain_rules/README.md)
- [Data Layer Rules](../data_rules/README.md)
