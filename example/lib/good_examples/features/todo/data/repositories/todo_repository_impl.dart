import '../../domain/entities/todo.dart';
import '../../domain/repositories/todo_repository.dart';
import '../datasources/todo_remote_datasource.dart';
import '../models/todo_model.dart';

/// Repository implementation: pass-through pattern.
/// Returns Future<Todo> directly and lets DataSource exceptions bubble up.
class TodoRepositoryImpl implements TodoRepository {
  const TodoRepositoryImpl(this._remoteDataSource);

  final TodoRemoteDataSource _remoteDataSource;

  @override
  Future<Todo> getTodo(String id) async {
    final model = await _remoteDataSource.getTodo(id);
    return model.toEntity();
  }
}
