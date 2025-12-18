import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_datasource.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductLocalDataSource localDataSource;

  ProductRepositoryImpl(this.localDataSource);

  @override
  Future<List<Product>> getAllProducts({
    String? searchQuery,
    int? categoryId,
    String? sortBy,
    int? limit,
    int? offset,
  }) async {
    final models = await localDataSource.getAllProducts(
      searchQuery: searchQuery,
      categoryId: categoryId,
      sortBy: sortBy,
      limit: limit,
      offset: offset,
    );
    return models;
  }

  @override
  Future<Product?> getProductById(int id) async {
    return await localDataSource.getProductById(id);
  }

  @override
  Future<Product?> getProductBySku(String sku) async {
    return await localDataSource.getProductBySku(sku);
  }

  @override
  Future<int> insertProduct(Product product) async {
    final model = ProductModel.fromEntity(product);
    return await localDataSource.insertProduct(model);
  }

  @override
  Future<int> updateProduct(Product product) async {
    final model = ProductModel.fromEntity(product);
    return await localDataSource.updateProduct(model);
  }

  @override
  Future<int> deleteProduct(int id) async {
    return await localDataSource.deleteProduct(id);
  }

  @override
  Future<List<Product>> getLowStockProducts() async {
    final models = await localDataSource.getLowStockProducts();
    return models;
  }

  @override
  Future<int> getProductCount({String? searchQuery, int? categoryId}) async {
    return await localDataSource.getProductCount(
      searchQuery: searchQuery,
      categoryId: categoryId,
    );
  }

  @override
  Future<List<ProductCharacteristic>> getCharacteristicsByProduct(int productId) async {
    return await localDataSource.getCharacteristicsByProduct(productId);
  }

  @override
  Future<void> setProductCharacteristics(
    int productId,
    List<ProductCharacteristic> characteristics,
  ) async {
    await localDataSource.setProductCharacteristics(productId, characteristics);
  }
}

