// ignore_for_file: unused_element

import 'dart:async';

// Mock types
class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

// Result types
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

  factory TodoFailure.notFound(String message) => TodoFailure(message);
  factory TodoFailure.network(String message) => TodoFailure(message);
}

// Data layer exceptions
class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

abstract class TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id);
  Future<Result<List<Todo>, TodoFailure>> getTodos();
  Future<void> deleteTodo(String id); // void is OK
}

// ✅ GOOD: Repository returning Result
class TodoRepositoryImpl implements TodoRepository {
  final _TodoDataSource _dataSource = _TodoDataSource();

  // ✅ Returns Result, catches exceptions
  @override
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    try {
      final todo = await _dataSource.getTodo(id);
      return Success(todo);
    } on NotFoundException catch (e) {
      return Failure(TodoFailure.notFound(e.message));
    } on NetworkException catch (e) {
      return Failure(TodoFailure.network(e.message));
    } catch (e) {
      return Failure(TodoFailure('Unknown error: $e'));
    }
  }

  // ✅ Returns Result for list operations
  @override
  Future<Result<List<Todo>, TodoFailure>> getTodos() async {
    try {
      final todos = await _dataSource.getTodos();
      return Success(todos);
    } on NetworkException catch (e) {
      return Failure(TodoFailure.network(e.message));
    } catch (e) {
      return Failure(TodoFailure('Error loading todos: $e'));
    }
  }

  // ✅ void methods are allowed (no error to handle)
  @override
  Future<void> deleteTodo(String id) async {
    await _dataSource.deleteTodo(id);
  }
}

// ✅ Using Either is also acceptable
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

class UserRepositoryImpl implements UserRepository {
  final _UserApi _api = _UserApi();

  // ✅ Either is also a valid Result type
  Future<Either<TodoFailure, User>> getUser(String id) async {
    try {
      final user = await _api.getUser(id);
      return Right(user);
    } on NotFoundException catch (e) {
      return Left(TodoFailure(e.message));
    } catch (e) {
      return Left(TodoFailure('Error: $e'));
    }
  }
}

abstract class UserRepository {
  Future<Either<TodoFailure, User>> getUser(String id);
}

class User {
  final String id;
  User(this.id);
}

// Mock DataSource
class _TodoDataSource {
  Future<Todo> getTodo(String id) async {
    if (id == 'not_found') {
      throw NotFoundException('Todo not found: $id');
    }
    return Todo(id: id, title: 'Test');
  }

  Future<List<Todo>> getTodos() async => [];

  Future<void> deleteTodo(String id) async {}
}

class _UserApi {
  Future<User> getUser(String id) async => User(id);
}
