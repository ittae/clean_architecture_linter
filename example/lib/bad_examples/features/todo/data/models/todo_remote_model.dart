/// ❌ Triggers `model_naming_convention`.
///
/// The Model name leaks a DataSource implementation detail ("Remote").
/// Models must stay independent of where the data comes from.
///
/// Fix: see ../../../../../good_examples/features/todo/data/models/todo_model.dart
/// (rename `TodoRemoteModel` -> `TodoModel`).
class Entity {
  const Entity();
}

@Entity()
class TodoRemoteModel {
  const TodoRemoteModel({required this.id});

  final String id;
}
