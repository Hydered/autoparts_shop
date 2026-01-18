import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/favorites_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/product_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import 'product_detail_screen.dart';
import 'auth_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _favoriteProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Перезагружаем избранное при изменениях в товарах
    final productProvider = context.watch<ProductProvider>();
    if (productProvider.products.isNotEmpty && !_isLoading) {
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId != null) {
      final favoritesProvider = context.read<FavoritesProvider>();
      final products = await favoritesProvider.loadUserFavorites(auth.userId!);
      setState(() {
        _favoriteProducts = products;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addToCart(Product product) async {
    final auth = context.read<AuthProvider>();
    final saleProvider = context.read<SaleProvider>();

    if (auth.isGuest) {
      _showAuthRequiredDialog();
      return;
    }

    // Проверяем, есть ли товар в наличии
    if (product.quantity == 0) {
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

    try {
      final saleItem = SaleItem(product: product, quantity: 1);
      await saleProvider.addToCart(saleItem, auth.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} добавлен в корзину')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при добавлении в корзину: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeFromFavorites(Product product) async {
    final auth = context.read<AuthProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (auth.userId == null) return;

    final success = await favoritesProvider.removeFromFavorites(
      auth.userId!,
      product.id!,
    );

    if (success && mounted) {
      setState(() {
        _favoriteProducts.removeWhere((p) => p.id == product.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} удален из избранного')),
      );
    }
  }

  Future<void> _clearAllFavorites() async {
    final auth = context.read<AuthProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    if (auth.userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить избранное'),
        content: const Text('Вы действительно хотите удалить все товары из избранного?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить все'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await favoritesProvider.clearUserFavorites(auth.userId!);
      if (success && mounted) {
        setState(() {
          _favoriteProducts.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Все товары удалены из избранного')),
        );
      }
    }
  }

  void _showAuthRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Требуется авторизация'),
        content: const Text(
          'Чтобы добавлять товары в корзину, необходимо зарегистрироваться или войти в аккаунт.',
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Избранное'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_border,
                size: 64,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Избранное доступно только для зарегистрированных пользователей',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                child: const Text('Войти в аккаунт'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        elevation: 0,
        actions: [
          if (_favoriteProducts.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllFavorites,
              icon: const Icon(Icons.clear_all, color: AppColors.error),
              label: const Text(
                'Удалить все',
                style: TextStyle(color: AppColors.error),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _favoriteProducts.isEmpty
              ? const EmptyStateWidget(
                  message: 'У вас нет избранных товаров',
                  icon: Icons.favorite_border,
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _favoriteProducts.length,
                    itemBuilder: (context, index) {
                      final product = _favoriteProducts[index];
                      final auth = context.read<AuthProvider>();
                      return ProductCard(
                        product: product,
                        showQuantity: true,
                        isAdmin: auth.isAdmin,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(productId: product.id!),
                            ),
                          );
                        },
                        onAddToCart: product.quantity > 0 ? () => _addToCart(product) : null,
                        onDelete: () => _removeFromFavorites(product),
                      );
                    },
                  ),
                ),
    );
  }
}
