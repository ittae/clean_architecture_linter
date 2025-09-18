// Good examples of Clean Architecture Domain Layer

// ✅ Immutable Entity
class UserEntity {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  bool isValidEmail() {
    return email.contains('@') && email.contains('.');
  }

  bool canPerformAction() {
    return isValidEmail() && name.isNotEmpty;
  }
}

// ✅ Repository Interface (Abstract)
abstract class UserRepository {
  Future<UserEntity?> getUserById(String id);
  Future<List<UserEntity>> getAllUsers();
  Future<void> saveUser(UserEntity user);
  Future<void> deleteUser(String id);
}

// ✅ Single Responsibility UseCase
class GetUserByIdUseCase {
  final UserRepository repository;

  GetUserByIdUseCase(this.repository);

  Future<UserEntity?> call(String userId) {
    return repository.getUserById(userId);
  }
}

// ✅ Another UseCase with clear responsibility
class ValidateUserUseCase {
  ValidateUserUseCase();

  bool call(UserEntity user) {
    return user.isValidEmail() && user.name.trim().isNotEmpty;
  }
}