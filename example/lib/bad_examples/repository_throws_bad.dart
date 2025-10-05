// ignore_for_file: unused_element, unused_field, unused_local_variable

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

// ❌ BAD: Repository throwing exceptions directly
// This will trigger: repository_no_throw
class TodoRepositoryImpl implements TodoRepository {
  final _TodoDataSource _dataSource = _TodoDataSource();

  @override
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    // ❌ Repository should NOT throw - should return Failure instead
    if (id.isEmpty) {
      throw ArgumentError('ID is required');
    }

    try {
      final todo = await _dataSource.getTodo(id);
      return Success(todo);
    } catch (e) {
      // ❌ Throwing in catch block (not rethrow)
      throw Exception('Failed to get todo: $e');
    }
  }

  @override
  Future<Result<List<Todo>, TodoFailure>> getTodos() async {
    final todos = await _dataSource.getTodos();

    if (todos.isEmpty) {
      // ❌ Direct throw
      throw StateError('No todos found');
    }

    return Success(todos);
  }
}

// ✅ ALLOWED: Private helper can throw (will be caught by public method)
class UserRepositoryImpl implements UserRepository {
  Future<Result<User, String>> getUser(String id) async {
    try {
      final user = _fetchUser(id); // ✅ Private method can throw
      return Success(user);
    } catch (e) {
      return Failure('Error: $e');
    }
  }

  // ✅ OK: Private helper method can throw
  User _fetchUser(String id) {
    if (id.isEmpty) {
      throw ArgumentError('Invalid ID'); // ✅ Will be caught by public method
    }
    return User(id);
  }
}

abstract class UserRepository {
  Future<Result<User, String>> getUser(String id);
}

class User {
  final String id;
  User(this.id);
}

class _TodoDataSource {
  Future<Todo> getTodo(String id) async => Todo(id: id, title: 'Test');
  Future<List<Todo>> getTodos() async => [];
}
