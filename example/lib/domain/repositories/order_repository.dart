// Domain repository interface for orders
import '../entities/order_entity.dart';

abstract class OrderRepository {
  Future<Order?> getOrder(String orderId);
  Future<List<Order>> getOrdersByCustomer(String customerId);
  Future<bool> saveOrder(Order order);
  Future<bool> updateOrder(Order order);
  Future<bool> deleteOrder(String orderId);
}
