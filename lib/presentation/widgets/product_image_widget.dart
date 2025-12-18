import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ProductImageWidget({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildPlaceholder();
    }

    // Если путь начинается с /, это абсолютный путь к файлу
    if (imagePath!.startsWith('/')) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      // Если файл не существует, возвращаем placeholder
      return _buildPlaceholder();
    }

    // Если путь содержит обратные слэши (Windows путь) или выглядит как путь к файлу
    if (imagePath!.contains('\\') || 
        (imagePath!.contains('/') && !imagePath!.startsWith('assets/'))) {
      // Пытаемся проверить, существует ли файл
      try {
        final file = File(imagePath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
      } catch (e) {
        // Если не удалось проверить, пробуем как asset
      }
    }

    // Во всех остальных случаях пытаемся загрузить как asset
    // Поддерживаем разные форматы путей:
    // - assets/images/product.jpg
    // - assets/product.jpg
    // - images/product.jpg
    // - product.jpg
    
    List<String> possiblePaths = [];
    
    if (imagePath!.startsWith('assets/')) {
      // Уже полный путь к asset
      possiblePaths.add(imagePath!);
    } else if (imagePath!.startsWith('images/')) {
      // Путь начинается с images/
      possiblePaths.add('assets/${imagePath!}');
      possiblePaths.add(imagePath!);
    } else {
      // Просто имя файла или относительный путь
      possiblePaths.add('assets/images/${imagePath!}');
      possiblePaths.add('assets/${imagePath!}');
      possiblePaths.add('images/${imagePath!}');
      possiblePaths.add(imagePath!);
    }

    // Пробуем загрузить по каждому возможному пути
    return _tryLoadAsset(possiblePaths, 0);
  }

  Widget _tryLoadAsset(List<String> paths, int index) {
    if (index >= paths.length) {
      return _buildPlaceholder();
    }

    return Image.asset(
      paths[index],
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Пробуем следующий путь
        return _tryLoadAsset(paths, index + 1);
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.background,
      child: const Icon(
        Icons.image_outlined,
        size: 40,
        color: AppColors.textSecondary,
      ),
    );
  }
}

