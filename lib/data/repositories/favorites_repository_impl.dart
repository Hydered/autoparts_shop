import '../../domain/repositories/favorites_repository.dart';
import '../../domain/entities/favorite.dart';
import '../datasources/favorites_local_datasource.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  final FavoritesLocalDataSource localDataSource;

  FavoritesRepositoryImpl(this.localDataSource);

  @override
  Future<List<Favorite>> getUserFavorites(int userId) async {
    return await localDataSource.getUserFavorites(userId);
  }

  @override
  Future<bool> isProductInFavorites(int userId, int productId) async {
    return await localDataSource.isProductInFavorites(userId, productId);
  }

  @override
  Future<int> addToFavorites(int userId, int productId) async {
    return await localDataSource.addToFavorites(userId, productId);
  }

  @override
  Future<void> removeFromFavorites(int userId, int productId) async {
    return await localDataSource.removeFromFavorites(userId, productId);
  }

  @override
  Future<void> clearUserFavorites(int userId) async {
    return await localDataSource.clearUserFavorites(userId);
  }

  @override
  Future<int> getUserFavoritesCount(int userId) async {
    return await localDataSource.getUserFavoritesCount(userId);
  }
}
