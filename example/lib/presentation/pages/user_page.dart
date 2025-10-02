// GOOD: Presentation layer properly depending only on Domain layer
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_user.dart';

class UserPage {
  // GOOD: Using domain use case instead of data layer directly
  final GetUserUseCase getUserUseCase;

  UserPage(this.getUserUseCase);

  Future<void> loadUser(String userId) async {
    final user = await getUserUseCase.execute(userId);
    if (user != null) {
      displayUser(user);
    }
  }

  void displayUser(User user) {
    print('Displaying user: ${user.name}');
  }
}
