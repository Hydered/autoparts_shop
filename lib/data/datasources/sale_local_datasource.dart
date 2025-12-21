import 'package:sqflite/sqflite.dart';
import '../models/sale_model.dart';
import 'database_helper.dart';
import '../../core/exceptions/app_exceptions.dart' as app_exceptions;

class SaleLocalDataSource {
  final DatabaseHelper dbHelper;

  SaleLocalDataSource(this.dbHelper);

  Future<void> clearClientHistory(int userId) async {
    final db = await dbHelper.database;
    // Просто помечаем продажи как скрытые для клиента, не удаляем!
    await db.rawUpdate('UPDATE Sales SET client_deleted_history = 1 WHERE user_id = ?', [userId]);
  }

  Future<List<SaleModel>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await dbHelper.database;
      var query = '''
        SELECT 
          s.id as id,
          s.created_at as created_at,
          s.order_number as order_number,
          s.total_price as total_price,
          s.status as status,
          s.user_id as user_id,
          s.CustomerName as customer_name,
          s.Notes as notes,
          si.product_id as product_id,
          si.quantity as quantity,
          si.price as unit_price
        FROM Sales s
        INNER JOIN SaleItems si ON s.id = si.sale_id
        WHERE 1=1
      ''';
      final List<dynamic> whereArgs = [];

      if (startDate != null) {
        query += ' AND s.created_at >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        query += ' AND s.created_at <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }
      if (userId != null) {
        query += ' AND s.user_id = ?';
        whereArgs.add(userId);
        // Показываем только те, которые клиент не скрыл
        query += ' AND (s.client_deleted_history IS NULL OR s.client_deleted_history = 0)';
      }

      query += ' ORDER BY s.created_at DESC';

      if (limit != null) {
        query += ' LIMIT ?';
        whereArgs.add(limit);
        if (offset != null) {
          query += ' OFFSET ?';
          whereArgs.add(offset);
        }
      }

      final maps = await db.rawQuery(query, whereArgs);
      return maps.map((map) => SaleModel.fromJson(map)).toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить продажи: $e');
    }
  }

  Future<SaleModel?> getSaleById(int id) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT 
          s.id as id,
          s.created_at as created_at,
          s.order_number as order_number,
          s.total_price as total_price,
          s.status as status,
          s.user_id as user_id,
          s.CustomerName as customer_name,
          s.Notes as notes,
          si.product_id as product_id,
          si.quantity as quantity,
          si.price as unit_price
        FROM Sales s
        INNER JOIN SaleItems si ON s.id = si.sale_id
        WHERE s.id = ?
        LIMIT 1
      ''', [id]);
      if (maps.isEmpty) return null;
      return SaleModel.fromJson(maps.first);
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Failed to get sale: $e');
    }
  }

  Future<int> insertSale(SaleModel sale) async {
    try {
      final db = await dbHelper.database;
      
      // Вставляем продажу в таблицу Sales
      final saleId = await db.insert('Sales', {
        'created_at': sale.saleDate.millisecondsSinceEpoch,
        'user_id': sale.userId,
        'status': 'completed',
        'order_number': sale.orderNumber ?? '',
        'total_price': sale.totalPrice,
        'CustomerName': sale.customerName,
        'Notes': sale.notes,
      });
      
      // Вставляем элемент продажи в SaleItems
      await db.insert('SaleItems', {
        'sale_id': saleId,
        'product_id': sale.productId,
        'quantity': sale.quantity,
        'price': sale.unitPrice,
      });
      
      return saleId;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Failed to insert sale: $e');
    }
  }

  Future<double> getDailySalesTotal(DateTime date) async {
    try {
      final db = await dbHelper.database;
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final result = await db.rawQuery('''
        SELECT SUM(si.quantity * si.price) as total 
        FROM Sales s
        INNER JOIN SaleItems si ON s.id = si.sale_id
        WHERE s.created_at >= ? AND s.created_at <= ?
      ''', [startOfDay.millisecondsSinceEpoch, endOfDay.millisecondsSinceEpoch]);
      
      return (result.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить общий объем ежедневных продаж: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 3}) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery('''
        SELECT 
          p.id as id,
          p.name as name,
          p.sku as sku,
          SUM(si.quantity) as total_sold,
          SUM(si.quantity * si.price) as total_revenue
        FROM SaleItems si
        INNER JOIN Products p ON si.product_id = p.id
        GROUP BY p.id, p.name, p.sku
        ORDER BY total_sold DESC
        LIMIT ?
      ''', [limit]);
      
      return result;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить самые продаваемые товары: $e');
    }
  }

  Future<int> getSalesCount({DateTime? startDate, DateTime? endDate}) async {
    try {
      final db = await dbHelper.database;
      var query = 'SELECT COUNT(DISTINCT s.id) as count FROM Sales s WHERE 1=1';
      final List<dynamic> whereArgs = [];

      if (startDate != null) {
        query += ' AND s.created_at >= ?';
        whereArgs.add(startDate.millisecondsSinceEpoch);
      }

      if (endDate != null) {
        query += ' AND s.created_at <= ?';
        whereArgs.add(endDate.millisecondsSinceEpoch);
      }

      final result = await db.rawQuery(query, whereArgs);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить количество продаж: $e');
    }
  }

  Future<List<SaleModel>> getSalesByOrderNumber(String orderNumber, int userId, {bool ignoreClientDeletedHistory = false}) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT
          s.id as id,
          s.created_at as created_at,
          s.order_number as order_number,
          s.total_price as total_price,
          s.status as status,
          s.user_id as user_id,
          s.CustomerName as customer_name,
          s.Notes as notes,
          si.product_id as product_id,
          si.quantity as quantity,
          si.price as unit_price
        FROM Sales s
        INNER JOIN SaleItems si ON s.id = si.sale_id
        WHERE s.order_number = ? AND s.user_id = ?
        ${ignoreClientDeletedHistory ? '' : 'AND (s.client_deleted_history IS NULL OR s.client_deleted_history = 0)'}
        ORDER BY s.created_at DESC
      ''', [orderNumber, userId]);
      return maps.map((map) => SaleModel.fromJson(map)).toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить продажи по номеру заказа: $e');
    }
  }
}
