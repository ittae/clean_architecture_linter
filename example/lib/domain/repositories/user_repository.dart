// Domain repository interface - abstraction
import '../entities/user.dart';

abstract class UserRepository {
  Future<User?> getUser(String userId);
  Future<List<User>> getAllUsers();
  Future<bool> saveUser(User user);
  Future<bool> deleteUser(String userId);
}