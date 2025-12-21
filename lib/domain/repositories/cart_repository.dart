abstract class CartRepository {
  /// Получить все товары в корзине пользователя
  Future<List<Map<String, dynamic>>> getCartItems(int? userId);
  
  /// Получить количество резервированных товаров по product_id (сумма всех корзин)
  Future<Map<int, int>> getReservedQuantities();

  /// Получить количество резервированного товара этим пользователем
  Future<int> getUserReservedQuantity(int productId, int? userId);
  
  /// Добавить товар в корзину
  Future<int> addToCart(int? userId, int productId, int quantity);
  
  /// Обновить количество товара в корзине
  Future<void> updateCartItemQuantity(int? userId, int productId, int quantity);
  
  /// Удалить товар из корзины
  Future<void> removeFromCart(int? userId, int productId);
  
  /// Очистить корзину пользователя
  Future<void> clearCart(int? userId);
  
  /// Получить и удалить старые записи корзины (старше 24 часов)
  /// Возвращает список удаленных записей с product_id и quantity
  Future<List<Map<String, dynamic>>> removeExpiredCartItems();
}
