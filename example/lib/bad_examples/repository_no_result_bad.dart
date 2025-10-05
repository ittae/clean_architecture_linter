// ignore_for_file: unused_element

import 'dart:async';

// Mock types
class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

abstract class TodoRepository {
  Future<Todo> getTodo(String id);
  Future<List<Todo>> getTodos();
}

class NotFoundException implements Exception {}

// ❌ BAD: Repository NOT returning Result
// This will trigger: repository_must_return_result
class TodoRepositoryImpl implements TodoRepository {
  // ❌ Repository should return Result<Todo, TodoFailure>
  @override
  Future<Todo> getTodo(String id) async {
    // Missing error handling - should catch and convert to Result
    final todo = await _dataSource.getTodo(id);
    return todo;
  }

  // ❌ Repository should return Result<List<Todo>, TodoFailure>
  @override
  Future<List<Todo>> getTodos() async {
    return await _dataSource.getTodos();
  }

  final _TodoDataSource _dataSource = _TodoDataSource();
}

// ❌ Another bad pattern - direct Entity return
class UserRepositoryImpl implements UserRepository {
  // ❌ Should return Result
  Future<User> getUser(String id) async {
    try {
      return await _api.getUser(id);
    } catch (e) {
      rethrow; // ❌ Repository shouldn't throw
    }
  }

  final _UserApi _api = _UserApi();
}

abstract class UserRepository {
  Future<User> getUser(String id);
}

class User {
  final String id;
  User(this.id);
}

class _TodoDataSource {
  Future<Todo> getTodo(String id) async {
    throw NotFoundException();
  }

  Future<List<Todo>> getTodos() async => [];
}

class _UserApi {
  Future<User> getUser(String id) async => User(id);
}
