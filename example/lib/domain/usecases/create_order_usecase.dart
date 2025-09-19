// GOOD: Proper Use Case implementing application-specific business rules
import '../entities/user.dart';
import '../entities/order_entity.dart';
import '../repositories/user_repository.dart';
import '../repositories/order_repository.dart';

class CreateOrderUseCase {
  final UserRepository userRepository;
  final OrderRepository orderRepository;

  CreateOrderUseCase({
    required this.userRepository,
    required this.orderRepository,
  });

  // GOOD: Single responsibility - creates an order
  Future<CreateOrderResult> execute(CreateOrderRequest request) async {
    // GOOD: Application-specific business rule - validate user can create order
    final user = await userRepository.getUser(request.userId);
    if (user == null) {
      return CreateOrderResult.failure('User not found');
    }

    // GOOD: Application-specific rule - check user permissions
    if (!_canUserCreateOrder(user)) {
      return CreateOrderResult.failure('User not authorized to create orders');
    }

    // GOOD: Orchestrate entity creation using enterprise business rules
    final order = Order(
      id: _generateOrderId(),
      customerId: user.id,
      items: request.items,
      createdAt: DateTime.now(),
      status: OrderStatus.pending,
      totalAmount: _calculateTotal(request.items),
    );

    // GOOD: Use entity business rules for validation
    if (!order.isValid) {
      return CreateOrderResult.failure('Invalid order data');
    }

    // GOOD: Application-specific rule - large orders need approval
    if (order.requiresApproval) {
      await _requestApproval(order);
    }

    // GOOD: Use repository abstraction to save
    final success = await orderRepository.saveOrder(order);

    if (success) {
      return CreateOrderResult.success(order);
    } else {
      return CreateOrderResult.failure('Failed to save order');
    }
  }

  // GOOD: Application-specific business rule
  bool _canUserCreateOrder(User user) {
    // This rule might vary by application context
    return user.isNewUser ? true : user.email.isNotEmpty;
  }

  // GOOD: Private helper for orchestration
  String _generateOrderId() {
    return 'ORD_${DateTime.now().millisecondsSinceEpoch}';
  }

  // GOOD: Private helper that orchestrates entity calculations
  Money _calculateTotal(List<OrderItem> items) {
    return items.fold(
      Money.zero(),
      (total, item) => total.add(item.totalPrice),
    );
  }

  // GOOD: Application-specific workflow step
  Future<void> _requestApproval(Order order) async {
    // This would typically notify an approval service
    // Implementation is application-specific
  }
}

// GOOD: Application-specific input/output data structures
class CreateOrderRequest {
  final String userId;
  final List<OrderItem> items;

  CreateOrderRequest({
    required this.userId,
    required this.items,
  });
}

class CreateOrderResult {
  final bool isSuccess;
  final Order? order;
  final String? errorMessage;

  CreateOrderResult._({
    required this.isSuccess,
    this.order,
    this.errorMessage,
  });

  factory CreateOrderResult.success(Order order) {
    return CreateOrderResult._(isSuccess: true, order: order);
  }

  factory CreateOrderResult.failure(String message) {
    return CreateOrderResult._(isSuccess: false, errorMessage: message);
  }
}

// Repository abstractions (would be defined elsewhere)
abstract class OrderRepository {
  Future<bool> saveOrder(Order order);
  Future<Order?> getOrder(String orderId);
}