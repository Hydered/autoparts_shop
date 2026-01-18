class Favorite {
  final int? id;
  final int userId;
  final int productId;
  final DateTime createdAt;

  Favorite({
    this.id,
    required this.userId,
    required this.productId,
    required this.createdAt,
  });

  factory Favorite.create({
    required int userId,
    required int productId,
  }) {
    return Favorite(
      userId: userId,
      productId: productId,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'product_id': productId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'],
      userId: map['user_id'],
      productId: map['product_id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  Favorite copyWith({
    int? id,
    int? userId,
    int? productId,
    DateTime? createdAt,
  }) {
    return Favorite(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
