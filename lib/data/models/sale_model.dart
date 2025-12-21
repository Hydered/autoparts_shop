import '../../domain/entities/sale.dart';

class SaleModel extends Sale {
  // Вспомогательные методы для безопасного парсинга типов
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
  
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  SaleModel({
    super.id,
    super.userId,
    required super.productId,
    required super.quantity,
    required super.unitPrice,
    required super.totalPrice,
    required super.saleDate,
    super.customerName,
    super.notes,
    super.orderNumber,
    super.status,
    super.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) {
    // Поддержка как старого формата (snake_case), так и нового (PascalCase)
    // Безопасное преобразование типов
    final id = _parseInt(json['id']) ?? _parseInt(json['Id']);
    final productId = _parseInt(json['product_id']) ?? _parseInt(json['ProductId']) ?? 0;
    final quantity = _parseInt(json['quantity']) ?? _parseInt(json['Quantity']) ?? 0;
    final unitPrice = _parseDouble(json['unit_price']) ?? _parseDouble(json['PriceAtSale']) ?? _parseDouble(json['UnitPrice']) ?? 0.0;
    final totalPrice = _parseDouble(json['total_price']) ?? _parseDouble(json['TotalPrice']) ?? (quantity * unitPrice);
    
    // Обработка даты из created_at (может быть int или строка)
    DateTime saleDate;
    final createdAtValue = json['created_at'];
    if (createdAtValue != null) {
      if (createdAtValue is int) {
        saleDate = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
      } else if (createdAtValue is String) {
        final timestamp = int.tryParse(createdAtValue);
        saleDate = timestamp != null 
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now();
      } else {
        saleDate = DateTime.now();
      }
    } else {
      // Пробуем получить из sale_date
      final saleDateValue = json['sale_date'];
      if (saleDateValue != null) {
        if (saleDateValue is int) {
          saleDate = DateTime.fromMillisecondsSinceEpoch(saleDateValue);
        } else if (saleDateValue is String) {
          final timestamp = int.tryParse(saleDateValue);
          saleDate = timestamp != null 
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();
        } else {
          saleDate = DateTime.now();
        }
      } else {
        saleDate = DateTime.now();
      }
    }
    
    final customerName = json['customer_name'] as String? ?? json['CustomerName'] as String?;
    final notes = json['notes'] as String? ?? json['Notes'] as String?;
    final orderNumber = json['order_number'] as String?;
    final status = json['status'] as String?;
    final createdAt = _parseInt(json['created_at']);
    
    return SaleModel(
      id: id,
      userId: _parseInt(json['user_id']) ?? _parseInt(json['UserId']),
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      saleDate: saleDate,
      customerName: customerName,
      notes: notes,
      orderNumber: orderNumber,
      status: status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'sale_date': saleDate.millisecondsSinceEpoch,
      'customer_name': customerName,
      'notes': notes,
      'order_number': orderNumber,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory SaleModel.fromEntity(Sale sale) {
    return SaleModel(
      id: sale.id,
      productId: sale.productId,
      quantity: sale.quantity,
      unitPrice: sale.unitPrice,
      totalPrice: sale.totalPrice,
      saleDate: sale.saleDate,
      userId: sale.userId,
      customerName: sale.customerName,
      notes: sale.notes,
      orderNumber: sale.orderNumber,
      status: sale.status,
      createdAt: sale.createdAt,
    );
  }
}

