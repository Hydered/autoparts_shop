import '../entities/favorite.dart';

abstract class FavoritesRepository {
  /// Получить все избранные товары пользователя
  Future<List<Favorite>> getUserFavorites(int userId);

  /// Проверить, находится ли товар в избранном у пользователя
  Future<bool> isProductInFavorites(int userId, int productId);

  /// Добавить товар в избранное
  Future<int> addToFavorites(int userId, int productId);

  /// Удалить товар из избранного
  Future<void> removeFromFavorites(int userId, int productId);

  /// Очистить все избранное пользователя
  Future<void> clearUserFavorites(int userId);

  /// Получить количество товаров в избранном у пользователя
  Future<int> getUserFavoritesCount(int userId);
}
