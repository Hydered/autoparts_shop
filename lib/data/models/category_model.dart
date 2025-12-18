import '../../domain/entities/category.dart';

class CategoryModel extends Category {
  CategoryModel({
    super.id,
    required super.name,
    required super.iconPath,
    required super.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['Id'] as int? ?? json['id'] as int?,
      name: json['Name'] as String? ?? json['name'] as String,
      iconPath: (json['IconPath'] as String?) ?? (json['icon_path'] as String?) ?? '',
      createdAt: json['CreatedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['CreatedAt'] as int)
          : (json['created_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int)
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'Name': name,
      if (iconPath.isNotEmpty) 'IconPath': iconPath,
      'CreatedAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory CategoryModel.fromEntity(Category category) {
    return CategoryModel(
      id: category.id,
      name: category.name,
      iconPath: category.iconPath,
      createdAt: category.createdAt,
    );
  }
}

