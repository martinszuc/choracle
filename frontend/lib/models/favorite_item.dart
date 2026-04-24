class FavoriteItem {
  final String id;
  final String name;

  const FavoriteItem({required this.id, required this.name});

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
