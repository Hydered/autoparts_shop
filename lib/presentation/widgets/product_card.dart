import 'package:flutter/material.dart';
import '../../domain/entities/product.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import 'product_image_widget.dart';
import 'package:intl/intl.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddToCart;
  final int? availableQuantity; // Доступное количество (для клиентов/гостей)

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAddToCart,
    this.availableQuantity,
  });

  @override
  Widget build(BuildContext context) {
    // Определяем количество для отображения: доступное для клиентов, реальное для админа
    final displayQuantity = availableQuantity ?? product.quantity;

    final isLowStock = displayQuantity <= (product.minQuantity);
    final stockColor = displayQuantity == 0
        ? AppColors.error
        : isLowStock
            ? AppColors.lowStock
            : AppColors.success;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ProductImageWidget(
                  imagePath: product.imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Артикул: ${product.sku}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                              .format(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: stockColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: stockColor, width: 1),
                              ),
                              child: Text(
                                '${AppStrings.quantity}: $displayQuantity',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: stockColor,
                                ),
                              ),
                            ),
                            if (onAddToCart != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_shopping_cart),
                                color: AppColors.primary,
                                onPressed: onAddToCart,
                                tooltip: AppStrings.addToCart,
                              ),
                            ],
                            if (onDelete != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.error,
                                onPressed: onDelete,
                                tooltip: AppStrings.delete,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

