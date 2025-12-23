import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/sale_provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import 'auth_screen.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../widgets/profile_section.dart';
import 'receipt_preview_screen.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Timer? _debounceTimer;
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Очищаем просроченные товары из корзины
      final cleanedItemsCount = await context.read<SaleProvider>().cleanupExpiredCarts();

      // Показываем уведомление, если были удалены просроченные товары
      if (cleanedItemsCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Удалено $cleanedItemsCount просроченных товаров из вашей корзины (старше 24 часов)'),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      _updateFieldsFromProfile();
    });
  }
  
  void _updateFieldsFromProfile() {
    final auth = context.read<AuthProvider>();
    if (auth.isClient) {
      // Обновляем поля только если они пустые или если данные изменились
      if (_fullNameController.text.isEmpty || _fullNameController.text != (auth.fullName ?? '')) {
        _fullNameController.text = auth.fullName ?? '';
      }
      if (_addressController.text.isEmpty || _addressController.text != (auth.address ?? '')) {
        _addressController.text = auth.address ?? '';
      }
      if (_phoneController.text.isEmpty || _phoneController.text != (auth.phone ?? '')) {
        _phoneController.text = auth.phone ?? '';
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fullNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final provider = context.read<ProductProvider>();
    await provider.searchProducts(query);
    
    setState(() {
      _searchResults = provider.products;
      _isSearching = false;
    });
  }

  Future<void> _addToCart(product, int quantity) async {
    final saleProvider = context.read<SaleProvider>();
    final auth = context.read<AuthProvider>();
    final inventoryService = saleProvider.inventoryService;

    try {
      if (auth.isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Админу нельзя оформлять покупки'),
            ),
          );
        }
        return;
      }
      await inventoryService.validateSale(product.id!, quantity, auth.userId);
      await saleProvider.addToCart(
        SaleItem(product: product, quantity: quantity),
        auth.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Товар добавлен в корзину')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeSale() async {
    final saleProvider = context.read<SaleProvider>();
    final auth = context.read<AuthProvider>();

    if (auth.isAdmin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Админу нельзя оформлять покупки'),
          ),
        );
      }
      return;
    }

    // Гость должен сначала зарегистрироваться
    if (auth.isGuest) {
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      }
      // После возврата гость мог стать клиентом, тогда пользователь
      // снова нажмёт "Оформить заказ" и пройдёт дальше.
      if (auth.isGuest) {
        return; // Пользователь не зарегистрировался
      }
      // Обновляем поля после регистрации
      _updateFieldsFromProfile();
    }
    // Для клиента подтягиваем данные из профиля, если поля пустые
    String fullName = _fullNameController.text.trim();
    String address = _addressController.text.trim();
    String phone = _phoneController.text.trim();
    
    if (auth.isClient) {
      // Если поля пустые, используем данные из профиля
      if (fullName.isEmpty) fullName = auth.fullName ?? '';
      if (address.isEmpty) address = auth.address ?? '';
      if (phone.isEmpty) phone = auth.phone ?? '';
    }
    
    // Проверяем обязательные поля
    if (fullName.isEmpty || address.isEmpty || phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заполните все обязательные поля: ФИО, Адрес, Номер телефона'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    final success = await saleProvider.completeSale(
      auth.userId!,
      fullName,
      _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (success && mounted) {
      // Обновляем список товаров, чтобы отразить изменения в количестве
      final saleProvider = context.read<SaleProvider>();
      context.read<ProductProvider>().loadProducts(
        refresh: true,
        saleProvider: saleProvider,
        currentUserId: auth.userId
      );

      // Очищаем поля только для гостей, клиентам оставляем данные
      if (auth.isGuest) {
        _fullNameController.clear();
        _addressController.clear();
        _phoneController.clear();
      }
      _notesController.clear();

      // Показываем чек
      final receipt = saleProvider.lastReceipt;
      if (receipt != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewScreen(receipt: receipt),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Покупка успешно завершена'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (mounted && saleProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saleProvider.error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ProfileSection(),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Корзина', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск товаров по названию или артикулу',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Search Results or Cart
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildCart(),
          ),
          // Cart Summary
          Consumer2<SaleProvider, AuthProvider>(
            builder: (context, provider, auth, child) {
              if (provider.cart.isEmpty) {
                return const SizedBox.shrink();
              }
              final isGuest = auth.isGuest;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          AppStrings.total,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      Text(
                          NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                              .format(provider.cartTotal),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (!isGuest) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'ФИО',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Адрес',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Номер телефона',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Заметка к заказу',
                          hintText:
                              'Например: позвонить перед доставкой, оставить у охраны, удобное время…',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                    if (isGuest) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lowStock.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Для оформления заказа необходимо зарегистрироваться',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.lowStock,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: provider.isLoading ? null : _completeSale,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: provider.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Оформить заказ'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const LoadingWidget();
    }

    if (_searchResults.isEmpty) {
      return const EmptyStateWidget(
        message: 'Товары не найдены',
        icon: Icons.search_off,
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final product = _searchResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            title: Text(product.name),
            subtitle: Text('Артикул: ${product.sku} | Остаток: ${product.quantity}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(product.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _showQuantityDialog(product),
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCart() {
    return Consumer2<SaleProvider, AuthProvider>(
      builder: (context, provider, auth, child) {
        if (provider.cart.isEmpty) {
          return const EmptyStateWidget(
            message: 'Найдите товары, чтобы добавить в корзину',
            icon: Icons.shopping_cart_outlined,
          );
        }

        return ListView.builder(
          itemCount: provider.cart.length,
          itemBuilder: (context, index) {
            final item = provider.cart[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                title: Text(item.product.name),
                subtitle: Text('${item.quantity} x ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(item.product.price)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(item.totalPrice),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => provider.removeFromCart(index, auth.userId, isGuest: auth.isGuest),
                    ),
                  ],
                ),
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () {
                    if (item.quantity > 1) {
                      provider.updateCartItemQuantity(index, item.quantity - 1, auth.userId, isGuest: auth.isGuest);
                    } else {
                      provider.removeFromCart(index, auth.userId, isGuest: auth.isGuest);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuantityDialog(product) {
    final quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Добавить ${product.name}'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Количество',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 1;
              Navigator.pop(context);
              _addToCart(product, quantity);
            },
            child: const Text(AppStrings.addToCart),
          ),
        ],
      ),
    );
  }
}

