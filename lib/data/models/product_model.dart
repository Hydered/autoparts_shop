import '../../domain/entities/product.dart';

class ProductModel extends Product {
  ProductModel({
    super.id,
    required super.name,
    required super.description,
    required super.categoryId,
    required super.price,
    required super.quantity,
    required super.sku,
    required super.minQuantity,
    super.imagePath,
    required super.createdAt,
    required super.updatedAt,
    super.discountPercent,
    super.originalPrice,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Поддержка как старого формата (snake_case), так и нового (PascalCase)
    final id = json['Id'] as int? ?? json['id'] as int?;
    final name = json['Name'] as String? ?? json['name'] as String;
    final description = json['Description'] as String? ?? json['description'] as String? ?? '';
    final categoryId = json['CategoryId'] as int? ?? json['category_id'] as int;
    final price = (json['Price'] as num?)?.toDouble() ?? (json['price'] as num).toDouble();
    // quantity хранится в поле Products.stock
    final quantity = json['quantity'] as int? ??
        json['Quantity'] as int? ??
        json['stock'] as int? ??
        json['Stock'] as int? ??
        0;
    final sku = json['SKU'] as String? ?? json['sku'] as String? ?? '';
    final minQuantity = json['MinQuantity'] as int? ?? json['min_quantity'] as int? ?? 5;
    final imagePath = json['ImageUrl'] as String? ?? json['image_path'] as String? ?? json['ImagePath'] as String?;
    final discountPercent = json['DiscountPercent'] != null 
        ? (json['DiscountPercent'] as num).toDouble()
        : (json['discount_percent'] != null 
            ? (json['discount_percent'] as num).toDouble() 
            : null);
    final originalPrice = json['OriginalPrice'] != null
        ? (json['OriginalPrice'] as num).toDouble()
        : (json['original_price'] != null
            ? (json['original_price'] as num).toDouble()
            : null);
    
    final createdAt = json['CreatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['CreatedAt'] as int)
        : (json['created_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
            : DateTime.now());
    
    final updatedAt = json['UpdatedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['UpdatedAt'] as int)
        : (json['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
            : DateTime.now());

    return ProductModel(
      id: id,
      name: name,
      description: description,
      categoryId: categoryId,
      price: price,
      quantity: quantity,
      sku: sku,
      minQuantity: minQuantity,
      imagePath: imagePath,
      createdAt: createdAt,
      updatedAt: updatedAt,
      discountPercent: discountPercent,
      originalPrice: originalPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'price': price,
      'quantity': quantity, // Хранится в Products.stock
      if (sku.isNotEmpty) 'sku': sku,
      // min_quantity не записываем - используется только для чтения с дефолтом 5
      if (imagePath != null && imagePath!.isNotEmpty) 'image_url': imagePath,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      if (discountPercent != null) 'discount_percent': discountPercent,
      if (originalPrice != null) 'original_price': originalPrice,
    };
  }

  factory ProductModel.fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      description: product.description,
      categoryId: product.categoryId,
      price: product.price,
      quantity: product.quantity,
      sku: product.sku,
      minQuantity: product.minQuantity,
      imagePath: product.imagePath,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      discountPercent: product.discountPercent,
      originalPrice: product.originalPrice,
    );
  }

  @override
  ProductModel copyWith({
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
    return ProductModel(
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

