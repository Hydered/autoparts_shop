import 'package:flutter/foundation.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/services/inventory_service.dart';
import '../../core/exceptions/app_exceptions.dart';

import 'product_provider.dart';

class SaleProvider with ChangeNotifier {
  Future<void> clearClientHistory(int userId) async {
    await saleRepository.clearClientHistory(userId);
    await loadSales(refresh: true, userId: userId);
  }
  ProductProvider? productProvider;

  void connectProductProvider(ProductProvider provider) {
    productProvider = provider;
  }

  final SaleRepository saleRepository;
  final InventoryService inventoryService;

  SaleProvider(this.saleRepository, this.inventoryService);

  List<Sale> _sales = [];
  List<Sale> get sales => _sales;

  List<SaleItem> _cart = [];
  List<SaleItem> get cart => _cart;

  double get cartTotal => _cart.fold(0.0, (sum, item) => sum + item.totalPrice);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  Future<void> loadSales({bool refresh = false, int? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sales = await saleRepository.getAllSales(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
        userId: userId,
      );
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

  Future<void> filterSalesByDate(DateTime? startDate, DateTime? endDate) async {
    _filterStartDate = startDate;
    _filterEndDate = endDate;
    await loadSales(refresh: true);
  }

  Future<double> getDailySalesTotal(DateTime date) async {
    try {
      return await saleRepository.getDailySalesTotal(date);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0.0;
    }
  }

  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 3}) async {
    try {
      return await saleRepository.getBestSellingProducts(limit: limit);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  void addToCart(SaleItem item) {
    // Реальное резервирование товара (уменьшаем)
    productProvider?.reserveQuantity(item.product.id!, item.quantity);
    final existingIndex = _cart.indexWhere((cartItem) => cartItem.product.id == item.product.id);
    if (existingIndex >= 0) {
      final existingItem = _cart[existingIndex];
      _cart[existingIndex] = SaleItem(
        product: existingItem.product,
        quantity: existingItem.quantity + item.quantity,
      );
    } else {
      _cart.add(item);
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    final removed = _cart[index];
    productProvider?.restoreQuantity(removed.product.id!, removed.quantity);
    _cart.removeAt(index);
    notifyListeners();
  }

  void updateCartItemQuantity(int index, int quantity) {
    final oldQty = _cart[index].quantity;
    final productId = _cart[index].product.id!;
    if (quantity > oldQty) {
      productProvider?.reserveQuantity(productId, quantity - oldQty);
    } else if (quantity < oldQty) {
      productProvider?.restoreQuantity(productId, oldQty - quantity);
    }
    if (quantity <= 0) {
      _cart.removeAt(index);
    } else {
      final item = _cart[index];
      _cart[index] = SaleItem(
        product: item.product,
        quantity: quantity,
      );
    }
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<bool> completeSale(int userId, String? customerName, String? notes) async {
    if (_cart.isEmpty) {
      _error = 'Cart is empty';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now();

      for (final item in _cart) {
        await inventoryService.validateSale(item.product.id!, item.quantity);
      }

      for (final item in _cart) {
        final sale = Sale(
          userId: userId,
          productId: item.product.id!,
          quantity: item.quantity,
          unitPrice: item.product.price,
          totalPrice: item.totalPrice,
          saleDate: now,
          customerName: customerName,
          notes: notes,
        );

        await saleRepository.insertSale(sale);
        await inventoryService.updateStockAfterSale(item.product.id!, item.quantity);
      }

      _cart.clear();
      await loadSales(refresh: true, userId: userId);
      return true;
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

