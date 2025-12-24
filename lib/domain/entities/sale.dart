class Sale {
  final int? id;
  final int? userId; // <-- клиент, владелец покупки
  final int productId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime saleDate;
  final String? notes;
  final String? orderNumber;
  final String? status;
  final int? createdAt;

  Sale({
    this.id,
    this.userId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.saleDate,
    this.notes,
    this.orderNumber,
    this.status,
    this.createdAt,
  });

  Sale copyWith({
    int? id,
    int? productId,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    DateTime? saleDate,
    String? notes,
  }) {
    return Sale(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      saleDate: saleDate ?? this.saleDate,
      notes: notes ?? this.notes,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

