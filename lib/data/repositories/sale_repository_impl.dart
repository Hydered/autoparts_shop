import '../../domain/entities/sale.dart';
import '../../domain/repositories/sale_repository.dart';
import '../datasources/sale_local_datasource.dart';
import '../models/sale_model.dart';

class SaleRepositoryImpl implements SaleRepository {
  @override
  Future<void> clearClientHistory(int userId) async {
    await localDataSource.clearClientHistory(userId);
  }
  final SaleLocalDataSource localDataSource;

  SaleRepositoryImpl(this.localDataSource);

  @override
  Future<List<Sale>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
    int? userId,
    int? limit,
    int? offset,
  }) async {
    final models = await localDataSource.getAllSales(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
      limit: limit,
      offset: offset,
    );
    return models;
  }

  @override
  Future<Sale?> getSaleById(int id) async {
    return await localDataSource.getSaleById(id);
  }

  @override
  Future<int> insertSale(Sale sale) async {
    final model = SaleModel.fromEntity(sale);
    return await localDataSource.insertSale(model);
  }

  @override
  Future<double> getDailySalesTotal(DateTime date) async {
    return await localDataSource.getDailySalesTotal(date);
  }

  @override
  Future<List<Map<String, dynamic>>> getBestSellingProducts({int limit = 3}) async {
    return await localDataSource.getBestSellingProducts(limit: limit);
  }

  @override
  Future<List<Sale>> getSalesByOrderNumber(String orderNumber, int userId, {bool ignoreClientDeletedHistory = false}) async {
    final models = await localDataSource.getSalesByOrderNumber(orderNumber, userId, ignoreClientDeletedHistory: ignoreClientDeletedHistory);
    return models;
  }
}

