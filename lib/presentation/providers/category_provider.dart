import 'package:flutter/foundation.dart';
import '../../domain/entities/category.dart' as domain;
import '../../domain/repositories/category_repository.dart';
import '../../core/exceptions/app_exceptions.dart';

class CategoryProvider with ChangeNotifier {
  final CategoryRepository categoryRepository;

  CategoryProvider(this.categoryRepository);

  List<domain.Category> _categories = [];
  List<domain.Category> get categories => _categories;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await categoryRepository.getAllCategories();
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (e is AppException) {
        _error = e.message;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}

