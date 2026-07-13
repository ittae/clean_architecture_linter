/// Immutable domain entity. No framework imports, no mutable fields.
class Todo {
  const Todo({required this.id, required this.title, required this.isDone});

  final String id;
  final String title;
  final bool isDone;
}
