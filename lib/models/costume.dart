class Costume {
  final String id;
  final String name;
  final String anime;
  final String storeId;
  final String description;
  final List<String> imageUrls;
  final double price;
  final List<String> sizes;
  final bool isAvailable;
  final double rating;
  final List<String> bookedDates;

  Costume({
    required this.id,
    required this.name,
    required this.anime,
    required this.storeId,
    required this.description,
    required this.imageUrls,
    required this.price,
    required this.sizes,
    required this.isAvailable,
    this.rating = 0.0,
    this.bookedDates = const [],
  });

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is Map) {
      return value.values.map((e) => e.toString()).toList();
    }
    return [];
  }

  factory Costume.fromMap(Map<String, dynamic> map, String id) {
    return Costume(
      id: id,
      name: (map['name'] ?? '').toString(),
      anime: (map['anime'] ?? '').toString(),
      storeId: (map['storeId'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      imageUrls: _parseStringList(map['imageUrls']),
      price: (map['price'] ?? 0).toDouble(),
      sizes: _parseStringList(map['sizes']),
      isAvailable: map['isAvailable'] ?? true,
      rating: (map['rating'] ?? 0).toDouble(),
      bookedDates: _parseStringList(map['bookedDates']),
    );
  }

  Costume copyWith({
    String? id,
    String? name,
    String? anime,
    String? storeId,
    String? description,
    List<String>? imageUrls,
    double? price,
    List<String>? sizes,
    bool? isAvailable,
    double? rating,
    List<String>? bookedDates,
  }) {
    return Costume(
      id: id ?? this.id,
      name: name ?? this.name,
      anime: anime ?? this.anime,
      storeId: storeId ?? this.storeId,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      price: price ?? this.price,
      sizes: sizes ?? this.sizes,
      isAvailable: isAvailable ?? this.isAvailable,
      rating: rating ?? this.rating,
      bookedDates: bookedDates ?? this.bookedDates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'anime': anime,
      'storeId': storeId,
      'description': description,
      'imageUrls': imageUrls,
      'price': price,
      'sizes': sizes,
      'isAvailable': isAvailable,
      'rating': rating,
      'bookedDates': bookedDates,
    };
  }
}
