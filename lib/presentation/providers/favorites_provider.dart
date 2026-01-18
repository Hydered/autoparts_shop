import 'package:flutter/foundation.dart';
import '../../domain/entities/favorite.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/exceptions/app_exceptions.dart';
import 'product_provider.dart';

class FavoritesProvider with ChangeNotifier {
  final FavoritesRepository favoritesRepository;
  final ProductRepository productRepository;
  ProductProvider? _productProvider;

  FavoritesProvider(this.favoritesRepository, this.productRepository);

  void setProductProvider(ProductProvider productProvider) {
    _productProvider = productProvider;
  }

  List<Favorite> _favorites = [];
  List<Favorite> get favorites => _favorites;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Загрузить избранные товары пользователя с деталями продуктов
  Future<List<Product>> loadUserFavorites(int userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userFavorites = await favoritesRepository.getUserFavorites(userId);
      _favorites = userFavorites;

      // Получаем детали товаров для отображения из ProductProvider (с актуальными резервированиями)
      final List<Product> favoriteProducts = [];
      if (_productProvider != null) {
        for (final favorite in userFavorites) {
          try {
            // Ищем товар в уже загруженных товарах ProductProvider
            try {
              final product = _productProvider!.products.firstWhere(
                (p) => p.id == favorite.productId,
              );
              favoriteProducts.add(product);
            } catch (e) {
              // Если товар не найден в ProductProvider, загружаем из базы
              final dbProduct = await productRepository.getProductById(favorite.productId);
              if (dbProduct != null) {
                favoriteProducts.add(dbProduct);
              }
            }
          } catch (e) {
            // Пропускаем товары, которые не удалось загрузить
            print('Не удалось загрузить товар ${favorite.productId}: $e');
          }
        }
      } else {
        // Fallback: загружаем из базы данных
        for (final favorite in userFavorites) {
          try {
            final product = await productRepository.getProductById(favorite.productId);
            if (product != null) {
              favoriteProducts.add(product);
            }
          } catch (e) {
            print('Не удалось загрузить товар ${favorite.productId}: $e');
          }
        }
      }

      _error = null;
      return favoriteProducts;
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Проверить, находится ли товар в избранном
  Future<bool> isProductInFavorites(int userId, int productId) async {
    try {
      return await favoritesRepository.isProductInFavorites(userId, productId);
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return false;
    }
  }

  /// Добавить товар в избранное
  Future<bool> addToFavorites(int userId, int productId) async {
    try {
      await favoritesRepository.addToFavorites(userId, productId);

      // Обновляем локальный список, если он загружен
      if (_favorites.isNotEmpty) {
        final newFavorite = Favorite.create(
          userId: userId,
          productId: productId,
        );
        _favorites.add(newFavorite);
        notifyListeners();
      }

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return false;
    }
  }

  /// Удалить товар из избранного
  Future<bool> removeFromFavorites(int userId, int productId) async {
    try {
      await favoritesRepository.removeFromFavorites(userId, productId);

      // Обновляем локальный список
      _favorites.removeWhere((f) => f.productId == productId);
      notifyListeners();

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return false;
    }
  }

  /// Очистить все избранное пользователя
  Future<bool> clearUserFavorites(int userId) async {
    try {
      await favoritesRepository.clearUserFavorites(userId);

      // Очищаем локальный список
      _favorites.clear();
      notifyListeners();

      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return false;
    }
  }

  /// Получить количество товаров в избранном
  Future<int> getUserFavoritesCount(int userId) async {
    try {
      return await favoritesRepository.getUserFavoritesCount(userId);
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return 0;
    }
  }

  /// Переключить статус избранного товара (добавить/удалить)
  Future<bool> toggleFavorite(int userId, int productId) async {
    final isInFavorites = await isProductInFavorites(userId, productId);

    if (isInFavorites) {
      return await removeFromFavorites(userId, productId);
    } else {
      return await addToFavorites(userId, productId);
    }
  }

  /// Очистить ошибку
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
