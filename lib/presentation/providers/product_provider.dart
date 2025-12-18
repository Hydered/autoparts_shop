import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/exceptions/app_exceptions.dart';

class ProductProvider with ChangeNotifier {
  // Резервирует в памяти заданное количество товара (для отображения актуального остатка)
  void reserveQuantity(int productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final current = _products[index];
      _products[index] = current.copyWith(quantity: (current.quantity - quantity).clamp(0, 1000000));
      notifyListeners();
    }
  }

  // Возвращает указанное количество товара обратно в память
  void restoreQuantity(int productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final current = _products[index];
      _products[index] = current.copyWith(quantity: current.quantity + quantity);
      notifyListeners();
    }
  }

  final ProductRepository productRepository;

  ProductProvider(this.productRepository);

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

  Future<void> loadProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 0;
      _hasMore = true;
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

      if (refresh) {
        _products = newProducts;
      } else {
        _products.addAll(newProducts);
      }

      _hasMore = newProducts.length == _pageSize;
      _currentPage++;

      _error = null;
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

