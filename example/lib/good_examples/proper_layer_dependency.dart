// This file demonstrates proper layer dependencies following Clean Architecture

class PresentationLayerProper {
  // GOOD: Depending on domain use case
  final GetUserUseCase getUserUseCase;

  PresentationLayerProper(this.getUserUseCase);

  Future<User?> fetchUser(String userId) async {
    // GOOD: Presentation calls domain use case
    return await getUserUseCase.execute(userId);
  }
}

// In domain/usecases/get_user.dart:
class GetUserUseCaseProper {
  // GOOD: Domain layer depends on abstraction (interface)
  final UserRepository repository;

  GetUserUseCaseProper(this.repository);

  Future<User?> execute(String userId) {
    return repository.getUser(userId);
  }
}

// In data/repositories/user_repository_impl.dart:
class UserRepositoryImplProper implements UserRepository {
  // GOOD: Data layer implements domain interface
  @override
  Future<User?> getUser(String userId) {
    // Implementation details
    return Future.value(User(id: userId, name: 'John Doe'));
  }
}

// Domain abstractions
abstract class UserRepository {
  Future<User?> getUser(String userId);
}

class User {
  final String id;
  final String name;

  User({required this.id, required this.name});
}

class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<User?> execute(String userId) {
    return repository.getUser(userId);
  }
}
