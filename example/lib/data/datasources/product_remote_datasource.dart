// ✅ Good example: DataSource with abstraction in Data Layer

import '../models/product_model.dart';

// ✅ Abstract DataSource interface
abstract class ProductRemoteDataSource {
  Future<List<ProductModel>> getProducts();
  Future<ProductModel> getProductById(String id);
}

// ✅ Concrete implementation
class ProductRemoteDataSourceImpl implements ProductRemoteDataSource {
  @override
  Future<List<ProductModel>> getProducts() async {
    // API call implementation
    return [];
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    // API call implementation
    throw UnimplementedError();
  }
}
