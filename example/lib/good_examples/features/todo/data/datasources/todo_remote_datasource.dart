import '../models/todo_model.dart';

/// DataSource throws a plain exception; it never returns a Result type.
class TodoNotFoundException implements Exception {
  const TodoNotFoundException(this.id);

  final String id;
}

abstract class TodoRemoteDataSource {
  Future<TodoModel> getTodo(String id);
}

class TodoRemoteDataSourceImpl implements TodoRemoteDataSource {
  const TodoRemoteDataSourceImpl();

  @override
  Future<TodoModel> getTodo(String id) async {
    if (id.isEmpty) throw TodoNotFoundException(id);
    return TodoModel(id: id, title: 'Buy milk', isDone: false);
  }
}
