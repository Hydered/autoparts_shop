import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_local_datasource.dart';
import '../models/category_model.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final CategoryLocalDataSource localDataSource;

  CategoryRepositoryImpl(this.localDataSource);

  @override
  Future<List<Category>> getAllCategories() async {
    final models = await localDataSource.getAllCategories();
    return models;
  }

  @override
  Future<Category?> getCategoryById(int id) async {
    return await localDataSource.getCategoryById(id);
  }

  @override
  Future<int> insertCategory(Category category) async {
    final model = CategoryModel.fromEntity(category);
    return await localDataSource.insertCategory(model);
  }

  @override
  Future<int> updateCategory(Category category) async {
    final model = CategoryModel.fromEntity(category);
    return await localDataSource.updateCategory(model);
  }

  @override
  Future<int> deleteCategory(int id) async {
    return await localDataSource.deleteCategory(id);
  }
}

