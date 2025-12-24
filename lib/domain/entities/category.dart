class Category {
  final int? id;
  final String name;

  Category({
    this.id,
    required this.name,
  });

  Category copyWith({
    int? id,
    String? name,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

