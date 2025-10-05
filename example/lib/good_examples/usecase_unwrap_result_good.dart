// ignore_for_file: unused_element

import 'dart:async';

// Mock types
class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

class Result<T, E> {
  T when<T>({
    required T Function(dynamic) success,
    required T Function(dynamic) failure,
  }) =>
      throw UnimplementedError();
}

class TodoFailure {
  TodoNotFoundException toException() => TodoNotFoundException('Not found');
}

// Domain exceptions
class TodoNotFoundException implements Exception {
  final String message;
  TodoNotFoundException(this.message);
}

class TodoValidationException implements Exception {
  final String message;
  TodoValidationException(this.message);
}

abstract class TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id);
  Future<Result<List<Todo>, TodoFailure>> getTodos();
}

// ✅ GOOD: UseCase unwraps Result and returns Entity or throws
class GetTodoUseCase {
  final TodoRepository repository;

  GetTodoUseCase(this.repository);

  // ✅ Returns Todo, unwraps Result internally
  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);

    // ✅ Unwrap Result and throw domain exception on failure
    return result.when(
      success: (todo) => todo,
      failure: (error) => throw error.toException(),
    );
  }
}

// ✅ GOOD: UseCase returns List, handles errors
class GetTodosUseCase {
  final TodoRepository repository;

  GetTodosUseCase(this.repository);

  // ✅ Returns List<Todo> directly
  Future<List<Todo>> call({
    bool onlyCompleted = false,
  }) async {
    final result = await repository.getTodos();

    final todos = result.when<List<Todo>>(
      success: (data) => data,
      failure: (error) => throw error.toException(),
    );

    // Apply business logic after unwrapping
    if (onlyCompleted) {
      return todos.where((t) => t.title.contains('done')).toList();
    }

    return todos;
  }
}

// ✅ GOOD: Synchronous UseCase returns bool or throws
class ValidateTodoUseCase {
  // ✅ Returns bool, throws on validation error
  bool call(Todo todo) {
    if (todo.title.isEmpty) {
      throw TodoValidationException('Title is required');
    }

    if (todo.title.length < 3) {
      throw TodoValidationException('Title must be at least 3 characters');
    }

    return true;
  }
}

// ✅ GOOD: void UseCase for commands
class DeleteTodoUseCase {
  final TodoRepository repository;

  DeleteTodoUseCase(this.repository);

  // ✅ void is acceptable for command operations
  Future<void> call(String id) async {
    final result = await repository.getTodo(id);

    result.when(
      success: (todo) {
        // Delete logic
      },
      failure: (error) => throw error.toException(),
    );
  }
}

// ✅ GOOD: UseCase with multiple Repository calls
class GetTodoWithRelatedUseCase {
  final TodoRepository todoRepository;

  GetTodoWithRelatedUseCase(this.todoRepository);

  // ✅ Returns Entity, handles multiple Results
  Future<Todo> call(String id) async {
    // Get main todo
    final todoResult = await todoRepository.getTodo(id);
    final todo = todoResult.when(
      success: (data) => data,
      failure: (error) => throw error.toException(),
    );

    // Get related todos
    final relatedResult = await todoRepository.getTodos();
    final related = relatedResult.when(
      success: (data) => data,
      failure: (error) => <Todo>[], // Graceful fallback
    );

    // Business logic with both results
    return todo;
  }
}
