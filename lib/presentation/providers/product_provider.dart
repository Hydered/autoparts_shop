import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../core/exceptions/app_exceptions.dart';

class ProductProvider with ChangeNotifier {
  /// Резервирует количество товара в памяти для отображения актуального остатка
  /// Вызывается когда товар добавляется в корзину любого пользователя
  ///
  /// @param productId - ID товара
  /// @param quantity - количество для резервирования
  void reserveQuantity(int productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final current = _products[index];
      // Уменьшаем доступное количество товара
      // clamp(0, 1000000) предотвращает отрицательные значения
      _products[index] = current.copyWith(quantity: (current.quantity - quantity).clamp(0, 1000000));
      notifyListeners();
    }
  }

  /// Возвращает зарезервированное количество товара обратно в доступное
  /// Вызывается при удалении товара из корзины
  ///
  /// @param productId - ID товара
  /// @param quantity - количество для возврата
  void restoreQuantity(int productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final current = _products[index];
      // Увеличиваем доступное количество товара
      _products[index] = current.copyWith(quantity: current.quantity + quantity);
      notifyListeners();
    }
  }

  /// Сбрасывает все резервирования товаров к оригинальным количествам из базы данных
  /// Используется перед повторным применением резервирований
  /// В отличие от старой версии, не перезагружает продукты из БД (избегает мерцания UI)
  void resetReservations() {
    // Восстанавливаем оригинальные количества из сохраненного кэша
    for (int i = 0; i < _products.length; i++) {
      final product = _products[i];
      if (product.id != null && _originalQuantities.containsKey(product.id)) {
        _products[i] = product.copyWith(quantity: _originalQuantities[product.id]!);
      }
    }
    _reservationsApplied = false;
    notifyListeners();
  }

  // Устанавливает флаг примененных резервирований
  void setReservationsApplied(bool applied) {
    _reservationsApplied = applied;
  }

  // Проверяет, были ли применены резервирования
  bool get reservationsApplied => _reservationsApplied;

  final ProductRepository productRepository;
  CartRepository? cartRepository;

  ProductProvider(this.productRepository, [this.cartRepository]);

  void setCartRepository(CartRepository repository) {
    cartRepository = repository;
  }

  /// (UI-agnostic!) Только для совместимости, ничего не делает!
  Future<void> refreshAvailableQuantities([int? currentUserId]) async {
    // Больше не нужно менять остатки товаров вручную -- теперь quantity product всегда "реальный склад"!
    notifyListeners();
  }

  /// Возвращает реальный доступный остаток товара для текущего клиента (его резерв не вычитается)
  Future<int> getAvailableForUser(int productId, int? userId) async {
    final product = await productRepository.getProductById(productId);
    if (product == null) return 0;
    final reserved = (await cartRepository?.getReservedQuantities() ?? {})[productId] ?? 0;
    int reservedByMe = 0;
    if (userId != null) {
      reservedByMe = await cartRepository?.getUserReservedQuantity(productId, userId) ?? 0;
    }
    final available = product.quantity - (reserved - reservedByMe);
    return available < 0 ? 0 : available;
  }


  List<Product> _products = [];
  List<Product> get products => _products;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int? _selectedCategoryId;
  int? get selectedCategoryId => _selectedCategoryId;

  String _sortBy = 'created_at';
  String get sortBy => _sortBy;

  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _reservationsApplied = false;

  // Храним оригинальные количества товаров для быстрого сброса резервирований
  final Map<int, int> _originalQuantities = {};

  Future<void> loadProducts({bool refresh = false, dynamic saleProvider, int? currentUserId}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
      // Сбрасываем флаг примененных резервирований при перезагрузке
      _reservationsApplied = false;
    }

    if (!_hasMore && !refresh) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newProducts = await productRepository.getAllProducts(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        categoryId: _selectedCategoryId,
        sortBy: _sortBy,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
      );

      // Всегда загружаем реальные количества из базы данных
      // Резервирования товаров будут применены позже через in-memory изменения
      if (refresh) {
        // Полная замена списка продуктов
        _products = newProducts;
        // Сохраняем оригинальные количества для быстрого сброса резервирований
        _originalQuantities.clear();
        for (final product in newProducts) {
          if (product.id != null) {
            _originalQuantities[product.id!] = product.quantity;
          }
        }
      } else {
        // Добавление к существующему списку (пагинация)
        _products.addAll(newProducts);
        // Сохраняем оригинальные количества для новых загруженных продуктов
        for (final product in newProducts) {
          if (product.id != null) {
            _originalQuantities[product.id!] = product.quantity;
          }
        }
      }

      _hasMore = newProducts.length == _pageSize;
      _currentPage++;

      _error = null;

      // Применяем резервирования из корзины после загрузки товаров
      if (saleProvider != null && refresh) {
        try {
          await saleProvider.applyCartReservationsToProducts(currentUserId: currentUserId);
        } catch (e) {
          print('Ошибка применения резервирований: $e');
        }
      }
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    await loadProducts(refresh: true);
  }

  Future<void> filterByCategory(int? categoryId) async {
    _selectedCategoryId = categoryId;
    await loadProducts(refresh: true);
  }

  Future<void> sortProducts(String sortBy) async {
    _sortBy = sortBy;
    await loadProducts(refresh: true);
  }

  void setSelectedCategoryId(int? categoryId) {
    _selectedCategoryId = categoryId;
    loadProducts(refresh: true);
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    loadProducts(refresh: true);
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _sortBy = 'created_at';
    loadProducts(refresh: true);
  }

  Future<Product?> getProductById(int id) async {
    try {
      return await productRepository.getProductById(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> addProduct(Product product) async {
    try {
      await productRepository.insertProduct(product);
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product product) async {
    try {
      await productRepository.updateProduct(product);
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addProductWithCharacteristics(
    Product product,
    List<ProductCharacteristic> characteristics,
  ) async {
    try {
      final productId = await productRepository.insertProduct(product);
      await productRepository.setProductCharacteristics(productId, characteristics);
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProductWithCharacteristics(
    Product product,
    List<ProductCharacteristic> characteristics,
  ) async {
    try {
      await productRepository.updateProduct(product);
      final id = product.id;
      if (id != null) {
        await productRepository.setProductCharacteristics(id, characteristics);
      }
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(int id) async {
    try {
      await productRepository.deleteProduct(id);
      await loadProducts(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Product>> getLowStockProducts() async {
    try {
      return await productRepository.getLowStockProducts();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<List<ProductCharacteristic>> getCharacteristicsByProduct(int productId) async {
    try {
      return await productRepository.getCharacteristicsByProduct(productId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }
}

