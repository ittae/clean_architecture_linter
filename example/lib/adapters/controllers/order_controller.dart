// GOOD: Proper Controller in Interface Adapter layer
import '../../domain/usecases/create_order_usecase.dart';
import '../presenters/order_presenter.dart';

class OrderController {
  final CreateOrderUseCase createOrderUseCase;
  final OrderPresenter presenter;

  OrderController({
    required this.createOrderUseCase,
    required this.presenter,
  });

  // GOOD: Controller handles user input and coordinates
  Future<void> handleCreateOrder(CreateOrderInput input) async {
    try {
      // GOOD: Convert UI input to use case format
      final request = CreateOrderRequest(
        userId: input.userId,
        items: input.items
            .map((item) => OrderItem(
                  productId: item.productId,
                  quantity: item.quantity,
                  unitPrice: Money(item.price, 'USD'),
                ))
            .toList(),
      );

      // GOOD: Call use case
      final result = await createOrderUseCase.execute(request);

      // GOOD: Delegate to presenter for output formatting
      if (result.isSuccess) {
        presenter.presentOrderCreated(result.order!);
      } else {
        presenter.presentOrderError(result.errorMessage!);
      }
    } catch (e) {
      presenter.presentSystemError(e.toString());
    }
  }

  // GOOD: Controller handles different user actions
  void handleCancelOrder(String orderId) {
    // Coordinate with appropriate use case
    presenter.presentOrderCancellation(orderId);
  }
}

// GOOD: Simple data structure for UI input
class CreateOrderInput {
  final String userId;
  final List<OrderItemInput> items;

  CreateOrderInput({
    required this.userId,
    required this.items,
  });
}

class OrderItemInput {
  final String productId;
  final int quantity;
  final double price;

  OrderItemInput({
    required this.productId,
    required this.quantity,
    required this.price,
  });
}

// Import necessary types
class Money {
  final double amount;
  final String currency;
  Money(this.amount, this.currency);
}

class OrderItem {
  final String productId;
  final int quantity;
  final Money unitPrice;

  OrderItem({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  Money get totalPrice =>
      Money(unitPrice.amount * quantity, unitPrice.currency);
}
