import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';
import '../../core/exceptions/app_exceptions.dart' as app_exceptions;
import '../../domain/entities/product_characteristic.dart';

class ProductLocalDataSource {
  final DatabaseHelper dbHelper;

  ProductLocalDataSource(this.dbHelper);

  Future<List<ProductModel>> getAllProducts({
    String? searchQuery,
    int? categoryId,
    String? sortBy,
    int? limit,
    int? offset,
  }) async {
    try {
      final db = await dbHelper.database;
      // Количество берём из поля Products.stock или из Stock.Quantity
      var query = '''
        SELECT 
          p.*,
          COALESCE(p.stock, s.Quantity, 0) as quantity,
          pi.image as image_path
        FROM Products p 
        LEFT JOIN Stock s ON p.id = s.ProductId
        LEFT JOIN ProductImages pi ON pi.product_id = p.id AND pi.is_main = 1
        WHERE 1=1
      ''';
      final List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query += ' AND (p.name LIKE ? OR p.sku LIKE ?)';
        final searchPattern = '%$searchQuery%';
        whereArgs.addAll([searchPattern, searchPattern]);
      }

      if (categoryId != null) {
        query += ' AND p.category_id = ?';
        whereArgs.add(categoryId);
      }

      if (sortBy != null) {
        switch (sortBy) {
          case 'name':
            query += ' ORDER BY p.Name ASC';
            break;
          case 'price':
            query += ' ORDER BY p.Price ASC';
            break;
          case 'quantity':
            query += ' ORDER BY quantity ASC';
            break;
          default:
            query += ' ORDER BY p.id DESC';
        }
      } else {
        query += ' ORDER BY p.id DESC';
      }

      if (limit != null) {
        query += ' LIMIT ?';
        whereArgs.add(limit);
        if (offset != null) {
          query += ' OFFSET ?';
          whereArgs.add(offset);
        }
      }

      final maps = await db.rawQuery(query, whereArgs);
      return maps.map((map) => ProductModel.fromJson(map)).toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить товары: $e');
    }
  }

  Future<ProductModel?> getProductById(int id) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT 
          p.*,
          COALESCE(p.stock, s.Quantity, 0) as quantity,
          pi.image as image_path
        FROM Products p 
        LEFT JOIN Stock s ON p.id = s.ProductId 
        LEFT JOIN ProductImages pi 
          ON pi.product_id = p.id AND pi.is_main = 1
        WHERE p.id = ?
      ''', [id]);
      if (maps.isEmpty) return null;
      return ProductModel.fromJson(maps.first);
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить товар: $e');
    }
  }

  Future<ProductModel?> getProductBySku(String sku) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT 
          p.*,
          COALESCE(p.stock, s.Quantity, 0) as quantity,
          pi.image as image_path
        FROM Products p 
        LEFT JOIN Stock s ON p.id = s.ProductId 
        LEFT JOIN ProductImages pi 
          ON pi.product_id = p.id AND pi.is_main = 1
        WHERE p.sku = ?
      ''', [sku]);
      if (maps.isEmpty) return null;
      return ProductModel.fromJson(maps.first);
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить товар по SKU: $e');
    }
  }

  Future<int> insertProduct(ProductModel product) async {
    try {
      final db = await dbHelper.database;
      final productJson = product.toJson();
      final quantity = productJson.remove('quantity') as int? ?? 0;

      // Записываем количество в поле stock (для текущей схемы БД)
      productJson['stock'] = quantity;
      
      final productId = await db.insert('Products', productJson);
      
      // Таблица Stock может существовать в других схемах, но для текущей не обязательна,
      // поэтому здесь её не трогаем.
      return productId;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось вставить товар: $e');
    }
  }

  Future<int> updateProduct(ProductModel product) async {
    try {
      final db = await dbHelper.database;
      final productJson = product.toJson();
      final quantity = productJson.remove('quantity') as int? ?? 0;

      productJson['stock'] = quantity;
      
      await db.update(
        'Products',
        productJson,
        where: 'id = ?',
        whereArgs: [product.id],
      );
      
      return 1;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось обновить товар: $e');
    }
  }

  Future<int> deleteProduct(int id) async {
    try {
      final db = await dbHelper.database;
      // В текущей схеме количество хранится в Products.stock, поэтому
      // достаточно удалить запись из Products.
      return await db.delete('Products', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось удалить товар: $e');
    }
  }

  Future<List<ProductModel>> getLowStockProducts() async {
    try {
      final db = await dbHelper.database;
      final maps = await db.rawQuery('''
        SELECT 
          p.*,
          COALESCE(p.stock, s.Quantity, 0) as quantity,
          pi.image as image_path
        FROM Products p 
        LEFT JOIN Stock s ON p.id = s.ProductId 
        LEFT JOIN ProductImages pi 
          ON pi.product_id = p.id AND pi.is_main = 1
        WHERE COALESCE(p.stock, s.Quantity, 0) <= 5
        ORDER BY quantity ASC
      ''');
      return maps.map((map) => ProductModel.fromJson(map)).toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить товары с низкими запасами: $e');
    }
  }

  Future<int> getProductCount({String? searchQuery, int? categoryId}) async {
    try {
      final db = await dbHelper.database;
      var query = 'SELECT COUNT(*) as count FROM Products p WHERE 1=1';
      final List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query += ' AND (p.name LIKE ? OR p.sku LIKE ?)';
        final searchPattern = '%$searchQuery%';
        whereArgs.addAll([searchPattern, searchPattern]);
      }

      if (categoryId != null) {
        query += ' AND p.category_id = ?';
        whereArgs.add(categoryId);
      }

      final result = await db.rawQuery(query, whereArgs);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить количество товаров: $e');
    }
  }

  Future<List<ProductCharacteristic>> getCharacteristicsByProduct(int productId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT c.name, c.unit, pc.value
        FROM ProductCharacteristics pc
        INNER JOIN Characteristics c ON pc.characteristic_id = c.id
        WHERE pc.product_id = ?
        ORDER BY c.id
      ''', [productId]);

      return rows
          .map(
            (r) => ProductCharacteristic(
              name: r['name'] as String,
              unit: r['unit'] as String?,
              value: r['value'].toString(),
            ),
          )
          .toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить характеристики: $e');
    }
  }

  Future<void> setProductCharacteristics(
    int productId,
    List<ProductCharacteristic> characteristics,
  ) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        // Удаляем старые связи
        await txn.delete(
          'ProductCharacteristics',
          where: 'product_id = ?',
          whereArgs: [productId],
        );

        for (final c in characteristics) {
          final name = c.name.trim();
          final unit = (c.unit ?? '').trim();
          final value = c.value.trim();
          if (name.isEmpty || value.isEmpty) continue;

          // Вставляем/находим характеристику в справочнике
          await txn.insert(
            'Characteristics',
            {
              'name': name,
              'unit': unit.isEmpty ? null : unit,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          final rows = await txn.query(
            'Characteristics',
            columns: ['id'],
            where: unit.isEmpty ? 'name = ? AND unit IS NULL' : 'name = ? AND unit = ?',
            whereArgs: unit.isEmpty ? [name] : [name, unit],
            limit: 1,
          );
          if (rows.isEmpty) continue;
          final characteristicId = rows.first['id'] as int;

          await txn.insert(
            'ProductCharacteristics',
            {
              'product_id': productId,
              'characteristic_id': characteristicId,
              'value': value,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось сохранить характеристики: $e');
    }
  }
}

