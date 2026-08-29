import '../data/repositories/todo_repository_impl.dart';

/// Triggers `layer_dependency` (cross_layer slice contract).
class BadPresentationImport {
  BadPresentationImport(this.repository);

  final TodoRepositoryImpl repository;
}
