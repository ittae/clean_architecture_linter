// GOOD: Pure enterprise business rules entity
class Order {
  final String id;
  final String customerId;
  final List<OrderItem> items;
  final DateTime createdAt;
  final OrderStatus status;
  final Money totalAmount;

  const Order({
    required this.id,
    required this.customerId,
    required this.items,
    required this.createdAt,
    required this.status,
    required this.totalAmount,
  });

  // GOOD: Core business rule - valid across all applications
  bool get isValid => items.isNotEmpty && totalAmount.isPositive;

  // GOOD: Enterprise-wide business rule
  bool get requiresApproval => totalAmount.amount > 10000;

  // GOOD: Stable business logic
  Money calculateSubtotal() {
    return items.fold(
      Money.zero(),
      (total, item) => total.add(item.totalPrice),
    );
  }

  // GOOD: Business rule that applies to all contexts
  bool canBeCancelled() {
    return status == OrderStatus.pending || status == OrderStatus.confirmed;
  }

  // GOOD: Domain-specific validation
  bool hasValidItems() {
    return items.every((item) => item.isValid);
  }
}

class OrderItem {
  final String productId;
  final int quantity;
  final Money unitPrice;

  const OrderItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  bool get isValid => quantity > 0 && unitPrice.isPositive;
  Money get totalPrice => unitPrice.multiply(quantity);
}

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }

class Money {
  final double amount;
  final String currency;

  const Money(this.amount, this.currency);

  factory Money.zero() => const Money(0, 'USD');

  bool get isPositive => amount > 0;

  Money add(Money other) {
    if (currency != other.currency) {
      throw ArgumentError('Cannot add different currencies');
    }
    return Money(amount + other.amount, currency);
  }

  Money multiply(int factor) => Money(amount * factor, currency);
}
