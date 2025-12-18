import 'product.dart';

class SaleItem {
  final Product product;
  final int quantity;
  
  SaleItem({
    required this.product,
    required this.quantity,
  });
  
  double get totalPrice => product.price * quantity;
  
  SaleItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return SaleItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

