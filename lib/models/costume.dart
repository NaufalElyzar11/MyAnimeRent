/// Listing kostum publik dari Supabase (kartu `search_products` atau detail `get_public_product`).
/// `storeId` berisi slug toko (dipakai di URL `/store_detail/:storeId`).
class CostumeVariant {
  const CostumeVariant({required this.id, required this.size, this.measurementsCm = const {}});

  final String id;
  final String size;
  final Map<String, num> measurementsCm;

  factory CostumeVariant.fromJson(Map<String, dynamic> m) => CostumeVariant(
        id: m['id'].toString(),
        size: (m['size'] ?? '').toString(),
        measurementsCm: {
          for (final e in ((m['measurements_cm'] as Map?) ?? const {}).entries)
            if (e.value is num) e.key.toString(): e.value as num,
        },
      );
}

typedef ImageResolver = String Function(String path);

class Costume {
  Costume({
    required this.id,
    required this.name,
    required this.anime,
    required this.storeId,
    required this.description,
    required this.imageUrls,
    required this.price,
    required this.sizes,
    this.slug = '',
    this.character = '',
    this.storeName = '',
    this.city = '',
    this.durationDays,
    this.extraDayIdr,
    this.depositIdr = 0,
    this.variants = const [],
    this.packageContents = const [],
    this.sizeNotes,
    this.storeWhatsapp,
    this.verifiedAt,
    this.updatedAt,
    this.isAvailable = true,
    this.rating = 0.0,
  });

  final String id;
  final String slug;
  final String name;

  /// Seri/franchise (nama lama dipertahankan agar pengelompokan beranda tetap jalan).
  final String anime;
  final String character;
  final String storeId;
  final String storeName;
  final String city;
  final String description;
  final List<String> imageUrls;

  /// Harga paket (Rp) untuk [durationDays] hari.
  final double price;
  final int? durationDays;
  final int? extraDayIdr;
  final int depositIdr;
  final List<String> sizes;
  final List<CostumeVariant> variants;
  final List<String> packageContents;
  final String? sizeNotes;
  final String? storeWhatsapp;
  final DateTime? verifiedAt;
  final DateTime? updatedAt;
  final bool isAvailable;

  /// Ulasan belum tersedia di backend baru; selalu 0 sehingga badge rating tidak tampil.
  final double rating;

  bool get hasPrice => price > 0 && durationDays != null;

  static String _text(Object? v) => (v ?? '').toString();
  static int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  static List<String> _strings(Object? v) =>
      v is List ? v.where((e) => e != null).map((e) => e.toString()).toList() : const [];

  /// Baris kartu dari `search_products` / `get_public_products_by_ids`.
  factory Costume.fromCard(Map<String, dynamic> m, ImageResolver image) {
    final cover = m['cover_path']?.toString();
    return Costume(
      id: _text(m['product_id']),
      slug: _text(m['product_slug']),
      name: _text(m['title']),
      anime: _text(m['franchise_name']).isNotEmpty ? _text(m['franchise_name']) : 'Lainnya',
      character: _text(m['character_name']),
      storeId: _text(m['store_slug']),
      storeName: _text(m['store_name']),
      city: _text(m['city_name']),
      description: '',
      imageUrls: cover == null || cover.isEmpty ? const [] : [image(cover)],
      price: (_int(m['price_idr']) ?? 0).toDouble(),
      durationDays: _int(m['duration_days']),
      depositIdr: _int(m['deposit_idr']) ?? 0,
      sizes: _strings(m['sizes']),
      verifiedAt: DateTime.tryParse(_text(m['verified_at'])),
      updatedAt: DateTime.tryParse(_text(m['updated_at'])),
    );
  }

  /// Detail dari `get_public_product_by_id`.
  factory Costume.fromDetail(Map<String, dynamic> m, ImageResolver image) {
    final price = (m['price'] as Map?) ?? const {};
    final store = (m['store'] as Map?) ?? const {};
    final variants = ((m['variants'] as List?) ?? const [])
        .whereType<Map>()
        .map((v) => CostumeVariant.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    return Costume(
      id: _text(m['id']),
      slug: _text(m['slug']),
      name: _text(m['title']),
      anime: _text(m['franchise']).isNotEmpty ? _text(m['franchise']) : 'Lainnya',
      character: _text(m['character']),
      storeId: _text(store['slug']),
      storeName: _text(store['name']),
      city: _text(store['city']),
      storeWhatsapp: store['whatsapp']?.toString(),
      description: _text(m['description']),
      imageUrls: ((m['images'] as List?) ?? const [])
          .whereType<Map>()
          .map((i) => i['path']?.toString() ?? '')
          .where((p) => p.isNotEmpty)
          .map(image)
          .toList(),
      price: (_int(price['amount_idr']) ?? 0).toDouble(),
      durationDays: _int(price['duration_days']),
      extraDayIdr: _int(price['extra_day_idr']),
      depositIdr: _int(price['deposit_idr']) ?? 0,
      variants: variants,
      sizes: variants.map((v) => v.size).toList(),
      packageContents: _strings(m['package_contents']),
      sizeNotes: m['size_notes']?.toString(),
      verifiedAt: DateTime.tryParse(_text(m['verified_at'])),
      updatedAt: DateTime.tryParse(_text(m['updated_at'])),
    );
  }

  /// Perkiraan biaya sewa (tanpa deposit) untuk [days] hari, sama dengan rumus server:
  /// harga paket + hari tambahan × tarif per hari (atau harga paket ÷ durasi, dibulatkan ke atas).
  int estimateRent(int days) {
    final d = durationDays;
    if (!hasPrice || d == null || d <= 0) return 0;
    final extra = days > d ? days - d : 0;
    final perDay = extraDayIdr ?? (price / d).ceil();
    return price.toInt() + extra * perDay;
  }
}
