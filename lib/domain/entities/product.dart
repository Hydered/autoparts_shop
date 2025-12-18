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
  });

  bool get isLowStock => quantity <= minQuantity;
  bool get isOutOfStock => quantity == 0;
  bool get isInStock => quantity > minQuantity;

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
    );
  }
}

