import '../entities/sale.dart';

abstract class SaleRepository {
  Future<List<Sale>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
    int? limit,
    int? offset,
  });
  Future<void> clearClientHistory(int userId);

  Future<Sale?> getSaleById(int id);
  Future<int> insertSale(Sale sale);
  Future<double> getDailySalesTotal(DateTime date);
  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 3});
  Future<List<Sale>> getSalesByOrderNumber(String orderNumber, int userId, {bool ignoreClientDeletedHistory = false});
}

