// Domain entity - Pure business logic
class User {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  bool get isNewUser => DateTime.now().difference(createdAt).inDays < 30;
}
