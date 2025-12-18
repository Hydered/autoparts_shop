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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts(refresh: true);
      context.read<CategoryProvider>().loadCategories();
    });

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<ProductProvider>().loadProducts();
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
          // Search Bar
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Products List
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.products.isEmpty) {
                  return const LoadingWidget();
                }

                if (provider.error != null && provider.products.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.loadProducts(refresh: true),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.products.isEmpty) {
                  return const EmptyStateWidget(
                    message: AppStrings.emptyState,
                    icon: Icons.inventory_2_outlined,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadProducts(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: provider.products.length + (provider.isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == provider.products.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final product = provider.products[index];
                      return Consumer2<SaleProvider, AuthProvider>(
                        builder: (context, saleProvider, auth, _) {
                          return ProductCard(
                            product: product,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProductDetailScreen(productId: product.id!),
                                ),
                              );
                            },
                            onAddToCart: auth.isAdmin
                                ? null
                                : () async {
                                    try {
                                      await saleProvider.inventoryService
                                          .validateSale(product.id!, 1);
                                      saleProvider.addToCart(
                                        SaleItem(product: product, quantity: 1),
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
                                  },
                            onDelete: auth.isAdmin
                                ? () async {
                                    final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Удалить товар'),
                                            content: Text(
                                              'Вы уверены, что хотите удалить \"${product.name}\"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(false),
                                                child: const Text('Отмена'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(true),
                                                child: const Text('Удалить'),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                    if (!confirmed) return;

                                    final success = await context
                                        .read<ProductProvider>()
                                        .deleteProduct(product.id!);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success
                                              ? 'Товар удалён'
                                              : 'Не удалось удалить товар'),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        },
                      );
                    },
                  ),
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
                context.read<ProductProvider>().loadProducts(refresh: true);
              });
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.filter),
        content: Consumer2<ProductProvider, CategoryProvider>(
          builder: (context, productProvider, categoryProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Filter
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
                      ...categoryProvider.categories.map((category) {
                        return DropdownMenuItem<int?>(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      productProvider.filterByCategory(value);
                      Navigator.pop(context);
                    },
                  ),
                const SizedBox(height: 16),
                // Sort Options
                DropdownButtonFormField<String>(
                  value: productProvider.sortBy,
                  decoration: const InputDecoration(
                    labelText: AppStrings.sort,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'created_at', child: Text('Сначала новые')),
                    DropdownMenuItem(value: 'name', child: Text('А-Я')),
                    DropdownMenuItem(value: 'price', child: Text('Цена на увеличение')),
                    DropdownMenuItem(value: 'quantity', child: Text('Количество на увеличение')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      productProvider.sortProducts(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
  }
}

