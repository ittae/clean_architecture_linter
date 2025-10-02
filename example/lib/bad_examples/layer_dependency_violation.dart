// This file demonstrates layer dependency violations

// BAD: Presentation layer directly importing Data layer
import '../data/repositories/user_repository_impl.dart';
import '../data/datasources/user_remote_datasource.dart';

class PresentationLayerViolation {
  // BAD: Presentation directly instantiating data layer classes
  final userRepository = UserRepositoryImpl(UserRemoteDataSourceImpl());
  final dataSource = UserRemoteDataSourceImpl();

  void fetchUser() {
    // This violates the dependency rule
    // Presentation should only depend on Domain layer
    userRepository.getUser('123');
  }
}
