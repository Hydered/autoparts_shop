import 'database_helper.dart';
import '../../core/exceptions/app_exceptions.dart' as app_exceptions;
import '../../domain/entities/favorite.dart';

class FavoritesLocalDataSource {
  final DatabaseHelper dbHelper;

  FavoritesLocalDataSource(this.dbHelper);

  /// Получить все избранные товары пользователя
  Future<List<Favorite>> getUserFavorites(int userId) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'Favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return maps.map((map) => Favorite.fromMap(map)).toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить избранное: $e');
    }
  }

  /// Проверить, находится ли товар в избранном у пользователя
  Future<bool> isProductInFavorites(int userId, int productId) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'Favorites',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
        limit: 1,
      );
      return maps.isNotEmpty;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось проверить избранное: $e');
    }
  }

  /// Добавить товар в избранное
  Future<int> addToFavorites(int userId, int productId) async {
    try {
      final db = await dbHelper.database;

      // Проверяем, не добавлен ли уже этот товар
      final existing = await db.query(
        'Favorites',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        return existing.first['id'] as int;
      }

      // Добавляем новый товар в избранное
      final favorite = Favorite.create(
        userId: userId,
        productId: productId,
      );

      return await db.insert('Favorites', favorite.toMap());
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось добавить товар в избранное: $e');
    }
  }

  /// Удалить товар из избранного
  Future<void> removeFromFavorites(int userId, int productId) async {
    try {
      final db = await dbHelper.database;
      await db.delete(
        'Favorites',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
      );
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось удалить товар из избранного: $e');
    }
  }

  /// Очистить все избранное пользователя
  Future<void> clearUserFavorites(int userId) async {
    try {
      final db = await dbHelper.database;
      await db.delete(
        'Favorites',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось очистить избранное: $e');
    }
  }

  /// Получить количество товаров в избранном у пользователя
  Future<int> getUserFavoritesCount(int userId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM Favorites WHERE user_id = ?',
        [userId],
      );
      return result.first['count'] as int? ?? 0;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить количество избранного: $e');
    }
  }
}
