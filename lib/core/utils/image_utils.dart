import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUtils {
  /// Сохраняет изображение в локальное хранилище приложения
  /// Возвращает путь к сохраненному файлу
  static Future<String> saveImage(File imageFile, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(directory.path, 'product_images'));
      
      // Создаем директорию, если её нет
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // Копируем файл в директорию приложения
      final savedFile = File(path.join(imagesDir.path, fileName));
      await imageFile.copy(savedFile.path);
      
      return savedFile.path;
    } catch (e) {
      throw Exception('Не удалось сохранить изображение: $e');
    }
  }

  /// Удаляет изображение по пути
  static Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    
    // Удаляем только локальные файлы, не asset изображения
    if (!imagePath.startsWith('assets/')) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Игнорируем ошибки удаления
      }
    }
  }

  /// Генерирует уникальное имя файла на основе SKU товара
  static String generateFileName(String sku, {String? extension}) {
    final ext = extension ?? 'jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${sku}_$timestamp.$ext';
  }

  /// Проверяет, является ли путь asset изображением
  static bool isAssetImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    // Если путь начинается с assets/, это точно asset
    if (imagePath.startsWith('assets/')) return true;
    
    // Если это абсолютный путь к файлу, это не asset
    if (imagePath.startsWith('/')) return false;
    
    // Если файл существует как локальный файл, это не asset
    try {
      final file = File(imagePath);
      if (file.existsSync()) return false;
    } catch (e) {
      // Если не удалось проверить, считаем что это может быть asset
    }
    
    // Если путь не содержит слэшей и не является абсолютным путем, 
    // скорее всего это asset (например, просто имя файла из assets)
    return !imagePath.contains('/') || imagePath.contains('assets/');
  }
}

