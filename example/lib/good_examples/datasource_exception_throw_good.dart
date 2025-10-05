// ignore_for_file: unused_element

import 'dart:async';

// Mock types for example
class TodoModel {
  final String id;
  final String title;
  TodoModel({required this.id, required this.title});
}

// Data Layer exceptions
class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
}

// ✅ GOOD: DataSource throws exceptions instead of returning Result
class TodoRemoteDataSource {
  // ✅ Returns data type directly, throws exception on error
  Future<TodoModel> getTodo(String id) async {
    // Simulate API call
    final response = await _apiCall(id);

    if (response == null) {
      // ✅ Throw exception instead of returning Result
      throw NotFoundException('Todo not found: $id');
    }

    if (response['status'] == 401) {
      throw UnauthorizedException('Access denied');
    }

    return TodoModel(
      id: response['id'] as String,
      title: response['title'] as String,
    );
  }

  // ✅ Returns list directly, throws on error
  Future<List<TodoModel>> getTodos() async {
    try {
      final response = await _apiCallList();
      return response
          .map((json) => TodoModel(
                id: json['id'] as String,
                title: json['title'] as String,
              ))
          .toList();
    } on SocketException {
      // ✅ Convert to domain exception
      throw NetworkException('Network connection failed');
    }
  }

  // ✅ Synchronous method - throws exception
  TodoModel getTodoSync(String id) {
    final cached = _cache[id];
    if (cached == null) {
      throw NotFoundException('Todo not in cache: $id');
    }
    return cached;
  }

  // Mock implementations
  final Map<String, TodoModel> _cache = {};

  Future<Map<String, dynamic>?> _apiCall(String id) async {
    return {'id': id, 'title': 'Test', 'status': 200};
  }

  Future<List<Map<String, dynamic>>> _apiCallList() async {
    return [
      {'id': '1', 'title': 'Test 1'},
      {'id': '2', 'title': 'Test 2'},
    ];
  }
}

// ✅ GOOD: Local DataSource also throws exceptions
class TodoLocalDataSource {
  // ✅ Direct return type with exceptions
  Future<TodoModel> getTodoById(String id) async {
    final todo = await _database.query(id);

    if (todo == null) {
      throw NotFoundException('Todo not found in local database: $id');
    }

    return TodoModel(id: todo['id'], title: todo['title']);
  }

  // ✅ List return with exception
  Future<List<TodoModel>> getAllTodos() async {
    final todos = await _database.queryAll();
    return todos
        .map((json) => TodoModel(
              id: json['id'] as String,
              title: json['title'] as String,
            ))
        .toList();
  }

  // ✅ Void method can also throw
  Future<void> saveTodo(TodoModel todo) async {
    try {
      await _database.insert(todo);
    } catch (e) {
      throw DatabaseException('Failed to save todo: $e');
    }
  }

  // Mock database
  final _Database _database = _Database();
}

// Mock database class
class _Database {
  Future<Map<String, dynamic>?> query(String id) async {
    return {'id': id, 'title': 'Cached'};
  }

  Future<List<Map<String, dynamic>>> queryAll() async {
    return [];
  }

  Future<void> insert(TodoModel todo) async {}
}

class SocketException implements Exception {}
