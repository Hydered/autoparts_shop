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

}

