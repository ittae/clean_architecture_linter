import '../../domain/entities/todo.dart';

/// Stand-in for a database annotation (e.g. ObjectBox's `@Entity()`).
/// clean_architecture_linter treats database-annotated models as an
/// exception to the `@freezed` requirement — see README's "ObjectBox
/// Example" note. Declared locally so this example needs no extra
/// dependency; a real app would import the actual database package.
class Entity {
  const Entity();
}

/// Data model. Plain "Model" suffix — no DataSource implementation detail
/// (e.g. "Remote", "Firestore") baked into the name.
@Entity()
class TodoModel {
  const TodoModel({
    required this.id,
    required this.title,
    required this.isDone,
  });

  final String id;
  final String title;
  final bool isDone;
}

/// Conversion extension lives in the same file as the Model.
extension TodoModelX on TodoModel {
  Todo toEntity() => Todo(id: id, title: title, isDone: isDone);
}
