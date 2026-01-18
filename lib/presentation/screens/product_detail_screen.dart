import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/favorites_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../widgets/product_image_widget.dart';
import 'add_edit_product_screen.dart';
import 'auth_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({Key? key, required this.productId}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  List<ProductCharacteristic> _characteristics = [];
  bool _isLoading = true;
  String? _error;
  bool _isFavorite = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Перезагружаем данные при возврате к экрану
    // Убираем проверку _isLoading чтобы данные обновлялись всегда
    if (ModalRoute.of(context)?.isCurrent == true) {
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final provider = context.read<ProductProvider>();
      final product = await provider.getProductById(widget.productId);
      if (product == null) {
        setState(() {
          _error = 'Товар не найден';
          _isLoading = false;
        });
        return;
      }
      final characteristics = await provider.getCharacteristicsByProduct(widget.productId);

      // Загружаем статус избранного
      bool isFavorite = false;
      final authProvider = context.read<AuthProvider>();
      if (authProvider.userId != null) {
        final favoritesProvider = context.read<FavoritesProvider>();
        isFavorite = await favoritesProvider.isProductInFavorites(authProvider.userId!, product.id!);
      }

      setState(() {
        _product = product;
        _characteristics = characteristics;
        _isFavorite = isFavorite;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить товар'),
        content: Text('Вы уверены, что хотите удалить "${_product?.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    ) ??
    false;
    if (!confirmed) return;
    final provider = context.read<ProductProvider>();
    final success = await provider.deleteProduct(widget.productId);
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Товар удалён')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось удалить товар'), backgroundColor: AppColors.error));
    }
  }

  void _editProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditProductScreen(product: _product!),
      ),
    );
    if (mounted) _loadData();
  }

  Future<void> _addToCart() async {
    if (_product == null) return;

    // Проверяем, есть ли товар в наличии
    if (_product!.quantity == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар закончился'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final saleProvider = context.read<SaleProvider>();
    final authProvider = context.read<AuthProvider>();
    try {
      await saleProvider.inventoryService.validateSale(_product!.id!, 1, authProvider.userId);
      await saleProvider.addToCart(SaleItem(product: _product!, quantity: 1), authProvider.userId!);
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

  Future<void> _toggleFavorite() async {
    if (_product == null) return;

    final authProvider = context.read<AuthProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (authProvider.userId == null) {
      // Показать диалог авторизации для гостей
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Требуется авторизация'),
          content: const Text(
            'Чтобы добавлять товары в избранное, необходимо зарегистрироваться или войти в аккаунт.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                );
              },
              child: const Text('Войти'),
            ),
          ],
        ),
      );
      return;
    }

    final success = await favoritesProvider.toggleFavorite(authProvider.userId!, _product!.id!);
    if (success && mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite
              ? '${_product!.name} добавлен в избранное'
              : '${_product!.name} удален из избранного'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;
    final canAddToCart = !isAdmin && _product != null && !_isLoading;
    final isOutOfStock = _product?.quantity == 0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.productDetails),
        actions: [
          if (_product != null && !isAdmin)
            IconButton(
              icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
              color: _isFavorite ? AppColors.accent : null,
              tooltip: _isFavorite ? 'Удалить из избранного' : 'Добавить в избранное',
              onPressed: _toggleFavorite,
            ),
          if (isAdmin && _product != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: AppStrings.edit,
              onPressed: _editProduct,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: AppStrings.delete,
              onPressed: _deleteProduct,
            ),
          ],
        ],
      ),
      bottomNavigationBar: canAddToCart
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isOutOfStock
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Будет позже',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _addToCart,
                        icon: const Icon(Icons.shopping_cart),
                        label: const Text(AppStrings.addToCart),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
              ),
            )
          : null,
      body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _product == null
                  ? const Center(child: Text('Товар не найден'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Картинка
                          Center(
                            child: Stack(
                              children: [
                                ProductImageWidget(
                                  imagePath: _product!.imagePath,
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  height: 220,
                                  fit: BoxFit.cover,
                                ),
                                // Discount badge
                                if (_product!.hasDiscount)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '-${_product!.discountPercent!.toInt()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Название
                          Text(
                            _product!.name,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          // Описание
                          Text(
                            AppStrings.description,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            _product!.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.inventory_2, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text('${AppStrings.sku}: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(_product!.sku),
                              const SizedBox(width: 24),
                              const Icon(Icons.monetization_on, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text('${AppStrings.price}: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                              _product!.hasDiscount && !isOutOfStock
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_product!.displayOriginalPrice} ₽',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            decoration: TextDecoration.lineThrough,
                                            decorationColor: Colors.red,
                                          ),
                                        ),
                                        Text(
                                          '${_product!.price} ₽',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '${_product!.displayPrice} ₽',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Характеристики
                          Text(
                            'Характеристики',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _characteristics.isEmpty
                              ? const Text('Нет характеристик')
                              : Column(
                                  children: _characteristics
                                      .map(
                                        (c) => Row(
                                          children: [
                                            Text('${c.name}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text(c.value + (c.unit != null && c.unit!.isNotEmpty ? ' ${c.unit}' : '')),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
    );
  }
}
