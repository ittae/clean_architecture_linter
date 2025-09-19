// Data source - handles external communication
import '../models/user_model.dart';

abstract class UserRemoteDataSource {
  Future<UserModel?> fetchUser(String userId);
  Future<List<UserModel>> fetchAllUsers();
  Future<bool> saveUser(UserModel user);
  Future<bool> deleteUser(String userId);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  // This would normally use http client, dio, etc.

  @override
  Future<UserModel?> fetchUser(String userId) async {
    // Simulate API call
    await Future.delayed(Duration(milliseconds: 500));
    return UserModel(
      id: userId,
      name: 'John Doe',
      email: 'john@example.com',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<UserModel>> fetchAllUsers() async {
    await Future.delayed(Duration(milliseconds: 500));
    return [
      UserModel(
        id: '1',
        name: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime.now(),
      ),
      UserModel(
        id: '2',
        name: 'Jane Smith',
        email: 'jane@example.com',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<bool> saveUser(UserModel user) async {
    await Future.delayed(Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<bool> deleteUser(String userId) async {
    await Future.delayed(Duration(milliseconds: 500));
    return true;
  }
}