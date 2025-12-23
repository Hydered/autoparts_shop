import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('autoparts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 10);
  }
}

Future<void> main() async {
  // Обновим пути к изображениям товаров в базе данных
  try {
    final db = await DatabaseHelper.instance.database;
    final products = await db.query('Products');
    print('Найдено товаров: ${products.length}');

    int updatedCount = 0;
    for (final product in products) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final id = product['id'];
      final currentImage = product['image_url'];

      print('Товар: ${product['name']}, текущее изображение: $currentImage');

      String? imagePath;
      if (name.contains('gates') && name.contains('ремень')) {
        imagePath = 'assets/images/gates_grm_1.png';
      } else if (name.contains('bosch') && name.contains('масляный')) {
        imagePath = 'assets/images/bosch_filter_2.png';
      } else if (name.contains('bosch') && name.contains('фильтр')) {
        imagePath = 'assets/images/bosch_filter_1.png';
      } else if (name.contains('ate') && name.contains('диск')) {
        imagePath = 'assets/images/ate_disc_1.png';
      } else if (name.contains('ate') && name.contains('тормозной')) {
        imagePath = 'assets/images/ate_brake_1.png';
      } else if (name.contains('kyb') && name.contains('амортизатор')) {
        imagePath = 'assets/images/kyb_amort_1.png';
      } else if (name.contains('mann') && name.contains('фильтр')) {
        imagePath = 'assets/images/mann_filter_1.png';
      }

      if (imagePath != null && currentImage != imagePath) {
        await db.update(
          'Products',
          {'image_url': imagePath},
          where: 'id = ?',
          whereArgs: [id],
        );
        print('✓ Обновлено: ${product['name']} -> $imagePath');
        updatedCount++;
      }
    }

    print('Всего обновлено изображений: $updatedCount');

    // Проверим результат
    print('\nПроверка результатов:');
    final updatedProducts = await db.query('Products', where: 'image_url IS NOT NULL');
    for (final product in updatedProducts) {
      print('${product['name']}: ${product['image_url']}');
    }

  } catch (e) {
    print('Ошибка: $e');
  }
}
