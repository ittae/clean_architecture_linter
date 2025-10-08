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

// ✅ NEW: State Pattern (Use this)
@freezed
sealed class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,  // Immutable
    @Default(false) bool isLoading,
  }) = _TodoState;
}

@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  TodoState build() => const TodoState();

  Future<void> loadTodos() async {
    state = state.copyWith(isLoading: true);  // Immutable update
  }
}
```

#### Riverpod with riverpod_generator

**State Class:**

```dart
// presentation/states/todo_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/todo.dart';

part 'todo_state.freezed.dart';

@freezed
sealed class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    @Default(null) String? selectedTodoId,
    @Default(false) bool isLoading,
    @Default(null) String? error,
  }) = _TodoState;
}

// UI logic extensions in the same file
extension TodoStateX on TodoState {
  List<Todo> get completedTodos =>
      todos.where((t) => t.isCompleted).toList();

  List<Todo> get incompleteTodos =>
      todos.where((t) => !t.isCompleted).toList();

  List<Todo> get overdueTodos =>
      todos.where((t) => t.isOverdue).toList();

  Todo? get selectedTodo =>
      todos.cast<Todo?>().firstWhere(
        (t) => t?.id == selectedTodoId,
        orElse: () => null,
      );

  int get totalCount => todos.length;

  int get completedCount => completedTodos.length;

  double get completionRate =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  bool isSelected(String id) => selectedTodoId == id;
}
```

**Notifier with riverpod_generator:**

```dart
// presentation/providers/todo_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/usecases/get_todos_usecase.dart';
import '../states/todo_state.dart';

part 'todo_provider.g.dart';

@riverpod
class TodoNotifier extends _$TodoNotifier {
  @override
  TodoState build() {
    return const TodoState();
  }

  Future<void> loadTodos({
    bool onlyIncomplete = false,
    bool onlyOverdue = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final getTodosUseCase = ref.read(getTodosUseCaseProvider);
      final todos = await getTodosUseCase(
        onlyIncomplete: onlyIncomplete,
        onlyOverdue: onlyOverdue,
      );
      state = state.copyWith(todos: todos, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void selectTodo(String todoId) {
    state = state.copyWith(selectedTodoId: todoId);
  }

  void clearSelection() {
    state = state.copyWith(selectedTodoId: null);
  }

  Future<void> toggleTodoComplete(String todoId) async {
    final todo = state.todos.firstWhere((t) => t.id == todoId);
    final updated = todo.isCompleted
        ? todo.markAsIncomplete()
        : todo.markAsCompleted();

    // Update in repository and refresh
    await ref.read(updateTodoUseCaseProvider)(updated);
    await loadTodos();
  }
}
```

**Widget:**

```dart
// presentation/widgets/todo_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/todo_provider.dart';
import '../states/todo_state.dart';

class TodoList extends ConsumerWidget {
  const TodoList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todoNotifierProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(child: Text('Error: ${state.error}'));
    }

    return Column(
      children: [
        // Use computed property from extension
        Text('Completion: ${(state.completionRate * 100).toStringAsFixed(1)}%'),
        Text('${state.completedCount} / ${state.totalCount} completed'),
        Expanded(
          child: ListView.builder(
            itemCount: state.todos.length,
            itemBuilder: (context, index) {
              final todo = state.todos[index];
              final isSelected = state.isSelected(todo.id);

              return TodoItem(
                todo: todo,
                isSelected: isSelected,
                onTap: () {
                  ref.read(todoNotifierProvider.notifier)
                      .selectTodo(todo.id);
                },
                onToggle: () {
                  ref.read(todoNotifierProvider.notifier)
                      .toggleTodoComplete(todo.id);
                },
              );
            },
          ),
        ),
      ],
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

### Pattern 1: UI-Specific Extensions on Entities

When you need UI formatting or calculations, add extensions in the **State file** or **Widget file**:

**Option A: In State file (recommended for shared UI logic)**
```dart
// presentation/states/todo_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/todo.dart';

part 'todo_state.freezed.dart';

@freezed
sealed class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,
    @Default(false) bool isLoading,
  }) = _TodoState;
}

// State extensions
extension TodoStateX on TodoState {
  int get totalCount => todos.length;
  double get completionRate =>
      totalCount == 0 ? 0.0 : completedTodos.length / totalCount;
}

// Entity UI extensions in the same file (shared across widgets)
extension TodoUIX on Todo {
  String get formattedDueDate {
    if (dueDate == null) return 'No due date';
    return DateFormat('MMM dd, yyyy').format(dueDate!);
  }

  Color get priorityColor {
    switch (priority) {
      case TodoPriority.high:
        return Colors.red;
      case TodoPriority.medium:
        return Colors.orange;
      case TodoPriority.low:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    if (isCompleted) return Icons.check_circle;
    if (isOverdue) return Icons.warning;  // Uses domain extension
    return Icons.circle_outlined;
  }

  String get statusLabel {
    if (isCompleted) return 'Completed';
    if (isOverdue) return 'Overdue';
    if (daysUntilDue != null && daysUntilDue! <= 3) return 'Due soon';
    return 'Active';
  }

  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (isOverdue) return Colors.red;
    if (isPriority) return Colors.orange;
    return Colors.grey;
  }
}
```

**Option B: In Widget file (for widget-specific logic only)**
```dart
// presentation/widgets/todo_card.dart
import 'package:flutter/material.dart';
import '../../domain/entities/todo.dart';
import '../states/todo_state.dart';  // Imports shared UI extensions

// Widget-specific extensions (only used in this widget)
extension _TodoCardX on Todo {
  EdgeInsets get cardPadding {
    return isPriority
      ? EdgeInsets.all(16.0)
      : EdgeInsets.all(8.0);
  }

  double get cardElevation {
    return isOverdue ? 4.0 : 1.0;
  }
}

class TodoCard extends StatelessWidget {
  final Todo todo;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: todo.cardElevation,  // Widget-specific extension
      child: Padding(
        padding: todo.cardPadding,
        child: Column(
          children: [
            Text(todo.formattedDueDate),  // Shared UI extension from state file
            Icon(todo.statusIcon, color: todo.statusColor),
            Text(todo.statusLabel),
          ],
        ),
      ),
    );
  }
}
```

### Pattern 2: Complex UI State (Freezed State + Extensions)

When you need to combine multiple entities or track complex UI state:

```dart
// presentation/states/todo_ui_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/todo.dart';

part 'todo_ui_state.freezed.dart';

enum TodoFilter { all, active, completed, overdue }
enum TodoSortOrder { byDueDate, byPriority, byTitle }

@freezed
sealed class TodoUIState with _$TodoUIState {
  const factory TodoUIState({
    @Default([]) List<Todo> todos,
    @Default({}) Set<String> selectedIds,
    @Default({}) Map<String, bool> expandedStates,
    @Default(TodoFilter.all) TodoFilter filter,
    @Default(TodoSortOrder.byDueDate) TodoSortOrder sortOrder,
  }) = _TodoUIState;
}

// Computed properties in extension
extension TodoUIStateX on TodoUIState {
  List<Todo> get filteredTodos {
    var result = todos;

    switch (filter) {
      case TodoFilter.active:
        result = result.where((t) => !t.isCompleted).toList();
        break;
      case TodoFilter.completed:
        result = result.where((t) => t.isCompleted).toList();
        break;
      case TodoFilter.overdue:
        result = result.where((t) => t.isOverdue).toList();
        break;
      default:
        break;
    }

    return _sortTodos(result);
  }

  List<Todo> get selectedTodos =>
      todos.where((t) => selectedIds.contains(t.id)).toList();

  int get totalSelectedCount => selectedIds.length;

  bool isSelected(String id) => selectedIds.contains(id);

  bool isExpanded(String id) => expandedStates[id] ?? false;

  List<Todo> _sortTodos(List<Todo> todos) {
    final sorted = List<Todo>.from(todos);
    switch (sortOrder) {
      case TodoSortOrder.byDueDate:
        sorted.sort((a, b) {
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case TodoSortOrder.byPriority:
        sorted.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        break;
      case TodoSortOrder.byTitle:
        sorted.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
    return sorted;
  }
}
```

### Pattern 3: UI-Specific State (Use State, Not Presentation Models)

When you need UI-specific data like selection or validation, use State classes that contain Entities:

```dart
// presentation/states/todo_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/todo.dart';

part 'todo_state.freezed.dart';

@freezed
sealed class TodoState with _$TodoState {
  const factory TodoState({
    @Default([]) List<Todo> todos,  // Domain Entities
    @Default({}) Set<String> selectedIds,  // UI state
    @Default({}) Map<String, String> validationErrors,  // UI validation
  }) = _TodoState;
}

// UI logic via extensions
extension TodoStateX on TodoState {
  List<Todo> get selectedTodos =>
      todos.where((t) => selectedIds.contains(t.id)).toList();

  bool isSelected(String id) => selectedIds.contains(id);

  String? validationError(String id) => validationErrors[id];

  bool canSelect(String id) => validationErrors[id] == null;

  // Computed UI properties using Entity extensions
  Color getStatusColor(Todo todo) {
    if (validationErrors[todo.id] != null) return Colors.red;
    if (isSelected(todo.id)) return Colors.blue;
    if (todo.isPriority) return Colors.orange;  // From Entity extension
    return Colors.grey;
  }
}

// Usage in Widget
final state = ref.watch(todoNotifierProvider);
final todo = state.todos[0];
final color = state.getStatusColor(todo);  // Use State extension
final label = todo.formattedDueDate;  // Use Entity extension
```

**Key Principle**: NO separate Presentation Models. State contains Entities + UI-specific fields.

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
