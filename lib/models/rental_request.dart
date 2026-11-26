import '../services/supabase_service.dart' show parseDate;

/// Status permintaan sewa (sama dengan backend).
enum RequestStatus { submitted, responded, accepted, declined, cancelled, expired }

extension RequestStatusX on RequestStatus {
  String get label => switch (this) {
        RequestStatus.submitted => 'Menunggu toko',
        RequestStatus.responded => 'Dibalas toko',
        RequestStatus.accepted => 'Dikonfirmasi',
        RequestStatus.declined => 'Ditolak',
        RequestStatus.cancelled => 'Dibatalkan',
        RequestStatus.expired => 'Kedaluwarsa',
      };

  /// Label untuk layar toko.
  String get storeLabel => switch (this) {
        RequestStatus.submitted => 'Baru',
        RequestStatus.responded => 'Sudah dibalas',
        RequestStatus.accepted => 'Dikonfirmasi',
        RequestStatus.declined => 'Ditolak',
        RequestStatus.cancelled => 'Dibatalkan',
        RequestStatus.expired => 'Kedaluwarsa',
      };

  /// Masih bisa dibatalkan penyewa / dibalas lewat pesan.
  bool get isOpen => this == RequestStatus.submitted || this == RequestStatus.responded;
  bool get canMessage => isOpen || this == RequestStatus.accepted;

  static RequestStatus parse(Object? v) => RequestStatus.values.firstWhere(
        (s) => s.name == v?.toString(),
        orElse: () => RequestStatus.submitted,
      );
}

/// Permintaan sewa milik penyewa (dari `list_my_requests`).
class RentalRequest {
  RentalRequest({
    required this.id,
    required this.code,
    required this.status,
    required this.revision,
    required this.productId,
    required this.productTitle,
    required this.storeSlug,
    required this.storeName,
    required this.rentStart,
    required this.rentEndExclusive,
    required this.createdAt,
    this.size,
    this.note,
    this.closedReason,
    this.closedBy,
    this.coverUrl = '',
    this.storeWhatsapp,
    this.totalRentIdr,
    this.depositIdr,
    this.lastMessageAt,
  });

  final String id;
  final String code;
  final RequestStatus status;
  final int revision;
  final String productId;
  final String productTitle;
  final String storeSlug;
  final String storeName;
  final String? size;
  final DateTime rentStart;
  final DateTime rentEndExclusive;
  final String? note;
  final String? closedReason;
  final String? closedBy;
  final String coverUrl;
  final String? storeWhatsapp;

  /// Terisi setelah toko mengonfirmasi (harga final dari server).
  final int? totalRentIdr;
  final int? depositIdr;
  final DateTime createdAt;
  final DateTime? lastMessageAt;

  /// Tanggal terakhir sewa (inklusif) untuk ditampilkan.
  DateTime get rentEnd => rentEndExclusive.subtract(const Duration(days: 1));
  int get days => rentEndExclusive.difference(rentStart).inDays;

  factory RentalRequest.fromJson(Map<String, dynamic> m, String Function(String) image) {
    final order = m['order'] is Map ? Map<String, dynamic>.from(m['order'] as Map) : null;
    final cover = m['cover_path']?.toString();
    return RentalRequest(
      id: m['id'].toString(),
      code: (m['request_code'] ?? '').toString(),
      status: RequestStatusX.parse(m['status']),
      revision: (m['revision'] as num?)?.toInt() ?? 1,
      productId: (m['product_id'] ?? '').toString(),
      productTitle: (m['product_title'] ?? '').toString(),
      storeSlug: (m['store_slug'] ?? '').toString(),
      storeName: (m['store_name'] ?? '').toString(),
      size: m['size']?.toString(),
      rentStart: parseDate(m['rent_start']) ?? DateTime.now(),
      rentEndExclusive: parseDate(m['rent_end_exclusive']) ?? DateTime.now(),
      note: m['note']?.toString(),
      closedReason: m['closed_reason']?.toString(),
      closedBy: m['closed_by']?.toString(),
      coverUrl: cover == null || cover.isEmpty ? '' : image(cover),
      storeWhatsapp: m['store_whatsapp']?.toString(),
      totalRentIdr: (order?['total_rent_idr'] as num?)?.toInt(),
      depositIdr: (order?['deposit_idr'] as num?)?.toInt(),
      createdAt: parseDate(m['created_at']) ?? DateTime.now(),
      lastMessageAt: parseDate(m['last_message_at']),
    );
  }
}

/// Pesan dalam satu permintaan (pengganti chat WA).
class RequestMessage {
  RequestMessage({required this.id, required this.fromStore, required this.body, required this.createdAt});

  final String id;
  final bool fromStore;
  final String body;
  final DateTime createdAt;

  factory RequestMessage.fromJson(Map<String, dynamic> m) => RequestMessage(
        id: m['id'].toString(),
        fromStore: m['author_role'] == 'store',
        body: (m['body'] ?? '').toString(),
        createdAt: parseDate(m['created_at']) ?? DateTime.now(),
      );
}
