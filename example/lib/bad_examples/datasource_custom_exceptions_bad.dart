// ignore_for_file: unused_element

import 'dart:async';

// Mock types
class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});
}

// ❌ BAD: Using generic Exception
// This will trigger: datasource_exception_types
class TodoRemoteDataSourceBad1 {
  Future<Todo> getTodo(String id) async {
    // ❌ Generic Exception is not allowed
    throw Exception('Custom error message');
  }
}

// ❌ BAD: Using Dart built-in exceptions
class TodoRemoteDataSourceBad2 {
  Future<List<Todo>> getTodos() async {
    // ❌ StateError is not allowed
    throw StateError('Invalid state');
  }

  Future<Todo> getTodoById(String id) async {
    // ❌ FormatException is not allowed
    throw FormatException('Invalid format');
  }

  Future<void> deleteTodo(String id) async {
    // ❌ ArgumentError is not allowed
    throw ArgumentError('Invalid argument');
  }
}

// ❌ BAD: Using custom exception types
class CustomDataException implements Exception {
  final String message;
  CustomDataException(this.message);
}

class TodoApiException implements Exception {
  final String message;
  TodoApiException(this.message);
}

class TodoRemoteDataSourceBad3 {
  Future<Todo> getTodo(String id) async {
    // ❌ Custom exception is not allowed
    throw CustomDataException('Custom error');
  }

  Future<List<Todo>> getTodos() async {
    // ❌ Custom exception is not allowed
    throw TodoApiException('API error');
  }
}

// ❌ BAD: Mixed exceptions
class TodoRemoteDataSourceBad4 {
  Future<Todo> getTodo(String id) async {
    if (id.isEmpty) {
      // ❌ ArgumentError is not allowed
      throw ArgumentError('ID is required');
    }

    // ❌ Exception is not allowed
    throw Exception('Failed to get todo');
  }

  Future<void> saveTodo(Todo todo) async {
    // ❌ StateError is not allowed
    throw StateError('Invalid state for save');
  }
}

// ❌ BAD: Using AssertionError
class TodoRemoteDataSourceBad5 {
  Future<Todo> getTodo(String id) async {
    // ❌ AssertionError is not allowed
    throw AssertionError('Assertion failed');
  }
}

// ❌ BAD: Using RangeError
class TodoRemoteDataSourceBad6 {
  Future<List<Todo>> getTodosPaginated(int page, int limit) async {
    if (page < 0) {
      // ❌ RangeError is not allowed
      throw RangeError('Page must be positive');
    }
    return [];
  }
}
