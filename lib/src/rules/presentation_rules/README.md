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

// ✅ GOOD: Using Freezed State
@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    @Default(false) bool isLoading,
  }) = _TodoState;
}

// State extensions in same file
extension TodoStateX on TodoState {
  int get completedCount => todos.where((t) => t.isCompleted).length;
}

// Riverpod Notifier
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  FutureOr<TodoState> build() async {
    return TodoState();
  }
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

// ✅ GOOD: Using Freezed
@freezed
class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    @Default(false) bool isLoading,
  }) = _TodoState;
}
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

// ✅ GOOD: Using @riverpod
@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  FutureOr<TodoState> build() async {
    final repository = ref.watch(todoRepositoryProvider);
    final result = await repository.getTodos();

    return result.when(
      success: (todos) => TodoState(todos: todos),
      failure: (failure) => throw failure.toException(),
    );
  }

  Future<void> addTodo(Todo todo) async {
    final repository = ref.read(todoRepositoryProvider);
    final result = await repository.createTodo(todo);

    result.when(
      success: (_) => ref.invalidateSelf(),
      failure: (failure) => throw failure.toException(),
    );
  }
}
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
class TodoNotifier extends _$TodoNotifier {
  @override
  FutureOr<TodoState> build() async {
    // Riverpod automatically wraps exceptions in AsyncValue.error
    return TodoState(todos: await getTodosUseCase());
  }
}
```

---

### 6. Presentation Use AsyncValue Rule (`presentation_use_async_value_rule.dart`)
**Purpose**: Enforces using AsyncValue for error handling instead of error fields in State.

**What it checks**:
- ❌ Don't add error fields to Freezed State classes
- ✅ Use Riverpod's `AsyncValue<T>` for error handling
- ✅ Let Riverpod automatically wrap exceptions in `AsyncValue.error`

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

## Best Practices

1. **Use Freezed State**: NO ViewModels or Presentation Models
2. **Use Riverpod Generator**: `@riverpod` for type-safe state management
3. **Use AsyncValue**: Let Riverpod handle error states
4. **Keep Extensions Together**: UI extensions in same file as State
5. **Handle Domain Exceptions Only**: Never catch Data exceptions
6. **Test Notifiers**: State management logic should be tested

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
