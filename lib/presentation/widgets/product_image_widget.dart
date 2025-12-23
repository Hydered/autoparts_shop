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

  /// Возвращает исправленный путь к изображению
  String? _getCorrectImagePath(String? path) {
    if (path == null || path.isEmpty) return null;

    // Если путь уже правильный, возвращаем как есть
    if (path.startsWith('assets/images/')) {
      return path;
    }

    // Простая логика: если это просто имя файла, добавляем assets/images/
    if (!path.startsWith('assets/') && !path.startsWith('/')) {
      return 'assets/images/$path';
    }

    return path;
  }

  @override
  Widget build(BuildContext context) {
    // Исправляем путь к изображению
    final correctedPath = _getCorrectImagePath(imagePath);

    if (correctedPath == null || correctedPath.isEmpty) {
      return _buildPlaceholder();
    }

    // Если путь начинается с /, это абсолютный путь к файлу
    if (correctedPath.startsWith('/')) {
      final file = File(correctedPath);
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
    if (correctedPath.contains('\\') ||
        (correctedPath.contains('/') && !correctedPath.startsWith('assets/'))) {
      // Пытаемся проверить, существует ли файл
      try {
        final file = File(correctedPath);
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
    return Image.asset(
      correctedPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
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

