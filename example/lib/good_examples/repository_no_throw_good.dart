// ignore_for_file: unused_element, unused_field

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

class TodoFailure {
  final String message;
  TodoFailure(this.message);

  factory TodoFailure.validation(String msg) => TodoFailure(msg);
  factory TodoFailure.notFound(String msg) => TodoFailure(msg);
  factory TodoFailure.unknown(String msg) => TodoFailure(msg);
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
}

abstract class TodoRepository {
  Future<Result<Todo, TodoFailure>> getTodo(String id);
  Future<Result<List<Todo>, TodoFailure>> getTodos();
}

// ✅ GOOD: Repository returns Failure instead of throwing
class TodoRepositoryImpl implements TodoRepository {
  final _TodoDataSource _dataSource = _TodoDataSource();

  @override
  Future<Result<Todo, TodoFailure>> getTodo(String id) async {
    // ✅ Return Failure instead of throwing
    if (id.isEmpty) {
      return Failure(TodoFailure.validation('ID is required'));
    }

    try {
      final todo = await _dataSource.getTodo(id);
      return Success(todo);
    } on NotFoundException catch (e) {
      // ✅ Catch and convert to Failure
      return Failure(TodoFailure.notFound(e.message));
    } catch (e) {
      // ✅ Convert to Failure, not throw
      return Failure(TodoFailure.unknown('Failed to get todo: $e'));
    }
  }

  @override
  Future<Result<List<Todo>, TodoFailure>> getTodos() async {
    try {
      final todos = await _dataSource.getTodos();

      // ✅ Return Failure instead of throwing
      if (todos.isEmpty) {
        return Failure(TodoFailure('No todos found'));
      }

      return Success(todos);
    } catch (e) {
      return Failure(TodoFailure.unknown('Error: $e'));
    }
  }

  // ✅ Private helper can throw (caught by public methods)
  Future<Todo> _fetchFromCache(String id) async {
    if (!_cache.containsKey(id)) {
      throw Exception('Not in cache'); // ✅ OK in private method
    }
    return _cache[id]!;
  }

  final Map<String, Todo> _cache = {};
}

// ✅ GOOD: Constructor validation is allowed
class UserRepositoryImpl implements UserRepository {
  final UserDataSource dataSource;

  // ✅ Constructor can validate and throw
  UserRepositoryImpl(this.dataSource) {
    if (dataSource == null) {
      throw ArgumentError('DataSource is required'); // ✅ OK in constructor
    }
  }

  Future<Result<User, String>> getUser(String id) async {
    try {
      final user = await dataSource.getUser(id);
      return Success(user);
    } catch (e) {
      return Failure('Error: $e');
    }
  }
}

abstract class UserRepository {
  Future<Result<User, String>> getUser(String id);
}

class User {
  final String id;
  User(this.id);
}

class UserDataSource {
  Future<User> getUser(String id) async => User(id);
}

// ✅ GOOD: Rethrow is allowed
class ProductRepositoryImpl implements ProductRepository {
  Future<Result<Product, String>> getProduct(String id) async {
    try {
      final product = await _api.getProduct(id);
      return Success(product);
    } catch (e) {
      // Log error
      print('Error: $e');
      rethrow; // ✅ Rethrow is allowed in catch blocks
    }
  }

  final _ProductApi _api = _ProductApi();
}

abstract class ProductRepository {
  Future<Result<Product, String>> getProduct(String id);
}

class Product {
  final String id;
  Product(this.id);
}

class _ProductApi {
  Future<Product> getProduct(String id) async => Product(id);
}

class _TodoDataSource {
  Future<Todo> getTodo(String id) async {
    if (id == 'not_found') {
      throw NotFoundException('Todo not found: $id');
    }
    return Todo(id: id, title: 'Test');
  }

  Future<List<Todo>> getTodos() async => [];
}
