// BAD: Entity with application-specific and infrastructure concerns

// Mock classes to simulate the violations without actual dependencies
class HttpClient {
  Future<HttpResponse> post(String url, {Map<String, dynamic>? body}) async {
    return HttpResponse();
  }
}

class HttpResponse {}

class BuildContext {}

class Navigator {
  static Navigator of(BuildContext context) => Navigator();
  void pushNamed(String route) {}
}

class Widget {}

class Container extends Widget {}

class Text extends Widget {
  Text(String text);
}

class BadOrderEntity {
  // BAD: Mutable fields violate immutability
  String id;
  String customerId;
  List<BadOrderItem> items;

  // BAD: Infrastructure dependency in entity
  final HttpClient httpClient;

  // BAD: UI framework dependency
  final BuildContext? context;

  BadOrderEntity({
    required this.id,
    required this.customerId,
    required this.items,
    required this.httpClient,
    this.context,
  });

  // BAD: Application-specific method (navigation concern)
  void navigateToPayment() {
    if (context != null) {
      final nav = Navigator.of(context!);
      nav.pushNamed('/payment');
    }
  }

  // BAD: Infrastructure method in entity
  Future<void> saveToDatabase() async {
    final response = await httpClient.post(
      'https://api.example.com/orders',
      body: {'id': id, 'customerId': customerId},
    );
  }

  // BAD: Technology-specific method
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerId': customerId,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // BAD: UI-related method
  Widget buildOrderWidget() {
    return Container();
  }

  // BAD: Operational concern
  void logOrderCreation() {
    print('Order created: $id at ${DateTime.now()}');
  }

  // BAD: Caching concern (infrastructure)
  void cacheOrder() {
    // Cache implementation
  }

  // BAD: Application-specific business rule (discount logic may vary by app)
  double calculateDiscount() {
    // This might be different for mobile app vs web app
    if (items.length > 5) {
      return 0.1; // 10% discount for mobile app
    }
    return 0.05; // 5% for web app
  }

  // BAD: Setter method violates immutability
  void setStatus(String newStatus) {
    // Mutating state
  }
}

class BadOrderItem {
  // BAD: Mutable fields
  String productId;
  int quantity;

  BadOrderItem({required this.productId, required this.quantity});

  // BAD: Infrastructure method
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
  };
}

// BAD: Technology-specific class name
class JsonOrderEntity {
  final String data;
  JsonOrderEntity(this.data);
}

// BAD: Temporal class name
class LegacyOrderEntity {
  final String id;
  LegacyOrderEntity(this.id);
}

// BAD: Application-specific class name
class MobileOrderEntity {
  final String id;
  MobileOrderEntity(this.id);
}