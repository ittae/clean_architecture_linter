// Good examples of Clean Architecture Domain Layer
import 'package:freezed_annotation/freezed_annotation.dart';

part 'domain_examples.freezed.dart';

// ✅ Immutable Entity with Business Logic
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

// ✅ Freezed Entity with Extension (Business Logic Pattern)
@freezed
class Todo with _$Todo {
  const factory Todo({
    required String id,
    required String title,
    required bool isCompleted,
    DateTime? dueDate,
  }) = _Todo;
}

// ✅ Business logic in extension (same file)
extension TodoX on Todo {
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  bool get isPending => !isCompleted && !isOverdue;

  Todo markAsCompleted() => copyWith(isCompleted: true);

  Todo updateTitle(String newTitle) => copyWith(title: newTitle);
}

// ✅ Value Object (Allowed without complex business logic)
class Email {
  final String value;

  const Email(this.value);

  bool get isValid => value.contains('@') && value.length > 3;
}

// ✅ Value Object with simple validation
class Money {
  final double amount;
  final String currency;

  const Money(this.amount, this.currency);

  bool get isPositive => amount > 0;
}

// ✅ Complex Entity with Multiple Business Logic Methods
class Order {
  final String id;
  final List<OrderItem> items;
  final DateTime createdAt;
  final String status;

  const Order({
    required this.id,
    required this.items,
    required this.createdAt,
    required this.status,
  });

  // ✅ Business logic: calculations
  double get totalAmount {
    return items.fold(0.0, (sum, item) => sum + item.price * item.quantity);
  }

  // ✅ Business logic: validations
  bool get canBeCancelled {
    return status == 'pending' || status == 'processing';
  }

  // ✅ Business logic: transformations
  Order cancel() {
    if (!canBeCancelled) {
      throw Exception('Order cannot be cancelled in status: $status');
    }
    return Order(
      id: id,
      items: items,
      createdAt: createdAt,
      status: 'cancelled',
    );
  }
}

class OrderItem {
  final String productId;
  final int quantity;
  final double price;

  const OrderItem({
    required this.productId,
    required this.quantity,
    required this.price,
  });
}
