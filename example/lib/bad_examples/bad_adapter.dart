// BAD: Adapter with multiple Clean Architecture violations

// Mock external service types
class HttpClient {
  Future<Map<String, dynamic>> get(String url) async => {};
  Future<Map<String, dynamic>> post(String url, Map<String, dynamic> data) async => {};
}

class Database {
  Future<void> save(Map<String, dynamic> data) async {}
  Future<Map<String, dynamic>?> query(String sql) async => null;
}

// BAD: Controller with business logic and UI concerns
class BadOrderController {
  final HttpClient httpClient;
  final Database database;

  BadOrderController(this.httpClient, this.database);

  // BAD: Controller implementing business logic
  Future<void> createOrder(Map<String, dynamic> orderData) async {
    // BAD: Business logic in controller (should be in use case)
    double total = 0;
    for (var item in orderData['items']) {
      double price = item['price'];
      int quantity = item['quantity'];

      // BAD: Business rule implementation
      if (quantity > 10) {
        price = price * 0.9; // Volume discount
      }

      total += price * quantity;
    }

    // BAD: Tax calculation (business logic)
    double tax = total * 0.08;
    double finalTotal = total + tax;

    // BAD: Direct database access (should use repository)
    await database.save({
      'total': finalTotal,
      'tax': tax,
      'status': 'pending',
    });

    // BAD: Direct HTTP call (should use gateway)
    await httpClient.post('https://api.payment.com/charge', {
      'amount': finalTotal,
    });

    // BAD: UI rendering in controller
    print('Order created successfully!'); // This is UI concern
  }

  // BAD: Data formatting in controller (should be in presenter)
  String formatOrderTotal(double total) {
    return '\$${total.toStringAsFixed(2)}';
  }

  // BAD: Validation logic in controller (should be in entity/use case)
  bool validateOrder(Map<String, dynamic> orderData) {
    return orderData['items'].isNotEmpty;
  }
}

// BAD: Presenter with business logic and UI rendering
class BadOrderPresenter {
  // BAD: Business logic in presenter
  double calculateDiscount(double total, String customerType) {
    if (customerType == 'premium') {
      return total * 0.1;
    }
    return 0;
  }

  // BAD: Direct use case call (should go through controller)
  Future<void> processOrder() async {
    // This should be in controller, not presenter
  }

  // BAD: UI rendering in presenter (should be in view)
  Widget buildOrderWidget() {
    return Container();
  }

  // BAD: User input handling (should be in controller)
  void onOrderButtonClick() {
    // Presenter should not handle user input
  }
}

// BAD: View with business logic and data processing
class BadOrderView {
  // BAD: Business logic in view
  double calculateTax(double amount) {
    return amount * 0.08;
  }

  // BAD: Direct use case call from view
  Future<void> submitOrder() async {
    // Views should delegate to controller
  }

  // BAD: Data processing in view (should be in presenter)
  List<String> formatOrderItems(List<dynamic> items) {
    return items.map((item) => '${item['name']}: \$${item['price']}').toList();
  }

  // BAD: Complex validation logic (should be in use case/entity)
  bool validateComplexOrderRules(Map<String, dynamic> order) {
    // Complex business rules should not be in view
    return true;
  }
}

// BAD: Model with business logic
class BadOrderModel {
  final String id;
  final double total;
  final List<dynamic> items;

  BadOrderModel({
    required this.id,
    required this.total,
    required this.items,
  });

  // BAD: Business logic in model (should be data container only)
  double calculateTotal() {
    return items.fold(0.0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  // BAD: Validation logic in model
  bool isValid() {
    return total > 0 && items.isNotEmpty;
  }

  // BAD: Persistence logic in model
  Future<void> save() async {
    // Models should not handle persistence
  }

  // BAD: UI logic in model
  String getDisplayText() {
    return 'Order #$id - Total: \$${total.toStringAsFixed(2)}';
  }
}

// BAD: External service adapter with business logic
class BadPaymentGateway {
  final HttpClient httpClient;

  BadPaymentGateway(this.httpClient);

  // BAD: Business logic in adapter
  Future<bool> processPayment(Map<String, dynamic> paymentData) async {
    double amount = paymentData['amount'];

    // BAD: Business rule in adapter (should be in use case)
    if (amount > 1000) {
      // Require additional verification for large amounts
      await _requireAdditionalVerification();
    }

    // BAD: Tax calculation in adapter (business logic)
    double tax = amount * 0.08;
    double totalWithTax = amount + tax;

    try {
      final response = await httpClient.post('/payment', {
        'amount': totalWithTax,
      });

      // BAD: Business logic for determining success
      return response['status'] == 'success' && totalWithTax > 0;
    } catch (e) {
      // BAD: No proper error conversion to domain errors
      throw e; // Should convert to domain error
    }
  }

  // BAD: Business logic method in adapter
  Future<void> _requireAdditionalVerification() async {
    // This business rule should not be in adapter
  }

  // BAD: No data conversion methods (adapters should convert formats)
  // Missing toApiFormat() and fromApiFormat() methods
}

// Mock UI classes
class Container {}
class Widget {}

// BAD: Adapter directly extending domain entities (tight coupling)
class BadUserAdapter extends User {
  BadUserAdapter(String id, String name) : super(id: id, name: name, email: '', createdAt: DateTime.now());

  // BAD: Adding persistence logic to domain entity
  Future<void> saveToDatabase() async {
    // This should be in repository implementation
  }
}

class User {
  final String id;
  final String name;
  final String email;
  final DateTime createdAt;

  User({required this.id, required this.name, required this.email, required this.createdAt});
}