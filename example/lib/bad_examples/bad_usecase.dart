// BAD: Use Case with multiple violations of Clean Architecture principles

// BAD: Importing infrastructure directly
import 'dart:io';

// Mock classes to simulate violations
class HttpClient {
  Future<String> get(String url) async => 'response';
}

class Database {
  Future<void> save(Map<String, dynamic> data) async {}
  Future<Map<String, dynamic>?> find(String id) async => null;
}

class Widget {
  Widget();
}

class BuildContext {}

class Navigator {
  static void pushNamed(BuildContext context, String route) {}
}

// BAD: Use Case violating independence and orchestration principles
class BadOrderUseCase {
  // BAD: Direct infrastructure dependencies
  final HttpClient httpClient;
  final Database database;
  final BuildContext? context;

  BadOrderUseCase({
    required this.httpClient,
    required this.database,
    this.context,
  });

  // BAD: Multiple responsibilities in one method
  Future<void> createAndProcessAndNotifyOrder(
    String userId,
    List<String> productIds,
    String paymentMethod,
    String notificationEmail,
  ) async {
    // BAD: Direct database access (should use repository)
    final userData = await database.find(userId);
    if (userData == null) return;

    // BAD: Implementing entity-level business rules in use case
    double total = 0;
    for (final productId in productIds) {
      // BAD: Hard-coded business rule that should be in entity
      if (productId.startsWith('PREMIUM')) {
        total += 100.0;
      } else {
        total += 50.0;
      }
    }

    // BAD: Infrastructure concerns (HTTP calls)
    final paymentResponse = await httpClient.get(
      'https://payment-api.com/charge?amount=$total&method=$paymentMethod',
    );

    // BAD: Direct database save (should use repository)
    await database.save({
      'userId': userId,
      'total': total,
      'status': 'pending',
      'payment': paymentResponse,
    });

    // BAD: UI concerns in use case
    if (context != null) {
      Navigator.pushNamed(context!, '/order-confirmation');
    }

    // BAD: Infrastructure concern (email service)
    await _sendEmail(notificationEmail, 'Order created');

    // BAD: File system access (infrastructure)
    final file = File('/tmp/orders.log');
    await file.writeAsString('Order created for user $userId\n');
  }

  // BAD: Enterprise-level business rule implementation
  double calculateTax(double amount) {
    // This should be in an entity, not use case
    return amount * 0.08;
  }

  // BAD: Infrastructure method
  Future<void> _sendEmail(String email, String message) async {
    // Direct email service call
    await httpClient.get('https://email-api.com/send?to=$email&msg=$message');
  }

  // BAD: UI rendering in use case
  Widget buildOrderSummary() {
    return Widget();
  }

  // BAD: Multiple unrelated operations
  Future<void> processPaymentAndUpdateInventoryAndSendNotification() async {
    // Too many responsibilities
  }
}

// BAD: Use Case that affects entities (violates independence)
class BadUserValidationUseCase {
  // BAD: Implementing enterprise rules that should be in User entity
  bool validateUserEmail(String email) {
    // This enterprise rule should be in User entity
    return email.contains('@') && email.contains('.');
  }

  // BAD: Modifying entity behavior
  void updateUserValidationRules() {
    // Use cases should not affect entity rules
  }
}

// BAD: Generic use case name (not application-specific)
class GenericUseCase {
  void execute() {
    // Too generic
  }
}

// BAD: Multiple actions in one use case
class CreateAndUpdateAndDeleteUserUseCase {
  // Should be split into separate use cases
  void createAndUpdateAndDeleteUser() {}
}

// BAD: Technology-specific use case
class SqlDatabaseUserUseCase {
  // Name suggests technology dependence
  void executeSqlQuery() {}
}

// BAD: Framework-specific use case
class FlutterWidgetUseCase {
  // Depends on UI framework
  Widget buildWidget() => Widget();
}
