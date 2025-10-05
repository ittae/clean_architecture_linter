// ignore_for_file: unused_element

import 'dart:async';

// Mock types for example
class TodoModel {
  final String id;
  final String title;
  TodoModel({required this.id, required this.title});
}

class Result<T, E> {
  const Result();
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

class TodoFailure {
  final String message;
  const TodoFailure(this.message);
}

// ❌ BAD: DataSource returning Result type
// This will trigger: datasource_no_result_return
class TodoRemoteDataSource {
  // ❌ DataSource should NOT return Result
  Future<Result<TodoModel, TodoFailure>> getTodo(String id) async {
    // This is wrong - DataSource should throw exceptions instead
    try {
      // API call simulation
      return Success(TodoModel(id: id, title: 'Test'));
    } catch (e) {
      return Failure(TodoFailure('Error: $e'));
    }
  }

  // ❌ Another wrong pattern - returning Result synchronously
  Result<List<TodoModel>, TodoFailure> getTodos() {
    try {
      return Success([TodoModel(id: '1', title: 'Test')]);
    } catch (e) {
      return Failure(TodoFailure('Error: $e'));
    }
  }
}

// ❌ BAD: Using Either (same problem as Result)
class Either<L, R> {
  const Either();
}

class Left<L, R> extends Either<L, R> {
  final L value;
  const Left(this.value);
}

class Right<L, R> extends Either<L, R> {
  final R value;
  const Right(this.value);
}

class TodoLocalDataSource {
  // ❌ DataSource should NOT use Either
  Future<Either<TodoFailure, TodoModel>> getTodoById(String id) async {
    try {
      return Right(TodoModel(id: id, title: 'Local'));
    } catch (e) {
      return Left(TodoFailure('Error: $e'));
    }
  }

  // ❌ Nested in Future - still wrong
  Future<Either<String, List<TodoModel>>> getAllTodos() async {
    return Right([]);
  }
}
