// ignore_for_file: unused_element

import 'dart:async';

// Mock types
class Todo {
  final String id;
  final String title;
  Todo({required this.id, required this.title});

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
    );
  }
}

class HttpResponse {
  final int statusCode;
  final dynamic data;
  HttpResponse(this.statusCode, this.data);
}

class HttpClient {
  Future<HttpResponse> get(String path) async {
    return HttpResponse(200, {});
  }
}

// Defined Data layer exceptions
class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
}

class DataSourceException implements Exception {
  final String message;
  DataSourceException(this.message);
}

class CacheException implements Exception {
  final String message;
  CacheException(this.message);
}

class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
}

// ✅ GOOD: Using defined Data exceptions
class TodoRemoteDataSource {
  final HttpClient client;

  TodoRemoteDataSource(this.client);

  Future<Todo> getTodo(String id) async {
    try {
      final response = await client.get('/todos/$id');

      // ✅ Use NotFoundException for 404
      if (response.statusCode == 404) {
        throw NotFoundException('Todo not found: $id');
      }

      // ✅ Use UnauthorizedException for 401/403
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorizedException('Authentication required');
      }

      // ✅ Use ServerException for 5xx errors
      if (response.statusCode >= 500) {
        throw ServerException('Server error: ${response.statusCode}');
      }

      return Todo.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      // ✅ Use NetworkException for connection errors
      throw NetworkException('Failed to connect: $e');
    }
  }

  Future<List<Todo>> getTodos() async {
    try {
      final response = await client.get('/todos');

      if (response.statusCode == 404) {
        throw NotFoundException('Todos not found');
      }

      if (response.statusCode >= 500) {
        throw ServerException('Server error');
      }

      final data = response.data as List;
      return data.map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw NetworkException('Network error: $e');
    }
  }
}

// ✅ GOOD: Using CacheException in cache data source
class TodoCacheDataSource {
  Future<Todo> getCachedTodo(String id) async {
    // ✅ Use CacheException for cache errors
    throw CacheException('Cache miss for todo: $id');
  }

  Future<void> cacheTodo(Todo todo) async {
    // ✅ Use CacheException
    throw CacheException('Failed to cache todo');
  }
}

// ✅ GOOD: Using DatabaseException in local data source
class TodoLocalDataSource {
  Future<Todo> getTodoFromDb(String id) async {
    // ✅ Use DatabaseException for database errors
    throw DatabaseException('Failed to query todo from database');
  }

  Future<void> saveTodoToDb(Todo todo) async {
    // ✅ Use DatabaseException
    throw DatabaseException('Failed to save todo');
  }
}

// ✅ GOOD: Using DataSourceException for generic data source errors
class TodoDataSource {
  Future<Todo> getTodo(String id) async {
    // ✅ Use DataSourceException for data source specific errors
    throw DataSourceException('Data source unavailable');
  }
}

// ✅ GOOD: Multiple exception types based on error scenarios
class TodoApiDataSource {
  final HttpClient client;

  TodoApiDataSource(this.client);

  Future<List<Todo>> searchTodos(String query) async {
    try {
      final response = await client.get('/todos/search?q=$query');

      if (response.statusCode == 404) {
        // ✅ Not found
        throw NotFoundException('No todos found for: $query');
      }

      if (response.statusCode == 401) {
        // ✅ Unauthorized
        throw UnauthorizedException('Login required for search');
      }

      if (response.statusCode >= 500) {
        // ✅ Server error
        throw ServerException('Search service unavailable');
      }

      final data = response.data as List;
      return data.map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      // ✅ Network error
      throw NetworkException('Search failed: $e');
    }
  }
}
