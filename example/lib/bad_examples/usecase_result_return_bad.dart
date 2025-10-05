// ignore_for_file: unused_element

import 'dart:async';

// Mock types
class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

class Result<T, E> {}
class Success<T, E> extends Result<T, E> {
  final T value;
  Success(this.value);
}
class Failure<T, E> extends Result<T, E> {
  final E error;
  Failure(this.error);
}

class TodoFailure {}

abstract class TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id);
  Future<Result<List<Todo>, TodoFailure>> getTodos();
}

// ❌ BAD: UseCase returning Result type
// This will trigger: usecase_no_result_return
class GetTodoUseCase {
  final TodoRepository repository;

  GetTodoUseCase(this.repository);

  // ❌ UseCase should NOT return Result - should unwrap and return Todo
  Future<Result<Todo, TodoFailure>> call(String id) async {
    return await repository.getTodo(id); // Just passing through Result
  }
}

// ❌ BAD: Using Either
class Either<L, R> {}

class GetTodosUseCase {
  final TodoRepository repository;

  GetTodosUseCase(this.repository);

  // ❌ UseCase should NOT return Either
  Future<Either<TodoFailure, List<Todo>>> call() async {
    final result = await repository.getTodos();
    // Wrong - returning Result/Either directly
    return result as Either<TodoFailure, List<Todo>>;
  }
}

// ❌ BAD: Synchronous Result return
class ValidateTodoUseCase {
  // ❌ Should return bool or throw, not Result
  Result<bool, String> call(Todo todo) {
    if (todo.title.isEmpty) {
      return Failure('Title is required');
    }
    return Success(true);
  }
}
