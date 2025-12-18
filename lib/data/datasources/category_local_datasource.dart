import '../models/category_model.dart';
import 'database_helper.dart';
import '../../core/exceptions/app_exceptions.dart' as app_exceptions;

class CategoryLocalDataSource {
  final DatabaseHelper dbHelper;

  CategoryLocalDataSource(this.dbHelper);

  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query('Categories', orderBy: 'Name ASC');
      return maps.map((map) => CategoryModel.fromJson(map)).toList();
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить категории: $e');
    }
  }

  Future<CategoryModel?> getCategoryById(int id) async {
    try {
      final db = await dbHelper.database;
      final maps = await db.query(
        'Categories',
        where: 'Id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return CategoryModel.fromJson(maps.first);
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось получить категорию: $e');
    }
  }

  Future<int> insertCategory(CategoryModel category) async {
    try {
      final db = await dbHelper.database;
      return await db.insert('Categories', category.toJson());
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось вставить категорию: $e');
    }
  }

  Future<int> updateCategory(CategoryModel category) async {
    try {
      final db = await dbHelper.database;
      return await db.update(
        'Categories',
        category.toJson(),
        where: 'Id = ?',
        whereArgs: [category.id],
      );
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось обновить категорию: $e');
    }
  }

  Future<int> deleteCategory(int id) async {
    try {
      final db = await dbHelper.database;
      return await db.delete(
        'Categories',
        where: 'Id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw app_exceptions.AppDatabaseException('Не удалось удалить категорию: $e');
    }
  }
}

