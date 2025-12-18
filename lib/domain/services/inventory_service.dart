import '../entities/product.dart';
import '../repositories/product_repository.dart';
import '../../core/exceptions/app_exceptions.dart';

class InventoryService {
  final ProductRepository productRepository;

  InventoryService(this.productRepository);

  Future<bool> checkAvailability(int productId, int requestedQuantity) async {
    final product = await productRepository.getProductById(productId);
    if (product == null) {
      throw NotFoundException('Product');
    }
    return product.quantity >= requestedQuantity;
  }

  Future<void> validateSale(int productId, int requestedQuantity) async {
    final product = await productRepository.getProductById(productId);
    if (product == null) {
      throw NotFoundException('Product');
    }
    if (product.quantity < requestedQuantity) {
      throw InsufficientStockException(
        product.name,
        product.quantity,
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

