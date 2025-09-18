// Good examples of Clean Architecture Data Layer

import '../good_examples/domain_examples.dart';

// ✅ Proper DataSource naming
abstract class UserRemoteDataSource {
  Future<Map<String, dynamic>> getUserById(String id);
  Future<List<Map<String, dynamic>>> getAllUsers();
}

class UserApiDataSource implements UserRemoteDataSource {
  @override
  Future<Map<String, dynamic>> getUserById(String id) async {
    // API call implementation
    return {'id': id, 'name': 'John', 'email': 'john@example.com'};
  }

  @override
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    // API call implementation
    return [];
  }
}

// ✅ Proper Local DataSource
abstract class UserLocalDataSource {
  Future<Map<String, dynamic>?> getCachedUser(String id);
  Future<void> cacheUser(Map<String, dynamic> userData);
}

// ✅ Proper Model with serialization
class UserModel {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
  });

  // ✅ Required fromJson constructor
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // ✅ Required toJson method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Convert to domain entity
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      email: email,
      createdAt: createdAt,
    );
  }
}

// ✅ Repository Implementation with proper dependencies
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  final UserLocalDataSource localDataSource;

  UserRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<UserEntity?> getUserById(String id) async {
    try {
      final userData = await remoteDataSource.getUserById(id);
      final userModel = UserModel.fromJson(userData);

      // Cache the result
      await localDataSource.cacheUser(userData);

      return userModel.toEntity();
    } catch (e) {
      // Try local cache
      final cachedData = await localDataSource.getCachedUser(id);
      if (cachedData != null) {
        return UserModel.fromJson(cachedData).toEntity();
      }
      return null;
    }
  }

  @override
  Future<List<UserEntity>> getAllUsers() async {
    final usersData = await remoteDataSource.getAllUsers();
    return usersData
        .map((json) => UserModel.fromJson(json).toEntity())
        .toList();
  }

  @override
  Future<void> saveUser(UserEntity user) async {
    final userModel = UserModel(
      id: user.id,
      name: user.name,
      email: user.email,
      createdAt: user.createdAt,
    );

    // In real implementation, this would save to remote source
    await localDataSource.cacheUser(userModel.toJson());
  }

  @override
  Future<void> deleteUser(String id) async {
    // Implementation would delete from remote and local sources
  }
}