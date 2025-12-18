import '../entities/product.dart';
import '../entities/product_characteristic.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts({
    String? searchQuery,
    int? categoryId,
    String? sortBy,
    int? limit,
    int? offset,
  });
  Future<Product?> getProductById(int id);
  Future<Product?> getProductBySku(String sku);
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<List<Product>> getLowStockProducts();
  Future<int> getProductCount({String? searchQuery, int? categoryId});
  Future<List<ProductCharacteristic>> getCharacteristicsByProduct(int productId);
  Future<void> setProductCharacteristics(int productId, List<ProductCharacteristic> characteristics);
}

