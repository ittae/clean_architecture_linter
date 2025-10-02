// ❌ DataSource in Domain Layer - WRONG LOCATION!
// DataSource should be in Data Layer, not Domain Layer

class ProductModel {}

// ❌ This will be flagged - DataSource in Domain Layer
abstract class ProductDataSource {
  Future<List<ProductModel>> getProducts();
}
