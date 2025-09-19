// GOOD: Proper Presenter in Interface Adapter layer
import '../../domain/entities/order_entity.dart';

class OrderPresenter {
  // GOOD: Presenter formats data for display
  OrderViewModel presentOrderCreated(Order order) {
    return OrderViewModel(
      id: order.id,
      customerName: 'Customer ${order.customerId}', // Format for display
      itemCount: order.items.length,
      formattedTotal: _formatCurrency(order.totalAmount),
      statusText: _formatOrderStatus(order.status),
      createdAtText: _formatDate(order.createdAt),
      canBeCancelled: order.canBeCancelled(),
    );
  }

  // GOOD: Format error for user display
  ErrorViewModel presentOrderError(String errorMessage) {
    return ErrorViewModel(
      title: 'Order Creation Failed',
      message: _formatErrorMessage(errorMessage),
      isRetryable: _isRetryableError(errorMessage),
    );
  }

  // GOOD: Format system error for user display
  ErrorViewModel presentSystemError(String systemError) {
    return ErrorViewModel(
      title: 'System Error',
      message: 'Something went wrong. Please try again later.',
      isRetryable: true,
    );
  }

  // GOOD: Format cancellation confirmation
  ConfirmationViewModel presentOrderCancellation(String orderId) {
    return ConfirmationViewModel(
      title: 'Cancel Order',
      message: 'Are you sure you want to cancel order $orderId?',
      confirmText: 'Yes, Cancel',
      cancelText: 'Keep Order',
    );
  }

  // GOOD: Private formatting helpers (presentation logic)
  String _formatCurrency(Money amount) {
    return '\$${amount.amount.toStringAsFixed(2)}';
  }

  String _formatOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Processing';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.shipped:
        return 'On the way';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatErrorMessage(String errorMessage) {
    // Convert technical error to user-friendly message
    if (errorMessage.contains('User not found')) {
      return 'Please check your account and try again.';
    } else if (errorMessage.contains('Invalid order')) {
      return 'Please review your order details.';
    } else {
      return 'Unable to create order. Please try again.';
    }
  }

  bool _isRetryableError(String errorMessage) {
    return !errorMessage.contains('User not found');
  }
}

// GOOD: View Models for UI layer - simple data containers
class OrderViewModel {
  final String id;
  final String customerName;
  final int itemCount;
  final String formattedTotal;
  final String statusText;
  final String createdAtText;
  final bool canBeCancelled;

  OrderViewModel({
    required this.id,
    required this.customerName,
    required this.itemCount,
    required this.formattedTotal,
    required this.statusText,
    required this.createdAtText,
    required this.canBeCancelled,
  });
}

class ErrorViewModel {
  final String title;
  final String message;
  final bool isRetryable;

  ErrorViewModel({
    required this.title,
    required this.message,
    required this.isRetryable,
  });
}

class ConfirmationViewModel {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  ConfirmationViewModel({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });
}

// Import necessary types
class Money {
  final double amount;
  final String currency;
  Money(this.amount, this.currency);
}

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }