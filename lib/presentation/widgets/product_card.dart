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
  final VoidCallback? onToggleFavorite;
  final bool isFavorite;
  final int? availableQuantity; // Доступное количество (для клиентов/гостей)
  final bool showQuantity; // Показывать ли количество товара
  final bool isAdmin; // Является ли пользователь админом

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onAddToCart,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.availableQuantity,
    this.showQuantity = true, // По умолчанию показывать количество
    this.isAdmin = false, // По умолчанию не админ
  });

  @override
  Widget build(BuildContext context) {
    // Определяем количество для отображения: доступное для клиентов, реальное для админа
    final displayQuantity = availableQuantity ?? product.quantity;
    final isOutOfStock = displayQuantity == 0;





    final isLowStock = displayQuantity <= (product.minQuantity);
    final stockColor = displayQuantity == 0
        ? AppColors.error
        : isLowStock
            ? AppColors.lowStock
            : AppColors.success;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      color: isOutOfStock ? Colors.grey[200] : null,
      shape: isOutOfStock
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.grey, width: 2),
            )
          : null,
      child: Opacity(
        opacity: isOutOfStock ? 0.7 : 1.0,
        child: InkWell(
          onTap: onTap,
          child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ProductImageWidget(
                      imagePath: product.imagePath,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Discount badge (показываем только если товар в наличии)
                  if (product.hasDiscount && !isOutOfStock)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '-${product.discountPercent!.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (onToggleFavorite != null && !isAdmin)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: isFavorite ? AppColors.accent : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
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
                    // Price and quantity/status in top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price display with discount
                        product.hasDiscount && !isOutOfStock
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Old price crossed out
                                  Text(
                                    NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                                        .format(product.displayOriginalPrice),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // New price
                                  Text(
                                    NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                                        .format(product.price),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                                    .format(product.displayPrice),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                        if (showQuantity) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? Colors.grey[300]
                                  : stockColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isOutOfStock ? Colors.grey : stockColor,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isOutOfStock ? 'закончилось' : '$displayQuantity ${AppStrings.quantityShort}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOutOfStock ? Colors.grey[700] : stockColor,
                              ),
                            ),
                          ),
                        ] else if (isOutOfStock) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey,
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'закончилось',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF616161),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Action buttons in bottom row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onAddToCart != null && (!isOutOfStock || showQuantity)) ...[
                          if (isOutOfStock) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'будет позже',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            ElevatedButton.icon(
                              onPressed: onAddToCart,
                              icon: const Icon(Icons.add_shopping_cart, size: 16),
                              label: const Text('В корзину', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          ],
                        ],
                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: AppColors.error,
                            onPressed: onDelete,
                            tooltip: AppStrings.delete,
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        ),
    );
  }
}

