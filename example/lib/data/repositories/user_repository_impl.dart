// Data repository implementation
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../models/user_model.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl(this.remoteDataSource);

  @override
  Future<User?> getUser(String userId) async {
    try {
      final userModel = await remoteDataSource.fetchUser(userId);
      return userModel;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  @override
  Future<List<User>> getAllUsers() async {
    try {
      final userModels = await remoteDataSource.fetchAllUsers();
      return userModels;
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  @override
  Future<bool> saveUser(User user) async {
    try {
      final userModel = UserModel(
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.createdAt,
      );
      return await remoteDataSource.saveUser(userModel);
    } catch (e) {
      print('Error saving user: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteUser(String userId) async {
    try {
      return await remoteDataSource.deleteUser(userId);
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }
}