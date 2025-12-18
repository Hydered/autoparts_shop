class Category {
  final int? id;
  final String name;
  final String iconPath;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    required this.iconPath,
    required this.createdAt,
  });

  Category copyWith({
    int? id,
    String? name,
    String? iconPath,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

