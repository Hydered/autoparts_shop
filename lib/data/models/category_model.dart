import '../../domain/entities/category.dart';

class CategoryModel extends Category {
  CategoryModel({
    super.id,
    required super.name,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['Id'] as int? ?? json['id'] as int?,
      name: json['Name'] as String? ?? json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
    };
  }

  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
    );
  }
}

