import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../providers/sale_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/profile_section.dart';
import '../../domain/entities/sale_item.dart';
import '../../domain/entities/product.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import 'product_detail_screen.dart' show ProductDetailScreen;
import 'add_edit_product_screen.dart';
import 'dart:async';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();
  final Map<int, int> _availableQuantitiesCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      _clearAvailableQuantitiesCache();
      // Загружаем продукты только если они еще не загружены
      final productProvider = context.read<ProductProvider>();
      final saleProvider = context.read<SaleProvider>();
      if (productProvider.products.isEmpty) {
        await productProvider.loadProducts(
          refresh: true,
          saleProvider: saleProvider,
          currentUserId: auth.userId
        );
      } else {
        // Если продукты уже загружены, применяем резервирования
        await saleProvider.applyCartReservationsToProducts(currentUserId: auth.userId);
      }
      context.read<CategoryProvider>().loadCategories();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auth state changes are handled in the Consumer widgets
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final saleProvider = context.read<SaleProvider>();
      final auth = context.read<AuthProvider>();
      context.read<ProductProvider>().loadProducts(
        saleProvider: saleProvider,
        currentUserId: auth.userId
      );
    }
  }

  void _onSearchChanged(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      context.read<ProductProvider>().searchProducts(value);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearAvailableQuantitiesCache() {
    _availableQuantitiesCache.clear();
  }

  Future<void> _showFilterDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(AppStrings.filter),
          content: Consumer2<ProductProvider, CategoryProvider>(
            builder: (context, productProvider, categoryProvider, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (categoryProvider.categories.isNotEmpty)
                    DropdownButtonFormField<int?>(
                      value: productProvider.selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: AppStrings.category,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Все категории'),
                        ),
                        ...categoryProvider.categories.map(
                          (category) => DropdownMenuItem<int?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        productProvider.setSelectedCategoryId(value);
                        final saleProvider = Provider.of<SaleProvider>(context, listen: false);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        productProvider.loadProducts(
                          refresh: true,
                          saleProvider: saleProvider,
                          currentUserId: auth.userId
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: productProvider.sortBy,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'created_at',
                        child: Text('По дате добавления'),
                      ),
                      DropdownMenuItem(
                        value: 'name',
                        child: Text('По названию'),
                      ),
                      DropdownMenuItem(
                        value: 'price',
                        child: Text('По цене'),
                      ),
                      DropdownMenuItem(
                        value: 'quantity',
                        child: Text('По количеству'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        productProvider.setSortBy(value);
                        final saleProvider = Provider.of<SaleProvider>(context, listen: false);
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        productProvider.loadProducts(
                          refresh: true,
                          saleProvider: saleProvider,
                          currentUserId: auth.userId
                        );
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Очистить фильтры'),
              onPressed: () {
                context.read<ProductProvider>().clearFilters();
                final saleProvider = context.read<SaleProvider>();
                final auth = context.read<AuthProvider>();
                context.read<ProductProvider>().loadProducts(
                  refresh: true,
                  saleProvider: saleProvider,
                  currentUserId: auth.userId
                );
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Закрыть'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToCart(Product product, int? userId, SaleProvider saleProvider, bool isGuest) async {
    if (product.id == null) return;
    try {
      await saleProvider.inventoryService.validateSale(product.id!, 1, userId);
      await saleProvider.addToCart(
        SaleItem(product: product, quantity: 1),
        userId,
        isGuest: isGuest,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар добавлен в корзину'),
          ),
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

  Future<void> _deleteProduct(Product product, bool isGuest, int? userId) async {
    if (product.id == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить товар'),
            content: Text(
              'Вы уверены, что хотите удалить "${product.name}"?',
            ),
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
    final success = await context.read<ProductProvider>().deleteProduct(product.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Товар удалён' : 'Не удалось удалить товар'),
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
                Expanded(
                  child: Text(
                    AppStrings.products,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.search,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ProductProvider>().searchProducts('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, _) {
                if (productProvider.isLoading && productProvider.products.isEmpty) {
                  return const LoadingWidget();
                }
                if (productProvider.error != null && productProvider.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          productProvider.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final saleProvider = Provider.of<SaleProvider>(context, listen: false);
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            productProvider.loadProducts(
                              refresh: true,
                              saleProvider: saleProvider,
                              currentUserId: auth.userId
                            );
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }
                if (productProvider.products.isEmpty) {
                  return const EmptyStateWidget(
                    message: AppStrings.emptyState,
                    icon: Icons.inventory_2_outlined,
                  );
                }
                return Consumer2<SaleProvider, AuthProvider>(
                  builder: (context, saleProvider, auth, _) {
                    return RefreshIndicator(
                      onRefresh: () {
                        _clearAvailableQuantitiesCache();
                        return productProvider.loadProducts(
                          refresh: true,
                          saleProvider: saleProvider,
                          currentUserId: auth.userId
                        );
                      },
                      child: Builder(
                        builder: (context) {
                          final allProducts = productProvider.products;
                          // Фильтруем товары в зависимости от роли пользователя
                          final filteredProducts = allProducts.where((product) {
                              // Администраторы видят все товары (включая с нулевым количеством)
                              if (auth.isAdmin) return true;

                              // Для обычных пользователей (клиенты и гости):
                              // показываем только товары с доступным количеством > 0
                              // product.quantity уже учитывает резервирования всех пользователей
                              return product.quantity > 0;
                            }).toList();

                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: filteredProducts.length + (productProvider.isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredProducts.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final product = filteredProducts[index];
                              final availQty = product.quantity;
                              return ProductCard(
                                product: product,
                                availableQuantity: availQty,
                                onTap: () {
                                  if (product.id != null) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductDetailScreen(productId: product.id!),
                                      ),
                                    );
                                  }
                                },
                                onAddToCart: auth.isAdmin
                                    ? null
                                    : () => _addToCart(product, auth.userId, saleProvider, auth.isGuest),
                                onDelete: auth.isAdmin
                                    ? () => _deleteProduct(product, auth.isGuest, auth.userId)
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isAdmin) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddEditProductScreen(),
                ),
              ).then((_) {
                _clearAvailableQuantitiesCache();
                final saleProvider = context.read<SaleProvider>();
                final auth = context.read<AuthProvider>();
                context.read<ProductProvider>().loadProducts(
                  refresh: true,
                  saleProvider: saleProvider,
                  currentUserId: auth.userId
                );
              });
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
