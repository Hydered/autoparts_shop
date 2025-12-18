import 'package:flutter/foundation.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../core/utils/date_utils.dart';

class HomeProvider with ChangeNotifier {
  final SaleRepository saleRepository;
  final ProductRepository productRepository;

  HomeProvider(this.saleRepository, this.productRepository);

  double _dailySalesTotal = 0.0;
  double get dailySalesTotal => _dailySalesTotal;

  List<Map<String, dynamic>> _bestSellingProducts = [];
  List<Map<String, dynamic>> get bestSellingProducts => _bestSellingProducts;

  int _lowStockCount = 0;
  int get lowStockCount => _lowStockCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadHomeData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final today = DateUtils.getToday();
      _dailySalesTotal = await saleRepository.getDailySalesTotal(today);
      _bestSellingProducts = await saleRepository.getBestSellingProducts(limit: 3);
      final lowStockProducts = await productRepository.getLowStockProducts();
      _lowStockCount = lowStockProducts.length;
    } catch (e) {

      print('Error loading home data: $e');
      _dailySalesTotal = 0.0;
      _bestSellingProducts = [];
      _lowStockCount = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

