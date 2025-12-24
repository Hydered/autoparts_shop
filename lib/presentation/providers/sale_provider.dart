import 'package:flutter/foundation.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/services/inventory_service.dart';
import '../../domain/services/receipt_service.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/order_number_generator.dart';

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
  final CartRepository cartRepository;
  final ProductRepository? productRepository;

  SaleProvider(this.saleRepository, this.inventoryService, this.cartRepository, [this.productRepository]);

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

  // Кэш зарезервированных количеств для оптимизации
  Map<int, int> _reservedQuantitiesCache = {};
  DateTime? _lastReservedQuantitiesUpdate;

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

  /// Очистить просроченные корзины (старше 24 часов) и вернуть товары в доступное количество
  /// Возвращает количество удаленных товаров
  /// Получить зарезервированное количество товара из кэша
  int getReservedQuantityFromCache(int productId) {
    return _reservedQuantitiesCache[productId] ?? 0;
  }

  /// Обновить кэш зарезервированных количеств и вернуть его
  Future<Map<int, int>> _updateReservedQuantitiesCache() async {
    try {
      _reservedQuantitiesCache = await cartRepository.getReservedQuantities();
      _lastReservedQuantitiesUpdate = DateTime.now();
      return _reservedQuantitiesCache;
    } catch (e) {
      // В случае ошибки оставляем старый кэш
      debugPrint('Error updating reserved quantities cache: $e');
      return _reservedQuantitiesCache;
    }
  }

  /// Получить зарезервированное количество с обновлением кэша при необходимости
  Future<int> getReservedQuantity(int productId) async {
    // Обновляем кэш каждые 30 секунд или если его нет
    if (_lastReservedQuantitiesUpdate == null ||
        DateTime.now().difference(_lastReservedQuantitiesUpdate!) > const Duration(seconds: 30)) {
      await _updateReservedQuantitiesCache();
    }
    return _reservedQuantitiesCache[productId] ?? 0;
  }

  /// Получить общее зарезервированное количество товара из всех корзин
  int getTotalReservedQuantity(int productId) {
    final reservedInCart = _cart
        .where((item) => item.product.id == productId)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    return reservedInCart;
  }

  /// Применяет резервирования товаров из всех корзин к списку продуктов
  /// Это нужно для корректного отображения доступного количества товаров
  ///
  /// Логика работы:
  /// 1. Сбрасывает все текущие резервирования (восстанавливает оригинальные количества)
  /// 2. Загружает резервирования из базы данных (всех пользователей)
  /// 3. Исключает резервирования текущего пользователя (они будут из _cart)
  /// 4. Применяет резервирования из базы данных
  /// 5. Применяет резервирования из текущей корзины (_cart)
  ///
  /// @param currentUserId - ID текущего пользователя для исключения его резервирований из БД
  Future<void> applyCartReservationsToProducts({bool force = false, int? currentUserId}) async {
    if (!force && (productProvider?.reservationsApplied ?? false)) return; // Уже применены

    // Сначала сбросим все резервирования к оригинальным количествам из БД
    productProvider?.resetReservations();

    // Получить все резервирования из базы данных (сумма по всем пользователям)
    final allDbReservations = await _updateReservedQuantitiesCache();

    // Исключаем резервирования текущего пользователя из базы данных,
    // потому что они будут отдельно применены из _cart (текущей корзины в памяти)
    final dbReservations = Map<int, int>.from(allDbReservations);
    if (currentUserId != null) {
      // Для каждого товара получаем количество, зарезервированное текущим пользователем
      for (final productId in dbReservations.keys.toList()) {
        final userReserved = await cartRepository.getUserReservedQuantity(productId, currentUserId);
        if (userReserved > 0) {
          final newReserved = (dbReservations[productId] ?? 0) - userReserved;
          if (newReserved <= 0) {
            // Если после вычета резервирований текущего пользователя ничего не осталось
            dbReservations.remove(productId);
          } else {
            // Обновляем количество резервирований другими пользователями
            dbReservations[productId] = newReserved;
          }
        }
      }
    }

    // Применяем резервирования из базы данных (только от других пользователей)
    dbReservations.forEach((productId, reservedQuantity) {
      productProvider?.reserveQuantity(productId, reservedQuantity);
    });

    // Теперь применяем резервирования из текущей корзины (_cart)
    // Это включает резервирования текущего пользователя и гостей
    for (final item in _cart) {
      if (item.product.id != null) {
        productProvider?.reserveQuantity(item.product.id!, item.quantity);
      }
    }

    // Отмечаем, что резервирования применены
    productProvider?.setReservationsApplied(true);
  }

  Future<int> cleanupExpiredCarts() async {
    try {
      final expiredItems = await cartRepository.removeExpiredCartItems();

      if (expiredItems.isEmpty) return 0;

      // Возвращаем товары обратно в доступное количество
      // Группируем по product_id для суммирования количеств
      final Map<int, int> expiredByProduct = {};
      for (final item in expiredItems) {
        final productId = item['product_id'] as int;
        final quantity = item['quantity'] as int;
        expiredByProduct[productId] = (expiredByProduct[productId] ?? 0) + quantity;
      }

      // Возвращаем товары в UI
      for (final entry in expiredByProduct.entries) {
        productProvider?.restoreQuantity(entry.key, entry.value);
      }

      // Очищаем кэш зарезервированных количеств, так как они изменились
      await _updateReservedQuantitiesCache();
      // Обновляем доступные количества в списке продуктов
      await productProvider?.refreshAvailableQuantities();

      // Удаляем просроченные товары из текущей корзины, если они там есть
      final expiredProductIds = expiredByProduct.keys.toSet();
      _cart.removeWhere((cartItem) {
        if (cartItem.product.id != null && expiredProductIds.contains(cartItem.product.id)) {
          // Товар уже был возвращен выше, просто удаляем из корзины
          return true;
        }
        return false;
      });

      notifyListeners();
      return expiredItems.length;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return 0;
    }
  }

  /// Загружает корзину пользователя из базы данных
  /// Для гостей (userId = null) корзина остается пустой
  ///
  /// Логика работы:
  /// 1. Очищает просроченные корзины (>24 часов)
  /// 2. Очищает текущую корзину в памяти
  /// 3. Загружает товары корзины пользователя из базы данных
  /// 4. Создает объекты SaleItem для каждого товара
  /// 5. Применяет резервирования для корректного отображения количеств
  ///
  /// @param userId - ID пользователя (null для гостей)
  Future<void> loadCart(int? userId) async {
    try {
      // Очищаем корзины, которые старше 24 часов
      await cleanupExpiredCarts();

      // Очищаем текущую корзину в памяти перед загрузкой
      _cart.clear();

      // Загружаем товары корзины пользователя из базы данных
      final cartItems = await cartRepository.getCartItems(userId);

      // Для каждого товара из базы данных создаем объект SaleItem
      for (final item in cartItems) {
        final productId = item['product_id'] as int;
        final quantity = item['quantity'] as int;

        // Получаем полную информацию о товаре из репозитория
        if (productRepository != null) {
          final product = await productRepository!.getProductById(productId);
          if (product != null) {
            // Добавляем товар в корзину в памяти
            _cart.add(SaleItem(product: product, quantity: quantity));
          }
        }
      }

      // Применяем резервирования товаров для корректного отображения доступных количеств
      await applyCartReservationsToProducts(currentUserId: userId);

      // Уведомляем UI об изменении состояния корзины
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Добавляет товар в корзину
  /// Для авторизованных пользователей товар сохраняется в базе данных
  /// Для гостей товар хранится только в памяти
  ///
  /// Логика работы:
  /// 1. Если товар уже в корзине - увеличивает количество
  /// 2. Если товара нет в корзине - добавляет новый элемент
  /// 3. Сохраняет в БД (только для авторизованных пользователей)
  /// 4. Обновляет резервирования товаров для корректного отображения количеств
  ///
  /// @param item - элемент продажи (товар + количество)
  /// @param userId - ID пользователя (null для гостей)
  /// @param isGuest - флаг гостевого доступа
  Future<void> addToCart(SaleItem item, int? userId, {bool isGuest = false}) async {
    if (item.product.id == null) return;

    try {
      // Сохраняем в базе данных только для авторизованных пользователей
      // Гости хранят корзину только в памяти приложения
      if (!isGuest && userId != null) {
        await cartRepository.addToCart(userId, item.product.id!, item.quantity);
      }

      // Ищем товар в текущей корзине
      final existingIndex = _cart.indexWhere((cartItem) => cartItem.product.id == item.product.id);
      if (existingIndex >= 0) {
        // Товар уже есть в корзине - увеличиваем количество
        final existingItem = _cart[existingIndex];

        // Сначала "возвращаем" старое количество товара в доступное количество
        // (убираем резервирование старого количества)
        productProvider?.restoreQuantity(item.product.id!, existingItem.quantity);

        // Создаем обновленный элемент с новым количеством
        _cart[existingIndex] = SaleItem(
          product: existingItem.product,
          quantity: existingItem.quantity + item.quantity,
        );
      } else {
        // Товара нет в корзине - добавляем новый элемент
        _cart.add(item);
      }

      // Обновляем кэш резервирований из базы данных
      await _updateReservedQuantitiesCache();

      // Пересчитываем резервирования для всех товаров
      // force: true - принудительно пересчитать, даже если уже применены
      await applyCartReservationsToProducts(force: true, currentUserId: userId);

      // Уведомляем слушателей об изменении состояния корзины
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeFromCart(int index, int? userId, {bool isGuest = false}) async {
    final removed = _cart[index];
    if (removed.product.id == null) return;

    try {
      // Удаляем из БД только для авторизованных пользователей
      if (!isGuest && userId != null) {
        await cartRepository.removeFromCart(userId, removed.product.id!);
      }

    _cart.removeAt(index);
    // Обновляем кэш зарезервированных количеств
    await _updateReservedQuantitiesCache();
    // Обновляем резервирования в продуктах
    await applyCartReservationsToProducts(force: true, currentUserId: userId);
    notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateCartItemQuantity(int index, int quantity, int? userId, {bool isGuest = false}) async {
    final item = _cart[index];
    if (item.product.id == null) return;

    try {
      final productId = item.product.id!;

      // Обновляем в БД только для авторизованных пользователей
      if (!isGuest && userId != null) {
        await cartRepository.updateCartItemQuantity(userId, productId, quantity);
      }

    if (quantity <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index] = SaleItem(
        product: item.product,
        quantity: quantity,
      );
    }
    // Обновляем кэш зарезервированных количеств
    await _updateReservedQuantitiesCache();
    // Обновляем резервирования в продуктах
    await applyCartReservationsToProducts(force: true, currentUserId: userId);
    notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearCart(int? userId) async {
    try {
      // Очищаем в БД
      await cartRepository.clearCart(userId);

    _cart.clear();
    // Обновляем резервирования в продуктах (корзина пуста, так что резервирования сбросятся)
    await applyCartReservationsToProducts(force: true, currentUserId: userId);
    notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Receipt? _lastReceipt;
  Receipt? get lastReceipt => _lastReceipt;

  Future<bool> completeSale(int userId, String? notes) async {
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
      final receiptService = ReceiptService();
      double total = 0.0;
      final List<ReceiptItem> receiptItems = [];
      
      // Генерируем уникальный номер заказа для всей корзины
      final orderNumber = OrderNumberGenerator.generate();

      for (final item in _cart) {
        await inventoryService.validateSale(item.product.id!, item.quantity, userId);
      }

      for (final item in _cart) {
        final sale = Sale(
          userId: userId,
          productId: item.product.id!,
          quantity: item.quantity,
          unitPrice: item.product.price,
          totalPrice: item.totalPrice,
          saleDate: now,
          notes: notes,
          orderNumber: orderNumber, // Один номер заказа для всех товаров в корзине
        );

        await saleRepository.insertSale(sale);
        await inventoryService.updateStockAfterSale(item.product.id!, item.quantity);
        
        // Добавляем товар в чек
        total += item.totalPrice;
        receiptItems.add(ReceiptItem(
          productName: item.product.name,
          quantity: item.quantity.toDouble(),
          unitPrice: item.product.price,
          total: item.totalPrice,
          vatRate: 20.0,
        ));
      }

      // Создаем чек
      final vatAmount = receiptService.calculateVatAmount(total, 20.0);
      _lastReceipt = Receipt(
        companyName: 'Автозапчасти',
        hotline: '+7 (800) 123-45-67',
        owner: 'ИП Малков Тимур Владмирович',
        dateTime: now,
        items: receiptItems,
        total: total,
        vatRate: 20.0,
        vatAmount: vatAmount,
        paymentMethod: 'НАЛИЧНЫМИ',
        cashier: 'Администратор',
        customerName: null, // Имя будет получено из Users по userId в UI
        notes: notes,
        orderNumber: orderNumber, // Добавляем номер заказа в чек
        // Генерируем фискальные данные (в реальной системе они приходят от ККТ)
        kktRegistrationNumber: '0000000101059387',
        fiscalDriveNumber: '9999078902008329',
        fiscalDocumentNumber: DateTime.now().millisecondsSinceEpoch.toString().substring(0, 3),
        fiscalFeature: DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10),
      );

      // Очищаем корзину из БД
      await cartRepository.clearCart(userId);
      _cart.clear();
      // Обновляем резервирования в продуктах (корзина пуста)
      await applyCartReservationsToProducts(force: true, currentUserId: userId);
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

  /// Генерирует чек для конкретного заказа по номеру заказа
  Future<Receipt?> generateReceiptForOrder(String orderNumber, int userId, String customerName, {bool ignoreClientDeletedHistory = false}) async {
    try {
      // Получаем все продажи для данного заказа
      final sales = await saleRepository.getSalesByOrderNumber(orderNumber, userId, ignoreClientDeletedHistory: ignoreClientDeletedHistory);
      if (sales.isEmpty) {
        return null;
      }

      final receiptService = ReceiptService();
      double total = 0.0;
      final List<ReceiptItem> receiptItems = [];

      // Получаем информацию о товарах

      for (final sale in sales) {
        final product = await productProvider?.getProductById(sale.productId);
        if (product != null) {
          total += sale.totalPrice;
          receiptItems.add(ReceiptItem(
            productName: product.name,
            quantity: sale.quantity.toDouble(),
            unitPrice: sale.unitPrice,
            total: sale.totalPrice,
            vatRate: 20.0,
          ));
        }
      }

      // Создаем чек
      final vatAmount = receiptService.calculateVatAmount(total, 20.0);
      final receipt = Receipt(
        companyName: 'Автозапчасти',
        hotline: '+7 (800) 123-45-67',
        owner: 'ИП Малков Тимур Владмирович',
        dateTime: sales.first.saleDate,
        items: receiptItems,
        total: total,
        vatRate: 20.0,
        vatAmount: vatAmount,
        paymentMethod: 'НАЛИЧНЫМИ',
        cashier: 'Администратор',
        customerName: customerName,
        notes: sales.first.notes,
        orderNumber: orderNumber,
        // Генерируем фискальные данные (в реальной системе они приходят от ККТ)
        kktRegistrationNumber: '0000000101059387',
        fiscalDriveNumber: '9999078902008329',
        fiscalDocumentNumber: DateTime.now().millisecondsSinceEpoch.toString().substring(0, 3),
        fiscalFeature: DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10),
      );

      return receipt;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}

