# Clean Architecture Guide

This guide provides best practices for implementing Clean Architecture in Flutter/Dart projects.

## Table of Contents

- [Layer Overview](#layer-overview)
- [Dependency Rules](#dependency-rules)
- [Layer-Specific Patterns](#layer-specific-patterns)
- [Data Flow](#data-flow)
- [Common Patterns](#common-patterns)
- [Examples](#examples)

## Layer Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation Layer (UI)                                     │
│ • State Management (Riverpod with riverpod_generator)      │
│ • UI Components (Widgets, Pages, Screens)                  │
│ • View Models / UI State (Freezed)                         │
│ • Uses: Domain Entities                                     │
└─────────────────────────────────────────────────────────────┘
                           ↓ depends on
┌─────────────────────────────────────────────────────────────┐
│ Domain Layer (Business Logic)                               │
│ • Entities (Freezed)                                        │
│ • Use Cases (Business Rules)                                │
│ • Repository Interfaces (Abstractions)                      │
│ • Domain Services                                            │
└─────────────────────────────────────────────────────────────┘
                           ↑ implements
┌─────────────────────────────────────────────────────────────┐
│ Data Layer (External Data)                                  │
│ • Models (Freezed for JSON/DB)                              │
│ • Repository Implementations                                │
│ • Data Sources (Remote, Local, Cache)                       │
│ • API Clients                                                │
└─────────────────────────────────────────────────────────────┘
```

## Dependency Rules

### Golden Rule: Dependencies Point Inward

**Allowed Dependencies:**
- ✅ Presentation → Domain
- ✅ Data → Domain
- ✅ Presentation (internal dependencies)
- ✅ Data (internal dependencies)
- ✅ Domain (internal dependencies)

**Prohibited Dependencies:**
- ❌ Domain → Presentation
- ❌ Domain → Data
- ❌ Presentation → Data

### Import Rules

```dart
// ✅ GOOD: Presentation imports Domain
// presentation/widgets/todo_list.dart
import 'package:app/features/todos/domain/entities/todo.dart';

// ❌ BAD: Presentation imports Data
// presentation/widgets/todo_list.dart
import 'package:app/features/todos/data/models/todo_model.dart';

// ✅ GOOD: Data imports Domain
// data/repositories/todo_repository_impl.dart
import 'package:app/features/todos/domain/entities/todo.dart';
import 'package:app/features/todos/domain/repositories/todo_repository.dart';

// ❌ BAD: Domain imports Data
// domain/usecases/get_todos.dart
import 'package:app/features/todos/data/models/todo_model.dart';
```

## Layer-Specific Patterns

### 1. Data Layer: Use Freezed Models

**Purpose**: Handle external data formats (JSON, Database, API responses)

**Key Pattern**: Freezed Model contains Entity + JSON fields + Extension methods

```dart
// data/models/todo_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/todo.dart';

part 'todo_model.freezed.dart';
part 'todo_model.g.dart';

@freezed
sealed class TodoModel with _$TodoModel {
  const factory TodoModel({
    required Todo entity,  // Contains Domain Entity
    // Only add fields here if you need API/DB metadata
    // Examples: etag, version, cachedAt, syncStatus, etc.
  }) = _TodoModel;

  // Convert JSON to Model (builds Entity inside)
  factory TodoModel.fromJson(Map<String, dynamic> json) {
    final entity = Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      isCompleted: json['is_completed'] as bool,
      dueDate: json['due_date'] != null
        ? DateTime.parse(json['due_date'] as String)
        : null,
      priority: TodoPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TodoPriority.medium,
      ),
    );

    return TodoModel(entity: entity);
  }

  // Convert Model to JSON (uses Entity data)
  Map<String, dynamic> toJson() => {
    'id': entity.id,
    'title': entity.title,
    'description': entity.description,
    'is_completed': entity.isCompleted,
    'due_date': entity.dueDate?.toIso8601String(),
    'priority': entity.priority.name,
  };
}

// Conversion extensions in the same file
extension TodoModelX on TodoModel {
  // Extract Domain Entity from Model
  Todo toEntity() => entity;
}

extension TodoToModelX on Todo {
  // Convert Domain Entity to Model
  TodoModel toModel() => TodoModel(entity: this);
}
```

**Example with Metadata (only if needed):**
```dart
// Only use this pattern if you have API/DB specific metadata
@freezed
sealed class UserModel with _$UserModel {
  const factory UserModel({
    required User entity,
    // API metadata
    String? etag,              // HTTP caching
    int? version,              // API version
    // DB metadata
    DateTime? cachedAt,        // Local cache time
    String? syncStatus,        // 'pending', 'synced', 'failed'
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final entity = User(
      id: json['id'],
      name: json['name'],
    );

    return UserModel(
      entity: entity,
      etag: json['_etag'],
      version: json['_version'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': entity.id,
    'name': entity.name,
    if (etag != null) '_etag': etag,
    if (version != null) '_version': version,
  };
}
```

**Data Source Example:**

```dart
// data/datasources/todo_remote_datasource.dart
abstract class TodoRemoteDataSource {
  Future<List<TodoModel>> getTodos();
  Future<TodoModel> createTodo(TodoModel model);
}

class TodoRemoteDataSourceImpl implements TodoRemoteDataSource {
  final http.Client client;

  TodoRemoteDataSourceImpl({required this.client});

  @override
  Future<List<TodoModel>> getTodos() async {
    final response = await client.get(Uri.parse('$baseUrl/todos'));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => TodoModel.fromJson(json)).toList();
    } else {
      throw ServerException();
    }
  }

  @override
  Future<TodoModel> createTodo(TodoModel model) async {
    final response = await client.post(
      Uri.parse('$baseUrl/todos'),
      body: json.encode(model.toJson()),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return TodoModel.fromJson(json.decode(response.body));
    } else {
      throw ServerException();
    }
  }
}
```

**Repository Implementation:**

```dart
// data/repositories/todo_repository_impl.dart
import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_remote_datasource.dart';
import '../models/todo_model.dart';

class TodoRepositoryImpl implements TodoRepository {
  final TodoRemoteDataSource remoteDataSource;

  TodoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Todo>> getTodos() async {
    // Get Models from data source
    final models = await remoteDataSource.getTodos();

    // Convert Models to Entities using extension
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Todo> createTodo(Todo todo) async {
    // Convert Entity to Model using extension
    final model = todo.toModel();

    // Send Model to data source
    final resultModel = await remoteDataSource.createTodo(model);

    // Convert back to Entity
    return resultModel.toEntity();
  }
}
```

### 2. Domain Layer: Use Freezed Entities

**Purpose**: Represent business objects independent of external systems

**Key Pattern**: Freezed Entity + Extension methods for business logic

```dart
// domain/entities/todo.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo.freezed.dart';
part 'todo.g.dart';

enum TodoPriority { low, medium, high }

@freezed
sealed class Todo with _$Todo {
  const factory Todo({
    required String id,
    required String title,
    String? description,
    required bool isCompleted,
    DateTime? dueDate,
    @Default(TodoPriority.medium) TodoPriority priority,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) =>
      _$TodoFromJson(json);
}

// Business logic extensions in the same file
extension TodoX on Todo {
  // Business calculations
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  bool get isPriority => priority == TodoPriority.high;

  int? get daysUntilDue {
    if (dueDate == null) return null;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  // Business validations
  bool get hasValidDueDate {
    if (dueDate == null) return true;
    return dueDate!.isAfter(DateTime.now());
  }

  bool get isUrgent => isPriority && !isCompleted && (daysUntilDue ?? 0) <= 3;

  // Business operations
  Todo markAsCompleted() => copyWith(isCompleted: true);

  Todo markAsIncomplete() => copyWith(isCompleted: false);

  Todo updatePriority(TodoPriority newPriority) =>
      copyWith(priority: newPriority);
}
```

**Repository Interface:**

```dart
// domain/repositories/todo_repository.dart
import '../entities/todo.dart';

abstract class TodoRepository {
  Future<List<Todo>> getTodos();
  Future<Todo> getTodoById(String id);
  Future<Todo> createTodo(Todo todo);
  Future<Todo> updateTodo(Todo todo);
  Future<void> deleteTodo(String id);
}
```

**Use Case:**

```dart
// domain/usecases/get_todos_usecase.dart
import '../entities/todo.dart';
import '../repositories/todo_repository.dart';

class GetTodosUseCase {
  final TodoRepository repository;

  GetTodosUseCase(this.repository);

  Future<List<Todo>> call({
    bool onlyIncomplete = false,
    bool onlyOverdue = false,
  }) async {
    final todos = await repository.getTodos();

    var result = todos;

    if (onlyIncomplete) {
      result = result.where((t) => !t.isCompleted).toList();
    }

    if (onlyOverdue) {
      // Use business logic from extension
      result = result.where((t) => t.isOverdue).toList();
    }

    return result;
  }
}
```

### 3. Presentation Layer: Use Riverpod + Freezed State (NO ViewModels)

**Purpose**: Manage UI state and user interactions

**Key Pattern**: Riverpod Generator + Freezed State + Extension methods for UI logic

**Important**: We use **State** pattern, NOT **ViewModel** pattern. ViewModels are from the old MVVM pattern with ChangeNotifier.

#### Why State, Not ViewModel?

| Aspect | ViewModel (Old Pattern) | State (Our Pattern) |
|--------|------------------------|---------------------|
| **Mutability** | Mutable state | Immutable state (Freezed) |
| **Separation** | Logic + Data mixed | State (data) + Notifier (logic) separated |
| **Pattern** | MVVM with ChangeNotifier | Riverpod State Management |
| **Updates** | `notifyListeners()` | `state = newState` |
| **Debugging** | Hard to track changes | Easy time-travel debugging |

```dart
// ❌ OLD: ViewModel Pattern (Don't use)
class TodoViewModel extends ChangeNotifier {
  List<Todo> todos = [];  // Mutable
  bool isLoading = false;

  void loadTodos() {
    isLoading = true;
    notifyListeners();  // Manual notification
  }
}

// ✅ NEW: AsyncNotifier Pattern (Use this)
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    // ✅ AsyncValue automatically manages loading/error/data
    final result = await ref.read(getTodosUseCaseProvider)();
    return result.when(
      success: (todos) => todos,
      failure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// Widget uses AsyncValue.when()
final todosAsync = ref.watch(todoListProvider);
todosAsync.when(
  loading: () => CircularProgressIndicator(),
  error: (e, s) => ErrorWidget(e),
  data: (todos) => TodoList(todos),
);
```

#### Riverpod State Management with 3-Tier Architecture

This package enforces a **3-tier provider architecture** for proper separation of concerns:

1. **Tier 1: Entity Providers** - AsyncNotifier for domain data (loading/error/data auto-managed)
2. **Tier 2: UI State Providers** - Notifier for UI-only state (depends on Entity Providers)
3. **Tier 3: Computed Logic Providers** - Functions combining Entity + UI state

**Tier 1: Entity Provider (AsyncNotifier)**

```dart
// presentation/providers/todo_list_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/todo.dart';
import '../../domain/usecases/get_todos_usecase.dart';

part 'todo_list_provider.g.dart';

/// Entity Provider: Manages Todo list data
@riverpod
class TodoList extends _$TodoList {
  @override
  Future<List<Todo>> build() async {
    // ✅ AsyncNotifier automatically manages loading/error/data states
    final result = await ref.read(getTodosUseCaseProvider)();

    return result.when(
      success: (todos) => todos,
      failure: (failure) => throw failure,  // ✅ Auto converted to AsyncValue.error
    );
  }

  Future<void> toggleTodoComplete(String todoId) async {
    final currentTodos = state.value;
    if (currentTodos == null) return;

    final todo = currentTodos.firstWhere((t) => t.id == todoId);
    final updated = todo.isCompleted
        ? todo.markAsIncomplete()
        : todo.markAsCompleted();

    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await ref.read(updateTodoUseCaseProvider)(updated);
      final result = await ref.read(getTodosUseCaseProvider)();

      return result.when(
        success: (todos) => todos,
        failure: (failure) => throw failure,
      );
    });
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

/// Entity UI Extensions (formatting only)
extension TodoUIX on Todo {
  String get formattedDueDate => dueDate != null
      ? DateFormat('MMM dd').format(dueDate!)
      : 'No due date';

  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (isOverdue) return Colors.red;
    return Colors.grey;
  }

  IconData get statusIcon {
    if (isCompleted) return Icons.check_circle;
    if (isOverdue) return Icons.warning;
    return Icons.circle_outlined;
  }

  List<Todo> filterCompleted(List<Todo> todos) =>
      todos.where((t) => t.isCompleted).toList();

  List<Todo> filterIncomplete(List<Todo> todos) =>
      todos.where((t) => !t.isCompleted).toList();

  List<Todo> filterOverdue(List<Todo> todos) =>
      todos.where((t) => t.isOverdue).toList();
}
```

**Tier 2: UI State Provider (depends on Entity Provider)**

```dart
// presentation/providers/todo_ui_provider.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'todo_list_provider.dart';

part 'todo_ui_provider.freezed.dart';
part 'todo_ui_provider.g.dart';

/// UI State (Freezed) - UI-only state
@freezed
sealed class TodoUIState with _$TodoUIState {
  const factory TodoUIState({
    @Default(null) String? selectedTodoId,
    @Default(false) bool isEditDialogOpen,
    @Default(TodoFilter.all) TodoFilter activeFilter,
  }) = _TodoUIState;
}

extension TodoUIStateX on TodoUIState {
  bool isSelected(String id) => selectedTodoId == id;
}

enum TodoFilter { all, completed, incomplete, overdue }

/// UI State Provider (depends on Entity Provider)
@riverpod
class TodoUI extends _$TodoUI {
  @override
  TodoUIState build() {
    // ✅ Listen to entity changes
    ref.listen(
      todoListProvider,
      (previous, next) {
        // Clear selection when todos change
        next.whenData((_) {
          state = state.copyWith(selectedTodoId: null);
        });
      },
    );

    return const TodoUIState();
  }

  void selectTodo(String todoId) {
    state = state.copyWith(selectedTodoId: todoId);
  }

  void clearSelection() {
    state = state.copyWith(selectedTodoId: null);
  }

  void setFilter(TodoFilter filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void openEditDialog() {
    state = state.copyWith(isEditDialogOpen: true);
  }

  void closeEditDialog() {
    state = state.copyWith(isEditDialogOpen: false);
  }
}
```

**Tier 3: Computed Logic Providers (Entity + UI combination)**

```dart
// presentation/providers/todo_computed_providers.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/todo.dart';
import 'todo_list_provider.dart';
import 'todo_ui_provider.dart';

part 'todo_computed_providers.g.dart';

/// Filtered todos based on active filter
@riverpod
List<Todo> filteredTodos(FilteredTodosRef ref) {
  final todosAsync = ref.watch(todoListProvider);
  final uiState = ref.watch(todoUIProvider);

  return todosAsync.when(
    data: (todos) {
      switch (uiState.activeFilter) {
        case TodoFilter.completed:
          return todos.where((t) => t.isCompleted).toList();
        case TodoFilter.incomplete:
          return todos.where((t) => !t.isCompleted).toList();
        case TodoFilter.overdue:
          return todos.where((t) => t.isOverdue).toList();
        case TodoFilter.all:
        default:
          return todos;
      }
    },
    loading: () => [],
    error: (_, __) => [],
  );
}

/// Selected todo (combines entity + UI state)
@riverpod
Todo? selectedTodo(SelectedTodoRef ref) {
  final todosAsync = ref.watch(todoListProvider);
  final uiState = ref.watch(todoUIProvider);

  if (uiState.selectedTodoId == null) return null;

  return todosAsync.when(
    data: (todos) => todos.cast<Todo?>().firstWhere(
      (t) => t?.id == uiState.selectedTodoId,
      orElse: () => null,
    ),
    loading: () => null,
    error: (_, __) => null,
  );
}

/// Completion statistics
@riverpod
TodoStats todoStats(TodoStatsRef ref) {
  final todosAsync = ref.watch(todoListProvider);

  return todosAsync.when(
    data: (todos) {
      final completed = todos.where((t) => t.isCompleted).length;
      final total = todos.length;
      final rate = total == 0 ? 0.0 : completed / total;

      return TodoStats(
        total: total,
        completed: completed,
        incomplete: total - completed,
        completionRate: rate,
      );
    },
    loading: () => const TodoStats(),
    error: (_, __) => const TodoStats(),
  );
}

class TodoStats {
  final int total;
  final int completed;
  final int incomplete;
  final double completionRate;

  const TodoStats({
    this.total = 0,
    this.completed = 0,
    this.incomplete = 0,
    this.completionRate = 0.0,
  });
}
```

**Widget (using AsyncValue.when pattern):**

```dart
// presentation/widgets/todo_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_list_provider.dart';
import '../providers/todo_ui_provider.dart';
import '../providers/todo_computed_providers.dart';

class TodoList extends ConsumerWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ Watch Entity Provider (AsyncValue)
    final todosAsync = ref.watch(todoListProvider);

    // ✅ Watch UI State Provider
    final uiState = ref.watch(todoUIProvider);
    final uiNotifier = ref.read(todoUIProvider.notifier);

    // ✅ Watch Computed Providers
    final filteredTodos = ref.watch(filteredTodosProvider);
    final stats = ref.watch(todoStatsProvider);
    final selectedTodo = ref.watch(selectedTodoProvider);

    // ✅ AsyncValue.when() pattern for loading/error/data
    return todosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),

      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(todoListProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),

      data: (todos) {  // ✅ todos is non-nullable here
        return Column(
          children: [
            // ✅ Statistics from computed provider
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Completion: ${(stats.completionRate * 100).toStringAsFixed(1)}%'),
                    Text('${stats.completed} / ${stats.total} completed'),
                  ],
                ),
              ),
            ),

            // ✅ Filter buttons
            SegmentedButton<TodoFilter>(
              selected: {uiState.activeFilter},
              onSelectionChanged: (filters) {
                uiNotifier.setFilter(filters.first);
              },
              segments: const [
                ButtonSegment(value: TodoFilter.all, label: Text('All')),
                ButtonSegment(value: TodoFilter.completed, label: Text('Completed')),
                ButtonSegment(value: TodoFilter.incomplete, label: Text('Active')),
                ButtonSegment(value: TodoFilter.overdue, label: Text('Overdue')),
              ],
            ),

            // ✅ Todo list (filtered)
            Expanded(
              child: ListView.builder(
                itemCount: filteredTodos.length,
                itemBuilder: (context, index) {
                  final todo = filteredTodos[index];
                  final isSelected = uiState.isSelected(todo.id);

                  return ListTile(
                    // ✅ Entity UI Extensions
                    leading: Icon(todo.statusIcon, color: todo.statusColor),
                    title: Text(todo.title),
                    subtitle: Text(todo.formattedDueDate),
                    selected: isSelected,
                    onTap: () => uiNotifier.selectTodo(todo.id),
                    trailing: Checkbox(
                      value: todo.isCompleted,
                      onChanged: (_) {
                        ref.read(todoListProvider.notifier)
                            .toggleTodoComplete(todo.id);
                      },
                    ),
                  );
                },
              ),
            ),

            // ✅ Selected todo detail
            if (selectedTodo != null)
              Card(
                child: ListTile(
                  title: Text('Selected: ${selectedTodo.title}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: uiNotifier.clearSelection,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
```

## Data Flow

### Complete Flow Example

```
User Action (Tap Button)
         ↓
[Presentation] Widget calls Notifier method
         ↓
[Presentation] Notifier calls UseCase
         ↓
[Domain] UseCase calls Repository Interface
         ↓
[Data] Repository Implementation calls DataSource
         ↓
[Data] DataSource fetches JSON from API
         ↓
[Data] DataSource converts JSON → Model (Freezed)
         ↓
[Data] Repository converts Model → Entity (Extension)
         ↓
[Domain] UseCase applies business logic to Entities
         ↓
[Presentation] Notifier updates State (Freezed) with Entities
         ↓
[Presentation] Widget rebuilds with new State
         ↓
User sees updated UI
```

### Code Flow Example

```dart
// 1. User taps button in Widget
ElevatedButton(
  onPressed: () {
    // 2. Call Notifier method
    ref.read(todoNotifierProvider.notifier).loadTodos();
  },
)

// 3. Notifier calls UseCase
Future<void> loadTodos(...) async {
  final todos = await getTodosUseCase();  // Domain Entity
  state = state.copyWith(todos: todos);   // Update Freezed State
}

// 4. UseCase calls Repository
Future<List<Todo>> call() async {
  return await repository.getTodos();  // Domain Entity
}

// 5. Repository calls DataSource
Future<List<Todo>> getTodos() async {
  final models = await remoteDataSource.getTodos();     // Freezed Model
  return models.map((m) => m.toEntity()).toList();      // Extension conversion
}

// 6. DataSource fetches from API
Future<List<TodoModel>> getTodos() async {
  final response = await client.get(...);
  final json = jsonDecode(response.body);
  return json.map((j) => TodoModel.fromJson(j)).toList();  // Freezed fromJson
}

// 7. Widget rebuilds with new state
final state = ref.watch(todoNotifierProvider);  // Freezed State
return Text('Count: ${state.todos.length}');    // Use Entity
```

## Common Patterns

> 📖 **See above** for comprehensive Riverpod State Management patterns with 3-tier architecture (Entity Providers → UI State Providers → Computed Logic Providers).

### Quick Reference: Entity UI Extensions

When you need UI formatting or display logic, add extensions to entities:

```dart
// presentation/providers/todo_providers.dart (or in State file)

/// Entity UI Extensions (formatting only - no business logic)
extension TodoUIX on Todo {
  String get formattedDueDate => dueDate != null
      ? DateFormat('MMM dd').format(dueDate!)
      : 'No due date';

  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (isOverdue) return Colors.red;
    if (isPriority) return Colors.orange;
    return Colors.grey;
  }

  IconData get statusIcon {
    if (isCompleted) return Icons.check_circle;
    if (isOverdue) return Icons.warning;
    return Icons.circle_outlined;
  }

  String get statusLabel {
    if (isCompleted) return 'Completed';
    if (isOverdue) return 'Overdue';
    if (daysUntilDue != null && daysUntilDue! <= 3) return 'Due soon';
    return 'Active';
  }
}

// Widget-specific extensions (private, widget-only)
extension _TodoCardX on Todo {
  EdgeInsets get cardPadding => isPriority
      ? EdgeInsets.all(16.0)
      : EdgeInsets.all(8.0);

  double get cardElevation => isOverdue ? 4.0 : 1.0;
}
```

### Key Principles

1. **NO** manual `isLoading` or `errorMessage` fields - Use AsyncValue
2. **NO** Presentation Models - Use Entity Providers + UI State Providers
3. **NO** ViewModels - Use AsyncNotifier + Notifier
4. **Entity Extensions**: UI formatting/display only, no business logic
5. **State Extensions**: Computed properties combining UI state
6. **Computed Providers**: Derived values from Entity + UI State

## Examples

### Complete Feature Structure

```
lib/features/todos/
├── data/
│   ├── datasources/
│   │   ├── todo_local_datasource.dart
│   │   └── todo_remote_datasource.dart
│   ├── models/
│   │   └── todo_model.dart              # Freezed Model + conversion extensions (in same file)
│   └── repositories/
│       └── todo_repository_impl.dart
├── domain/
│   ├── entities/
│   │   └── todo.dart                    # Freezed Entity + business logic extensions (in same file)
│   ├── repositories/
│   │   └── todo_repository.dart
│   └── usecases/
│       ├── get_todos_usecase.dart
│       ├── create_todo_usecase.dart
│       └── delete_todo_usecase.dart
└── presentation/
    ├── providers/
    │   └── todo_provider.dart           # riverpod_generator (Notifier)
    ├── states/
    │   └── todo_state.dart              # Freezed State + UI extensions (State & Entity UI extensions)
    ├── pages/
    │   └── todo_page.dart
    └── widgets/
        ├── todo_list.dart
        └── todo_card.dart               # Can include widget-specific extensions in same file
    # NOTE: No models/ directory - State uses Domain Entities directly
    # NOTE: No viewmodels/ directory - we use State pattern, not ViewModel pattern
    # NOTE: No ui/ or extensions/ directory - put UI extensions in state file or widget files
    # NOTE: Entity UI extensions go in todo_state.dart along with State extensions
```

### Decision Tree: Which Pattern to Use?

```
Need UI-specific data?
├─ Simple formatting/calculation on Entity?
│  └─ ✅ Use Extension Methods on Entity
│
├─ Complex UI state (selection, filters, sorting, validation)?
│  └─ ✅ Use Freezed State (contains Entities) + Extensions
│
├─ Just displaying entity data?
│  └─ ✅ Use Entity directly
│
└─ Need Presentation Model?
   └─ ❌ NO - Use State with Entities instead
```

**Key Decision**:
- **Entity UI Extension in State file**: For shared UI formatting/calculations (Colors, Icons, Text)
- **Entity UI Extension in Widget file**: For widget-specific formatting (only used in that widget)
- **State Extension**: For UI logic involving multiple Entities or UI-specific state
- **NO Presentation Models**: State already contains Entities + UI fields
- **NO separate ui/extensions/ directory**: Put Entity UI extensions in State file

## Best Practices

### DO ✅

- **Use Freezed Models in Data Layer** - Model contains Entity + API fields
- **Use Freezed Entities in Domain Layer** for business objects
- **Use Extensions for functions** - keep Freezed classes pure data
- **Write Extensions in the same file** - Model extensions in model file, Entity extensions in entity file
- **Use riverpod_generator** for state management providers
- **Use Freezed State in Presentation** for UI state management
- **Models contain Entities** - `TodoModel` has `entity` field
- **Extract Entities from Models** using `model.toEntity()` (returns `model.entity`)
- **Keep business logic** in Domain entity extensions (in entity file)
- **Keep shared UI logic** in Presentation State file (Entity UI extensions with State extensions)
- **Widget-specific extensions** go in the widget file itself (use private extension with `_`)

### DON'T ❌

- **Don't use Data Models in Presentation** layer - use Domain Entities
- **Don't use Data Models in Domain** layer
- **Don't create Presentation Models** - State contains Entities directly
- **Don't use ViewModels** - use State pattern with Riverpod instead
- **Don't use ChangeNotifier** - use Freezed State + Notifier instead
- **Don't put methods inside Freezed classes** - use extensions instead
- **Don't create separate ui/ or extensions/ directories** - put extensions in state/widget files
- **Don't put business logic** in Presentation layer
- **Don't put UI logic** in Domain layer
- **Don't mix layers** - respect dependency boundaries
- **Don't use Equatable** - use Freezed for value equality
- **Don't create presentation/models/ directory** - use states/ with Entities
- **Don't create presentation/viewmodels/ directory** - use states/ + providers/
- **Don't create domain/extensions/ directory** - put extensions in entity files
- **Don't create data/extensions/ directory** - put extensions in model files

### When in Doubt

- If it's about **external data format** (JSON, DB) → **Freezed Model** (Data Layer)
- If it's about **business rules** → **Freezed Entity + Extension** (Domain Layer)
- If it's about **UI state or formatting** → **Freezed State + Extension** (Presentation Layer)
- If it's **any function/method** → **Extension**, not inside Freezed class

## Summary

| Layer | What to Use | Purpose | Example |
|-------|-------------|---------|---------|
| **Data** | Freezed Models (contains Entity) + Extensions | JSON/DB serialization | `TodoModel.fromJson()`, `model.toEntity()` (returns `model.entity`) |
| **Domain** | Freezed Entities + Extensions | Business logic | `Todo`, `todo.isOverdue` |
| **Presentation** | Freezed State + riverpod_generator + Extensions | UI state & interactions | `TodoState`, `TodoNotifier` |

**Tech Stack:**
- **State Management**: Riverpod with `riverpod_generator`
- **Immutability**: Freezed for all data classes (Models, Entities, States)
- **Functions**: Extensions in the same file as the class
- **JSON**: Custom `fromJson`/`toJson` in Models
- **Model Structure**: Model contains Entity only (no duplicate fields unless metadata needed)

**Key Patterns:**

```dart
// 1. Data Model (minimal - just Entity)
@freezed
sealed class TodoModel with _$TodoModel {
  const factory TodoModel({
    required Todo entity,  // Domain Entity inside
    // No duplicate fields - use entity data in toJson()
  }) = _TodoModel;

  Map<String, dynamic> toJson() => {
    'id': entity.id,  // Access entity fields directly
    'title': entity.title,
    'is_completed': entity.isCompleted,
  };
}

// 2. Model with Metadata (only if needed)
@freezed
sealed class UserModel with _$UserModel {
  const factory UserModel({
    required User entity,
    String? etag,      // API metadata
    DateTime? cachedAt,  // DB metadata
  }) = _UserModel;
}

// 3. Extensions in same file
extension TodoModelX on TodoModel {
  Todo toEntity() => entity;
}
```

**Remember:**
- **Models contain Entities** (no duplicate data)
- **Extensions in same file** as the class
- **Riverpod for state management**
- **Metadata only when needed** (etag, version, cachedAt, etc.)
