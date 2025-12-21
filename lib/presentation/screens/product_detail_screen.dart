import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_characteristic.dart';
import '../../domain/entities/sale_item.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sale_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../widgets/product_image_widget.dart';
import 'add_edit_product_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
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
      setState(() {
        _product = product;
        _characteristics = characteristics;
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
    if (mounted) _loadProduct();
  }

  Future<void> _addToCart() async {
    if (_product == null) return;
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin;
    final canAddToCart = !isAdmin && _product != null && !_isLoading;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.productDetails),
        actions: isAdmin && _product != null
            ? [
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
              ]
            : null,
      ),
      bottomNavigationBar: canAddToCart
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
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
                            child: ProductImageWidget(
                              imagePath: _product!.imagePath,
                              width: MediaQuery.of(context).size.width * 0.85,
                              height: 220,
                              fit: BoxFit.cover,
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
                              Text('${_product!.price} ₽'),
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
