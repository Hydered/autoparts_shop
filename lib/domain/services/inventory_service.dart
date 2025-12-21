import '../entities/product.dart';
import '../repositories/product_repository.dart';
import '../repositories/cart_repository.dart';
import '../../core/exceptions/app_exceptions.dart';

class InventoryService {
  final ProductRepository productRepository;
  final CartRepository cartRepository;

  InventoryService(this.productRepository, this.cartRepository);

  Future<bool> checkAvailability(int productId, int requestedQuantity) async {
    final product = await productRepository.getProductById(productId);
    if (product == null) {
      throw NotFoundException('Product');
    }
    return product.quantity >= requestedQuantity;
  }

  Future<void> validateSale(int productId, int requestedQuantity, int? userId) async {
    final product = await productRepository.getProductById(productId);
    if (product == null) {
      throw NotFoundException('Product');
    }

    // Получить зарезервированное количество товара
    final reservedQuantities = await cartRepository.getReservedQuantities();
    final reservedQuantity = reservedQuantities[productId] ?? 0;
    final userReserved = await cartRepository.getUserReservedQuantity(productId, userId);
    final reservedByOthers = reservedQuantity - userReserved;
    // Доступное количество для этого пользователя:
    final availableQuantity = product.quantity - reservedByOthers;

    if (availableQuantity < requestedQuantity) {
      throw InsufficientStockException(
        product.name,
        availableQuantity,
        requestedQuantity,
      );
    }
  }

  Future<void> updateStockAfterSale(int productId, int soldQuantity) async {
    final product = await productRepository.getProductById(productId);
    if (product == null) {
      throw NotFoundException('Product');
    }
    
    final newQuantity = product.quantity - soldQuantity;
    if (newQuantity < 0) {
      throw InsufficientStockException(
        product.name,
        product.quantity,
        soldQuantity,
      );
    }
    
    await productRepository.updateProduct(
      product.copyWith(
        quantity: newQuantity,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<List<Product>> getLowStockProducts() async {
    return await productRepository.getLowStockProducts();
  }
}

