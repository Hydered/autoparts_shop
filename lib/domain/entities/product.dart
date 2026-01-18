class Product {
  final int? id;
  final String name;
  final String description;
  final int categoryId;
  final double price;
  final int quantity;
  final String sku;
  final int minQuantity;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? discountPercent; // Процент скидки (0-100)
  final double? originalPrice; // Оригинальная цена до скидки

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.price,
    required this.quantity,
    required this.sku,
    required this.minQuantity,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
    this.discountPercent,
    this.originalPrice,
  });

  bool get isLowStock => quantity <= minQuantity;
  bool get isOutOfStock => quantity == 0;
  bool get isInStock => quantity > minQuantity;
  
  // Проверяет, есть ли активная скидка (скидка отображается только если товар в наличии)
  bool get hasDiscount => discountPercent != null && discountPercent! > 0 && quantity > 0;
  
  // Возвращает цену для отображения: если товар закончился, показываем оригинальную цену, иначе цену со скидкой
  double get displayPrice => isOutOfStock && originalPrice != null ? originalPrice! : price;
  
  // Возвращает оригинальную цену (до скидки) или текущую цену
  double get displayOriginalPrice => originalPrice ?? price;

  Product copyWith({
    int? id,
    String? name,
    String? description,
    int? categoryId,
    double? price,
    int? quantity,
    String? sku,
    int? minQuantity,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? discountPercent,
    double? originalPrice,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      minQuantity: minQuantity ?? this.minQuantity,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      discountPercent: discountPercent ?? this.discountPercent,
      originalPrice: originalPrice ?? this.originalPrice,
    );
  }
}

