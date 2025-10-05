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

// ❌ BAD: Throwing Failure directly without .toException()
// This will trigger: usecase_must_convert_failure
class GetTodoUseCaseBad1 {
  final TodoRepository repository;

  GetTodoUseCaseBad1(this.repository);

  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);

    // ❌ Should use .toException() to convert Failure to Domain Exception
    return result.when(
      success: (todo) => todo,
      failure: (error) => throw error, // ❌ Missing .toException()
    );
  }
}

// ❌ BAD: Returning Failure instead of throwing Exception
class GetTodoUseCaseBad2 {
  final TodoRepository repository;

  GetTodoUseCaseBad2(this.repository);

  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);

    // ❌ Should throw exception, not return Failure
    return result.when<Todo>(
      success: (data) => data,
      failure: (error) => error, // ❌ Should throw
    );
  }
}

// ❌ BAD: Multiple Result.when() without conversion
class GetTodosUseCaseBad {
  final TodoRepository repository;

  GetTodosUseCaseBad(this.repository);

  Future<List<Todo>> call() async {
    final result = await repository.getTodos();

    // ❌ No .toException() conversion
    return result.when(
      success: (todos) => todos,
      failure: (error) => throw error, // ❌
    );
  }

  Future<Todo> getTodo(String id) async {
    final result = await repository.getTodo(id);

    // ❌ Another missing conversion
    return result.when(
      success: (todo) => todo,
      failure: (error) => throw error, // ❌
    );
  }
}

// ❌ BAD: Block function body without conversion
class GetTodoUseCaseBad3 {
  final TodoRepository repository;

  GetTodoUseCaseBad3(this.repository);

  Future<Todo> call(String id) async {
    final result = await repository.getTodo(id);

    // ❌ Block body without .toException()
    return result.when(
      success: (data) => data,
      failure: (error) {
        // ❌ Should use error.toException()
        throw error;
      },
    );
  }
}
