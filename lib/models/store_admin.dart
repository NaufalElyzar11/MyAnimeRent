import '../services/supabase_service.dart' show parseDate;
import 'rental_request.dart';

int? _int(Object? v) => (v as num?)?.toInt();
String? _str(Object? v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// Toko tempat pengguna menjadi owner/staf (`list_my_stores`).
class MyStore {
  MyStore({
    required this.id,
    required this.slug,
    required this.name,
    required this.status,
    required this.role,
    required this.permissions,
    required this.calendarEnabled,
    this.city,
    this.planId,
    this.openRequests = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String status;
  final String? city;
  final String role;
  final Set<String> permissions;
  final String? planId;
  final bool calendarEnabled;
  final int openRequests;

  bool get isOwner => role == 'owner';
  bool can(String permission) => isOwner || permissions.contains(permission);
  bool get canOrders => can('orders');
  bool get canCalendar => can('calendar');
  bool get canCatalog => can('catalog');

  factory MyStore.fromJson(Map<String, dynamic> m) => MyStore(
        id: m['store_id'].toString(),
        slug: (m['slug'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        status: (m['status'] ?? '').toString(),
        city: _str(m['city']),
        role: (m['role'] ?? 'staff').toString(),
        permissions: ((m['permissions'] as List?) ?? const []).map((e) => e.toString()).toSet(),
        planId: _str(m['plan_id']),
        calendarEnabled: m['calendar_enabled'] == true,
        openRequests: _int(m['open_requests']) ?? 0,
      );
}

/// Unit fisik yang bisa dipilih saat mengonfirmasi permintaan.
class UnitOption {
  UnitOption({required this.unitId, required this.free, this.code, this.size});
  final String unitId;
  final String? code;
  final String? size;
  final bool free;

  String get label => [if (size != null) 'Ukuran $size', ?code].join(' · ');

  factory UnitOption.fromJson(Map<String, dynamic> m) => UnitOption(
        unitId: m['unit_id'].toString(),
        code: _str(m['internal_code']),
        size: _str(m['size']),
        free: m['free'] == true,
      );
}

/// Permintaan sewa dari sisi toko (`list_store_requests` / `get_store_request`).
class StoreRequest {
  StoreRequest({
    required this.id,
    required this.code,
    required this.status,
    required this.revision,
    required this.productId,
    required this.productTitle,
    required this.rentStart,
    required this.rentEndExclusive,
    required this.createdAt,
    this.size,
    this.note,
    this.source,
    this.closedReason,
    this.closedBy,
    this.lastMessageAt,
    this.renterName,
    this.renterPhone,
    this.storeId,
    this.storeName,
    this.coverUrl = '',
    this.calendarEnabled = false,
    this.blockStart,
    this.blockEndExclusive,
    this.estimateRentIdr,
    this.estimateDepositIdr,
    this.orderId,
    this.orderVersion,
    this.orderStatus,
    this.totalRentIdr,
    this.depositIdr,
    this.units = const [],
  });

  final String id;
  final String code;
  final RequestStatus status;
  final int revision;
  final String productId;
  final String productTitle;
  final String? size;
  final DateTime rentStart;
  final DateTime rentEndExclusive;
  final String? note;
  final String? source;
  final String? closedReason;
  final String? closedBy;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? renterName;

  /// Hanya terisi bila penyewa mengizinkan kontaknya dibagikan.
  final String? renterPhone;

  // Hanya dari detail (`get_store_request`).
  final String? storeId;
  final String? storeName;
  final String coverUrl;
  final bool calendarEnabled;
  final DateTime? blockStart;
  final DateTime? blockEndExclusive;
  final int? estimateRentIdr;
  final int? estimateDepositIdr;
  final String? orderId;
  final int? orderVersion;
  final String? orderStatus;
  final int? totalRentIdr;
  final int? depositIdr;
  final List<UnitOption> units;

  DateTime get rentEnd => rentEndExclusive.subtract(const Duration(days: 1));
  int get days => rentEndExclusive.difference(rentStart).inDays;
  bool get needsAnswer => status.isOpen;
  List<UnitOption> get freeUnits => units.where((u) => u.free).toList();

  factory StoreRequest.fromJson(Map<String, dynamic> m, String Function(String) image) {
    final renter = _map(m['renter']);
    final order = _map(m['order']);
    final quote = _map(m['quote']);
    final cover = _str(m['cover_path']);
    return StoreRequest(
      id: m['id'].toString(),
      code: (m['request_code'] ?? '').toString(),
      status: RequestStatusX.parse(m['status']),
      revision: _int(m['revision']) ?? 1,
      productId: (m['product_id'] ?? '').toString(),
      productTitle: (m['product_title'] ?? '').toString(),
      size: _str(m['size']),
      rentStart: parseDate(m['rent_start']) ?? DateTime.now(),
      rentEndExclusive: parseDate(m['rent_end_exclusive']) ?? DateTime.now(),
      note: _str(m['note']),
      source: _str(m['source']),
      closedReason: _str(m['closed_reason']),
      closedBy: _str(m['closed_by']),
      createdAt: parseDate(m['created_at']) ?? DateTime.now(),
      lastMessageAt: parseDate(m['last_message_at']),
      renterName: _str(renter?['display_name']),
      renterPhone: _str(renter?['phone']),
      storeId: _str(m['store_id']),
      storeName: _str(m['store_name']),
      coverUrl: cover == null ? '' : image(cover),
      calendarEnabled: m['calendar_enabled'] == true,
      blockStart: parseDate(m['block_start']),
      blockEndExclusive: parseDate(m['block_end_exclusive']),
      estimateRentIdr: _int(quote?['total_rent_idr']),
      estimateDepositIdr: _int(quote?['deposit_idr']),
      orderId: _str(order?['id']),
      orderVersion: _int(order?['version']),
      orderStatus: _str(order?['rental_status']),
      totalRentIdr: _int(order?['total_rent_idr']),
      depositIdr: _int(order?['deposit_idr']),
      units: ((m['units'] as List?) ?? const [])
          .whereType<Map>()
          .map((u) => UnitOption.fromJson(Map<String, dynamic>.from(u)))
          .toList(),
    );
  }
}

/// Satu set fisik di kalender toko.
class CalendarUnit {
  CalendarUnit({
    required this.unitId,
    required this.productId,
    required this.productTitle,
    this.code,
    this.size,
    this.lifecycle = 'active',
    this.productStatus,
    this.coverUrl = '',
  });

  final String unitId;
  final String productId;
  final String productTitle;
  final String? code;
  final String? size;
  final String lifecycle;
  final String? productStatus;
  final String coverUrl;

  bool get isActive => lifecycle == 'active';
  String get sizeLabel => size == null ? 'Tanpa ukuran' : 'Ukuran $size';

  factory CalendarUnit.fromJson(Map<String, dynamic> m, String Function(String) image) {
    final cover = _str(m['cover_path']);
    return CalendarUnit(
      unitId: m['unit_id'].toString(),
      productId: (m['product_id'] ?? '').toString(),
      productTitle: (m['product_title'] ?? '').toString(),
      code: _str(m['internal_code']),
      size: _str(m['size']),
      lifecycle: (m['lifecycle'] ?? 'active').toString(),
      productStatus: _str(m['product_status']),
      coverUrl: cover == null ? '' : image(cover),
    );
  }
}

/// Order di balik sebuah alokasi kalender (sewa dari app atau dicatat dari WA/IG).
class AllocationOrder {
  AllocationOrder({
    required this.id,
    required this.version,
    required this.source,
    required this.rentalStatus,
    required this.rentStart,
    required this.rentEndExclusive,
    this.requestId,
    this.requestCode,
    this.totalRentIdr,
    this.depositIdr,
    this.customerName,
    this.customerPhone,
    this.customerNote,
  });

  final String id;
  final int version;
  final String source;
  final String rentalStatus;
  final DateTime rentStart;
  final DateTime rentEndExclusive;
  final String? requestId;
  final String? requestCode;
  final int? totalRentIdr;
  final int? depositIdr;
  final String? customerName;
  final String? customerPhone;
  final String? customerNote;

  DateTime get rentEnd => rentEndExclusive.subtract(const Duration(days: 1));
  bool get canCancel => rentalStatus == 'confirmed';

  String get sourceLabel => switch (source) {
        'platform' => 'MyAnimeRent',
        'whatsapp' => 'WhatsApp',
        'instagram' => 'Instagram',
        'walk_in' => 'Datang langsung',
        _ => 'Lainnya',
      };

  factory AllocationOrder.fromJson(Map<String, dynamic> m) => AllocationOrder(
        id: m['id'].toString(),
        version: _int(m['version']) ?? 1,
        source: (m['source'] ?? 'other').toString(),
        rentalStatus: (m['rental_status'] ?? 'confirmed').toString(),
        rentStart: parseDate(m['rent_start']) ?? DateTime.now(),
        rentEndExclusive: parseDate(m['rent_end_exclusive']) ?? DateTime.now(),
        requestId: _str(m['request_id']),
        requestCode: _str(m['request_code']),
        totalRentIdr: _int(m['total_rent_idr']),
        depositIdr: _int(m['deposit_idr']),
        customerName: _str(m['customer_name']),
        customerPhone: _str(m['customer_phone']),
        customerNote: _str(m['customer_note']),
      );
}

/// Rentang terpakai pada satu unit: sewa, laundry, atau perbaikan.
class Allocation {
  Allocation({
    required this.id,
    required this.unitId,
    required this.kind,
    required this.start,
    required this.endExclusive,
    this.note,
    this.order,
  });

  final String id;
  final String unitId;
  final String kind; // order | offline_order | laundry | maintenance | hold
  final DateTime start;
  final DateTime endExclusive;
  final String? note;
  final AllocationOrder? order;

  bool get isRental => kind == 'order' || kind == 'offline_order';
  bool get isBlock => kind == 'laundry' || kind == 'maintenance';
  DateTime get end => endExclusive.subtract(const Duration(days: 1));

  String get kindLabel => switch (kind) {
        'order' => 'Sewa via app',
        'offline_order' => 'Sewa ${order?.sourceLabel ?? 'offline'}',
        'laundry' => 'Laundry',
        'maintenance' => 'Perbaikan',
        _ => 'Ditahan',
      };

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && d.isBefore(endExclusive);
  }

  factory Allocation.fromJson(Map<String, dynamic> m) {
    final order = _map(m['order']);
    return Allocation(
      id: m['allocation_id'].toString(),
      unitId: m['unit_id'].toString(),
      kind: (m['kind'] ?? 'hold').toString(),
      start: parseDate(m['start']) ?? DateTime.now(),
      endExclusive: parseDate(m['end_exclusive']) ?? DateTime.now(),
      note: _str(m['note']),
      order: order == null ? null : AllocationOrder.fromJson(order),
    );
  }
}

/// Jadwal toko dalam satu jendela tanggal (`get_store_calendar`).
class StoreCalendar {
  StoreCalendar({
    required this.calendarEnabled,
    required this.canManageOrders,
    required this.canManageCalendar,
    required this.from,
    required this.toExclusive,
    required this.units,
    required this.allocations,
  });

  final bool calendarEnabled;
  final bool canManageOrders;
  final bool canManageCalendar;
  final DateTime from;
  final DateTime toExclusive;
  final List<CalendarUnit> units;
  final List<Allocation> allocations;

  List<Allocation> forUnit(String unitId) => allocations.where((a) => a.unitId == unitId).toList();

  factory StoreCalendar.fromJson(Map<String, dynamic> m, String Function(String) image) => StoreCalendar(
        calendarEnabled: m['calendar_enabled'] == true,
        canManageOrders: m['can_manage_orders'] == true,
        canManageCalendar: m['can_manage_calendar'] == true,
        from: parseDate(m['from']) ?? DateTime.now(),
        toExclusive: parseDate(m['to_exclusive']) ?? DateTime.now(),
        units: ((m['units'] as List?) ?? const [])
            .whereType<Map>()
            .map((u) => CalendarUnit.fromJson(Map<String, dynamic>.from(u), image))
            .toList(),
        allocations: ((m['allocations'] as List?) ?? const [])
            .whereType<Map>()
            .map((a) => Allocation.fromJson(Map<String, dynamic>.from(a)))
            .toList(),
      );
}
