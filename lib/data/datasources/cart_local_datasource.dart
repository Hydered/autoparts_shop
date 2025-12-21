import 'database_helper.dart';
import '../../core/exceptions/app_exceptions.dart' as app_exceptions;

class CartLocalDataSource {
  final DatabaseHelper dbHelper;

  CartLocalDataSource(this.dbHelper);

  /// Получить все товары в корзине пользователя
  Future<List<Map<String, dynamic>>> getCartItems(int? userId) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'CartItems',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );
      return maps;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить корзину: $e');
    }
  }

  /// Получает общее количество зарезервированных товаров по каждому product_id
  /// Суммирует количества из всех корзин всех пользователей
  ///
  /// Используется для расчета доступного количества товаров:
  /// доступное_количество = общее_количество - зарезервированное_количество
  ///
  /// @return Map<productId, totalReservedQuantity> - словарь резервирований по товарам
  Future<Map<int, int>> getReservedQuantities() async {
    try {
      final db = await dbHelper.database;

      // SQL запрос суммирует количества товаров во всех корзинах
      // GROUP BY группирует по product_id для получения итоговых сумм
      final maps = await db.rawQuery('''
        SELECT product_id, SUM(quantity) as total_quantity
        FROM CartItems
        GROUP BY product_id
      ''');

      final Map<int, int> reserved = {};
      for (final map in maps) {
        final productId = map['product_id'] as int;
        final quantity = map['total_quantity'] as int? ?? 0;
        reserved[productId] = quantity;
      }

      return reserved;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить резервированные количества: $e');
    }
  }

  /// Получить количество резервированного товара этим пользователем
  Future<int> getUserReservedQuantity(int productId, int? userId) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'CartItems',
        columns: ['quantity'],
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return maps.first['quantity'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить резерв пользователя: $e');
    }
  }


  /// Добавить товар в корзину
  Future<int> addToCart(int? userId, int productId, int quantity) async {
    try {
      final db = await dbHelper.database;

      // Проверяем, есть ли уже этот товар в корзине
      final existing = await db.query(
        'CartItems',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        // Обновляем количество (просто устанавливаем новое значение, суммирование происходит в SaleProvider)
        await db.update(
          'CartItems',
          {
            'quantity': quantity,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'user_id = ? AND product_id = ?',
          whereArgs: [userId, productId],
        );
        return existing.first['id'] as int;
      } else {
        // Добавляем новый товар
        return await db.insert('CartItems', {
          'user_id': userId,
          'product_id': productId,
          'quantity': quantity,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось добавить товар в корзину: $e');
    }
  }

  /// Обновить количество товара в корзине
  Future<void> updateCartItemQuantity(int? userId, int productId, int quantity) async {
    try {
      final db = await dbHelper.database;
      if (quantity <= 0) {
        await db.delete(
          'CartItems',
          where: 'user_id = ? AND product_id = ?',
          whereArgs: [userId, productId],
        );
      } else {
        await db.update(
          'CartItems',
          {
            'quantity': quantity,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'user_id = ? AND product_id = ?',
          whereArgs: [userId, productId],
        );
      }
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось обновить корзину: $e');
    }
  }

  /// Удалить товар из корзины
  Future<void> removeFromCart(int? userId, int productId) async {
    try {
      final db = await dbHelper.database;
      await db.delete(
        'CartItems',
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, productId],
      );
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось удалить товар из корзины: $e');
    }
  }

  /// Очистить корзину пользователя
  Future<void> clearCart(int? userId) async {
    try {
      final db = await dbHelper.database;
      await db.delete(
        'CartItems',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось очистить корзину: $e');
    }
  }

  /// Автоматическая очистка просроченных корзин (> 24 часов)
  /// Освобождает зарезервированные товары от старых, забытых корзин
  ///
  /// Логика работы:
  /// 1. Находит все записи корзины старше 24 часов
  /// 2. Возвращает список удаляемых товаров (для освобождения резервирований)
  /// 3. Удаляет просроченные записи из базы данных
  ///
  /// @return список удаленных записей с product_id и quantity
  Future<List<Map<String, dynamic>>> removeExpiredCartItems() async {
    try {
      final db = await dbHelper.database;

      // Вычисляем timestamp для 24 часов назад
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      final oneDayAgoTimestamp = oneDayAgo.millisecondsSinceEpoch;

      // Сначала получаем список удаляемых товаров (для уведомления системы)
      final expiredItems = await db.query(
        'CartItems',
        where: 'created_at < ?',
        whereArgs: [oneDayAgoTimestamp],
      );

      // Удаляем просроченные записи из базы данных
      await db.delete(
        'CartItems',
        where: 'created_at < ?',
        whereArgs: [oneDayAgoTimestamp],
      );

      return expiredItems;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось удалить просроченные товары из корзины: $e');
    }
  }
}
