import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_local_datasource.dart';

class CartRepositoryImpl implements CartRepository {
  final CartLocalDataSource localDataSource;

  CartRepositoryImpl(this.localDataSource);

  @override
  Future<List<Map<String, dynamic>>> getCartItems(int? userId) async {
    return await localDataSource.getCartItems(userId);
  }

  @override
  Future<Map<int, int>> getReservedQuantities() async {
    return await localDataSource.getReservedQuantities();
  }

  @override
  Future<int> getUserReservedQuantity(int productId, int? userId) async {
    return await localDataSource.getUserReservedQuantity(productId, userId);
  }


  @override
  Future<int> addToCart(int? userId, int productId, int quantity) async {
    return await localDataSource.addToCart(userId, productId, quantity);
  }

  @override
  Future<void> updateCartItemQuantity(int? userId, int productId, int quantity) async {
    return await localDataSource.updateCartItemQuantity(userId, productId, quantity);
  }

  @override
  Future<void> removeFromCart(int? userId, int productId) async {
    return await localDataSource.removeFromCart(userId, productId);
  }

  @override
  Future<void> clearCart(int? userId) async {
    return await localDataSource.clearCart(userId);
  }

  @override
  Future<List<Map<String, dynamic>>> removeExpiredCartItems() async {
    return await localDataSource.removeExpiredCartItems();
  }
}
