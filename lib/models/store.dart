class Store {
  final String id;
  final String name;
  final String ownerUid;
  final String city;
  final String imageUrl;
  final double rating;

  Store({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.city,
    required this.imageUrl,
    required this.rating,
  });

  factory Store.fromMap(Map<String, dynamic> map, String id) {
    return Store(
      id: id,
      name: (map['storeName'] ?? map['name'] ?? '').toString(),
      ownerUid: (map['ownerUid'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      imageUrl: (map['storeImageUrl'] ?? map['imageUrl'] ?? '').toString(),
      rating: (map['rating'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeName': name,
      'ownerUid': ownerUid,
      'city': city,
      'storeImageUrl': imageUrl,
      'rating': rating,
    };
  }
}
