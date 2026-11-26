import '../services/supabase_service.dart' show parseDate;

int? _int(Object? v) => (v as num?)?.toInt();
String? _str(Object? v) {
  final s = v?.toString();
  return (s == null || s.trim().isEmpty) ? null : s;
}

List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();

/// Kekurangan agar listing bisa terbit (kode dari server → teks untuk toko).
const missingLabels = {
  'character': 'Nama karakter',
  'price': 'Harga sewa',
  'variant': 'Minimal 1 ukuran',
  'image': 'Minimal 1 foto',
  'publication_consent': 'Izin tampil publik',
};

String missingText(List<String> missing) => missing.map((m) => missingLabels[m] ?? m).join(', ');

const productStatusLabels = {'draft': 'Draft', 'published': 'Terbit', 'archived': 'Diarsipkan'};

const categoryLabels = {
  'costume': 'Kostum',
  'wig': 'Wig',
  'prop': 'Properti',
  'accessory': 'Aksesori',
  'set': 'Set lengkap',
};

/// Satu baris di daftar katalog toko (`list_store_products`).
class StoreProductSummary {
  StoreProductSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.revision,
    this.slug,
    this.characterName,
    this.franchiseName,
    this.coverUrl = '',
    this.imageCount = 0,
    this.sizes = const [],
    this.priceIdr,
    this.durationDays,
    this.depositIdr,
    this.missing = const [],
    this.updatedAt,
  });

  final String id;
  final String? slug;
  final String title;
  final String status;
  final int revision;
  final String? characterName;
  final String? franchiseName;
  final String coverUrl;
  final int imageCount;
  final List<String> sizes;
  final int? priceIdr;
  final int? durationDays;
  final int? depositIdr;
  final List<String> missing;
  final DateTime? updatedAt;

  bool get isDraft => status == 'draft';
  bool get isPublished => status == 'published';
  bool get isArchived => status == 'archived';
  bool get readyToPublish => missing.isEmpty;

  factory StoreProductSummary.fromJson(Map<String, dynamic> m, String Function(String) image) {
    final cover = _str(m['cover_path']);
    return StoreProductSummary(
      id: m['product_id'].toString(),
      slug: _str(m['slug']),
      title: (m['title'] ?? '').toString(),
      status: (m['status'] ?? 'draft').toString(),
      revision: _int(m['revision']) ?? 1,
      characterName: _str(m['character_name']),
      franchiseName: _str(m['franchise_name']),
      coverUrl: cover == null ? '' : image(cover),
      imageCount: _int(m['image_count']) ?? 0,
      sizes: _strings(m['sizes']),
      priceIdr: _int(m['price_idr']),
      durationDays: _int(m['duration_days']),
      depositIdr: _int(m['deposit_idr']),
      missing: _strings(m['missing_for_publish']),
      updatedAt: parseDate(m['updated_at']),
    );
  }
}

/// Ukuran yang bisa diedit. [id] null = ukuran baru; ukuran ukur badan dibawa apa adanya.
class EditableVariant {
  EditableVariant({required this.sizeLabel, this.id, this.measurements = const {}, this.enabled = true});

  final String? id;
  final String sizeLabel;
  final Map<String, dynamic> measurements;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'size_label': sizeLabel,
        if (measurements.isNotEmpty) 'measurements_cm': measurements,
        'enabled': true,
      };

  factory EditableVariant.fromJson(Map<String, dynamic> m) => EditableVariant(
        id: _str(m['id']),
        sizeLabel: (m['size_label'] ?? '').toString(),
        measurements: m['measurements_cm'] is Map ? Map<String, dynamic>.from(m['measurements_cm'] as Map) : const {},
        enabled: m['enabled'] != false,
      );
}

/// Harga aktif listing. Setiap perubahan menjadi versi harga baru di server; order lama tetap.
class EditablePrice {
  EditablePrice({
    required this.amountIdr,
    required this.durationDays,
    this.extraDayIdr,
    this.depositIdr = 0,
    this.bufferBeforeDays = 0,
    this.bufferAfterDays = 1,
  });

  final int amountIdr;
  final int durationDays;
  final int? extraDayIdr;
  final int depositIdr;
  final int bufferBeforeDays;
  final int bufferAfterDays;

  Map<String, dynamic> toJson() => {
        'amount_idr': amountIdr,
        'duration_days': durationDays,
        'extra_day_idr': extraDayIdr,
        'deposit_idr': depositIdr,
        'buffer_before_days': bufferBeforeDays,
        'buffer_after_days': bufferAfterDays,
      };

  bool sameAs(EditablePrice? o) =>
      o != null &&
      o.amountIdr == amountIdr &&
      o.durationDays == durationDays &&
      o.extraDayIdr == extraDayIdr &&
      o.depositIdr == depositIdr &&
      o.bufferBeforeDays == bufferBeforeDays &&
      o.bufferAfterDays == bufferAfterDays;

  factory EditablePrice.fromJson(Map<String, dynamic> m) => EditablePrice(
        amountIdr: _int(m['amount_idr']) ?? 0,
        durationDays: _int(m['duration_days']) ?? 1,
        extraDayIdr: _int(m['extra_day_idr']),
        depositIdr: _int(m['deposit_idr']) ?? 0,
        bufferBeforeDays: _int(m['buffer_before_days']) ?? 0,
        bufferAfterDays: _int(m['buffer_after_days']) ?? 1,
      );
}

class ProductImage {
  ProductImage({required this.id, required this.path, required this.url, required this.position});
  final String id;
  final String path;
  final String url;
  final int position;

  factory ProductImage.fromJson(Map<String, dynamic> m, String Function(String) image) => ProductImage(
        id: m['image_id'].toString(),
        path: (m['storage_path'] ?? '').toString(),
        url: image((m['storage_path'] ?? '').toString()),
        position: _int(m['position']) ?? 1,
      );
}

/// Isi form edit listing (`get_store_product`).
class StoreProductDetail {
  StoreProductDetail({
    required this.id,
    required this.storeId,
    required this.title,
    required this.status,
    required this.revision,
    this.slug,
    this.category = 'costume',
    this.characterName,
    this.franchiseName,
    this.description,
    this.packageContents = const [],
    this.sizeNotes,
    this.publicationConsent = false,
    this.aliases = const [],
    this.variants = const [],
    this.price,
    this.images = const [],
    this.missing = const [],
    this.storeStatus,
  });

  final String id;
  final String storeId;
  final String? slug;
  final String title;
  final String status;
  final int revision;
  final String category;
  final String? characterName;
  final String? franchiseName;
  final String? description;
  final List<String> packageContents;
  final String? sizeNotes;
  final bool publicationConsent;
  final List<String> aliases;
  final List<EditableVariant> variants;
  final EditablePrice? price;
  final List<ProductImage> images;
  final List<String> missing;
  final String? storeStatus;

  List<EditableVariant> get activeVariants => variants.where((v) => v.enabled).toList();

  factory StoreProductDetail.fromJson(Map<String, dynamic> m, String Function(String) image) {
    final price = m['price'];
    return StoreProductDetail(
      id: m['product_id'].toString(),
      storeId: (m['store_id'] ?? '').toString(),
      slug: _str(m['slug']),
      title: (m['title'] ?? '').toString(),
      status: (m['status'] ?? 'draft').toString(),
      revision: _int(m['revision']) ?? 1,
      category: (m['category'] ?? 'costume').toString(),
      characterName: _str(m['character_name']),
      franchiseName: _str(m['franchise_name']),
      description: _str(m['description']),
      packageContents: _strings(m['package_contents']),
      sizeNotes: _str(m['size_notes']),
      publicationConsent: m['publication_consent'] == true,
      aliases: _strings(m['aliases']),
      variants: ((m['variants'] as List?) ?? const [])
          .whereType<Map>()
          .map((v) => EditableVariant.fromJson(Map<String, dynamic>.from(v)))
          .toList(),
      price: price is Map ? EditablePrice.fromJson(Map<String, dynamic>.from(price)) : null,
      images: ((m['images'] as List?) ?? const [])
          .whereType<Map>()
          .map((i) => ProductImage.fromJson(Map<String, dynamic>.from(i), image))
          .toList(),
      missing: _strings(m['missing_for_publish']),
      storeStatus: _str(m['store_status']),
    );
  }
}

/// Profil toko untuk form edit owner (`get_my_store`).
class StoreProfile {
  StoreProfile({
    required this.id,
    required this.slug,
    required this.name,
    required this.status,
    required this.revision,
    required this.cityCode,
    this.city,
    this.description,
    this.publicPolicies,
    this.whatsapp,
    this.contactPublic = false,
    this.shipsIntercity = false,
    this.shippingNotes,
    this.consentAt,
    this.isOwner = false,
    this.planId,
    this.publishedProducts = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String status;
  final int revision;
  final String cityCode;
  final String? city;
  final String? description;
  final String? publicPolicies;
  final String? whatsapp;
  final bool contactPublic;
  final bool shipsIntercity;
  final String? shippingNotes;
  final DateTime? consentAt;
  final bool isOwner;
  final String? planId;
  final int publishedProducts;

  bool get isPublished => status == 'published';

  factory StoreProfile.fromJson(Map<String, dynamic> m) => StoreProfile(
        id: m['store_id'].toString(),
        slug: (m['slug'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        status: (m['status'] ?? 'draft').toString(),
        revision: _int(m['revision']) ?? 1,
        cityCode: (m['city_code'] ?? '').toString(),
        city: _str(m['city']),
        description: _str(m['description']),
        publicPolicies: _str(m['public_policies']),
        whatsapp: _str(m['whatsapp_e164']),
        contactPublic: m['contact_public'] == true,
        shipsIntercity: m['ships_intercity'] == true,
        shippingNotes: _str(m['shipping_notes']),
        consentAt: parseDate(m['publication_consent_at']),
        isOwner: m['is_owner'] == true,
        planId: _str(m['plan_id']),
        publishedProducts: _int(m['published_products']) ?? 0,
      );
}

class City {
  City({required this.code, required this.name, this.province});
  final String code;
  final String name;
  final String? province;

  factory City.fromJson(Map<String, dynamic> m) =>
      City(code: m['code'].toString(), name: (m['name'] ?? '').toString(), province: _str(m['province']));
}
