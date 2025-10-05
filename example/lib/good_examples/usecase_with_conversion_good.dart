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

class TodoNotFoundException implements Exception {
  final String message;
  TodoNotFoundException(this.message);
}

abstract class TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id);
  Future<Result<List<Todo>, TodoFailure>> getTodos();
}

// ✅ GOOD: Using .toException() to convert Failure
class GetTodoUseCase {
  final TodoRepository repository;

  GetTodoUseCase(this.repository);

  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);

    // ✅ Properly converts Failure to Domain Exception
    return result.when(
      success: (todo) => todo,
      failure: (error) => throw error.toException(), // ✅
    );
  }
}

// ✅ GOOD: Multiple Result.when() with proper conversion
class GetTodosUseCase {
  final TodoRepository repository;

  GetTodosUseCase(this.repository);

  Future<List<Todo>> call() async {
    final result = await repository.getTodos();

    // ✅ Converts to Domain Exception
    return result.when(
      success: (todos) => todos,
      failure: (error) => throw error.toException(),
    );
  }

  Future<Todo> getTodo(String id) async {
    final result = await repository.getTodo(id);

    // ✅ Another proper conversion
    return result.when(
      success: (todo) => todo,
      failure: (error) => throw error.toException(),
    );
  }
}

// ✅ GOOD: Block function body with .toException()
class GetTodoWithValidationUseCase {
  final TodoRepository repository;

  GetTodoWithValidationUseCase(this.repository);

  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);

    // ✅ Block body with proper conversion
    return result.when(
      success: (data) => data,
      failure: (error) {
        // ✅ Properly converts to Exception
        throw error.toException();
      },
    );
  }
}

// ✅ GOOD: Multiple operations with conversion
class TodoUseCases {
  final TodoRepository repository;

  TodoUseCases(this.repository);

  Future<Todo> getTodo(String id) async {
    final result = await repository.getTodo(id);

    // ✅ Conversion
    return result.when(
      success: (todo) => todo,
      failure: (error) => throw error.toException(),
    );
  }

  Future<List<Todo>> getAllTodos() async {
    final result = await repository.getTodos();

    // ✅ Conversion
    return result.when(
      success: (todos) => todos,
      failure: (error) => throw error.toException(),
    );
  }

  Future<List<Todo>> getCompletedTodos() async {
    final result = await repository.getTodos();

    final todos = result.when<List<Todo>>(
      success: (data) => data,
      failure: (error) => throw error.toException(), // ✅
    );

    return todos.where((t) => t.title.contains('done')).toList();
  }
}
