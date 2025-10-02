// ❌ Bad examples: DataSource violations

// Mock imports
class ProductModel {}
class ProductEntity {}

// ❌ Concrete DataSource without abstraction - will be flagged
class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts() async {
    return [];
  }
}

// ❌ DataSource in Domain Layer (wrong location) - will be flagged
// This would be detected if file was in domain/datasources/
// abstract class ProductDataSource {
//   Future<List<ProductEntity>> getProducts();  // ❌ Also wrong: returns Entity not Model
// }

// ❌ DataSource returning Entity instead of Model - will be flagged
abstract class OrderRemoteDataSource {
  Future<List<ProductEntity>> getOrders();  // ❌ Should return OrderModel
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  @override
  Future<List<ProductEntity>> getOrders() async {
    return [];
  }
}
