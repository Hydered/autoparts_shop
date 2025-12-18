import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/user.dart';
import '../providers/home_provider.dart';
import '../providers/auth_provider.dart';
import 'products_screen.dart';
import 'new_sale_screen.dart';
import 'sales_history_screen.dart';
import 'auth_screen.dart';
import 'profile_edit_screen.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import '../providers/product_provider.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  UserRole? _previousRole;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final auth = context.read<AuthProvider>();
        _previousRole = auth.role;
        context.read<HomeProvider>().loadHomeData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    // Сбрасываем индекс при смене роли
    if (_previousRole != null && _previousRole != auth.role) {
      _currentIndex = 0; // Сбрасываем на первую вкладку при смене роли
      _previousRole = auth.role;
    } else if (_previousRole == null) {
      _previousRole = auth.role;
    }
    
    // Вычисляем список вкладок для текущей роли
    final destinations = <Widget>[
      if (auth.isAdmin)
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Главная',
        ),
      const NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: AppStrings.products,
      ),
      NavigationDestination(
        icon: Icon(auth.isAdmin
            ? Icons.bar_chart_outlined
            : Icons.shopping_cart_outlined),
        selectedIcon: Icon(
            auth.isAdmin ? Icons.bar_chart : Icons.shopping_cart),
        label: auth.isAdmin ? AppStrings.salesHistory : AppStrings.cart,
      ),
      if (auth.isClient)
        const NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history),
          label: AppStrings.history,
        ),
    ];
    
    // Убеждаемся, что индекс не выходит за пределы
    if (_currentIndex >= destinations.length) {
      _currentIndex = 0;
    }
    
    // Убеждаемся, что selectedIndex валиден
    final validIndex = _currentIndex < destinations.length ? _currentIndex : 0;

    Widget currentScreen;
    if (auth.isAdmin) {
      // Для админа: 0 - Главная, 1 - Товары, 2 - История продаж
      switch (_currentIndex) {
        case 0:
          currentScreen = const HomeTab();
          break;
        case 1:
          currentScreen = const ProductsScreen();
          break;
        case 2:
          currentScreen = const SalesHistoryScreen();
          break;
        default:
          currentScreen = const HomeTab();
      }
    } else {
      // Для гостя и клиента: 0 - Товары, 1 - Корзина, 2 - История (только для клиента)
      switch (_currentIndex) {
        case 0:
          currentScreen = const ProductsScreen();
          break;
        case 1:
          currentScreen = const NewSaleScreen();
          break;
        case 2:
          currentScreen = const SalesHistoryScreen();
          break;
        default:
          currentScreen = const ProductsScreen();
      }
    }


    return Scaffold(
      body: currentScreen,
      bottomNavigationBar: NavigationBar(
        selectedIndex: validIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (auth.isAdmin && (index == 0 || index == 2)) {
            context.read<HomeProvider>().loadHomeData();
          }
        },
        destinations: destinations,
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isGuest) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AuthScreen(),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline),
                        const SizedBox(width: 4),
                        Text(
                          auth.displayName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return PopupMenuButton<String>(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 4),
                      Text(
                        auth.displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditScreen(),
                      ),
                    );
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Удаление аккаунта'),
                        content: const Text(AppStrings.confirmDelete),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text(AppStrings.cancel),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text(AppStrings.delete),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      try {
                        await auth.deleteAccount();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Аккаунт удалён')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  } else if (value == 'logout') {
                    auth.logout();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Вы вышли из аккаунта')),
                      );
                    }
                  }
                },
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];
                  if (auth.isClient) {
                    items.add(
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text(AppStrings.editProfile),
                          ],
                        ),
                      ),
                    );
                    items.add(
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              AppStrings.deleteAccount,
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  items.add(
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20),
                          SizedBox(width: 8),
                          Text(AppStrings.logout),
                        ],
                      ),
                    ),
                  );
                  return items;
                },
              );
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          try {
            return Consumer<HomeProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const LoadingWidget();
                }

                return RefreshIndicator(
                  onRefresh: () => provider.loadHomeData(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Daily Sales Summary
                        _buildDailySalesCard(context, provider.dailySalesTotal),
                        const SizedBox(height: 16),
                        // Low Stock Alerts
                        _buildLowStockCard(context, provider.lowStockCount),
                        const SizedBox(height: 16),
                        // Best Selling Products
                        _buildBestSellingCard(context, provider.bestSellingProducts),
                      ],
                    ),
                  ),
                );
              },
            );
          } catch (e) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Ошибка: $e'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                    child: const Text('Перезагрузить'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDailySalesCard(BuildContext context, double total) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  AppStrings.dailySales,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(total),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockCard(BuildContext context, int count) {
    return Card(
      elevation: 2,
      color: count > 0 ? AppColors.lowStock.withOpacity(0.1) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: count > 0 ? AppColors.lowStock : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppStrings.lowStockAlerts,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    count == 1 
                        ? '$count товар требует внимания'
                        : '$count товаров требуют внимания',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              TextButton(
                onPressed: () => _showLowStockProducts(context),
                child: const Text('Просмотр'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBestSellingCard(
      BuildContext context, List<Map<String, dynamic>> products) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.trending_up, color: AppColors.accent),
                SizedBox(width: 8),
                Text(
                  AppStrings.bestSelling,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (products.isEmpty)
              const EmptyStateWidget(message: 'Нет данных о продажах')
            else
              ...products.asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${product['total_sold']} продано',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                            .format(product['total_revenue'] as num),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _showLowStockProducts(BuildContext context) async {
    final productProvider = context.read<ProductProvider>();
    
    try {
      final lowStockProducts = await productProvider.getLowStockProducts();
      
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Товары на грани отсутствия'),
          content: SizedBox(
            width: double.maxFinite,
            child: lowStockProducts.isEmpty
                ? const Text('Нет товаров с низким остатком')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: lowStockProducts.length,
                    itemBuilder: (context, index) {
                      final product = lowStockProducts[index];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text('Артикул: ${product.sku}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Остаток: ${product.quantity}',
                              style: TextStyle(
                                color: product.quantity <= product.minQuantity
                                    ? AppColors.lowStock
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Мин: ${product.minQuantity}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки товаров: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

