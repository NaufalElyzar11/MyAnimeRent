/// Toko publik. `id` berisi slug toko (stabil untuk URL di app & website).
class Store {
  Store({
    required this.id,
    required this.name,
    required this.city,
    required this.imageUrl,
    this.rating = 0.0,
    this.cityCode = '',
    this.description,
    this.policies,
    this.whatsapp,
    this.shipsIntercity = false,
    this.shippingNotes,
    this.productCount = 0,
    this.verifiedAt,
  });

  final String id;
  final String name;
  final String city;
  final String cityCode;

  /// Foto sampul (foto listing terbaru); kosong bila belum ada.
  final String imageUrl;

  /// Ulasan belum tersedia di backend baru; 0 berarti tidak ditampilkan.
  final double rating;
  final String? description;
  final String? policies;
  final String? whatsapp;
  final bool shipsIntercity;
  final String? shippingNotes;
  final int productCount;
  final DateTime? verifiedAt;

  Store withImage(String url) => Store(
        id: id,
        name: name,
        city: city,
        imageUrl: url,
        rating: rating,
        cityCode: cityCode,
        description: description,
        policies: policies,
        whatsapp: whatsapp,
        shipsIntercity: shipsIntercity,
        shippingNotes: shippingNotes,
        productCount: productCount,
        verifiedAt: verifiedAt,
      );

  /// Item dari `list_public_stores`.
  factory Store.fromList(Map<String, dynamic> m, String Function(String) image) {
    final cover = m['cover_path']?.toString();
    return Store(
      id: (m['slug'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
      cityCode: (m['city_code'] ?? '').toString(),
      imageUrl: cover == null || cover.isEmpty ? '' : image(cover),
      description: m['description']?.toString(),
      shipsIntercity: m['ships_intercity'] == true,
      productCount: (m['product_count'] as num?)?.toInt() ?? 0,
      verifiedAt: DateTime.tryParse('${m['verified_at'] ?? ''}'),
    );
  }

  /// Hasil `get_public_store`.
  factory Store.fromPublic(Map<String, dynamic> m, {String imageUrl = ''}) => Store(
        id: (m['slug'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        city: (m['city'] ?? '').toString(),
        cityCode: (m['city_code'] ?? '').toString(),
        imageUrl: imageUrl,
        description: m['description']?.toString(),
        policies: m['policies']?.toString(),
        whatsapp: m['whatsapp']?.toString(),
        shipsIntercity: m['ships_intercity'] == true,
        shippingNotes: m['shipping_notes']?.toString(),
        verifiedAt: DateTime.tryParse('${m['verified_at'] ?? ''}'),
      );
}
