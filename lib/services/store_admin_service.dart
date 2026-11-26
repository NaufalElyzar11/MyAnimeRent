import '../config/event_safety.dart';
import '../models/store_admin.dart';
import 'supabase_service.dart';

/// Operasi "Toko Saya" untuk owner/staf.
/// Bacaan lewat RPC yang memeriksa keanggotaan toko; perubahan lewat Edge Function `rentals`
/// sehingga aturan kalender anti-bentrok dan izin staf tetap di server.
class StoreAdminService {
  StoreAdminService() {
    EventSafety.requireCloudAccess();
  }

  String _img(String path) => Backend.catalogImageUrl(path);

  List<Map<String, dynamic>> _rows(dynamic data) =>
      data is List ? data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

  // ─── Bacaan ───────────────────────────────────────────────
  Future<List<MyStore>> listMyStores() async {
    final data = await Backend.rpc('list_my_stores');
    return _rows(data).map(MyStore.fromJson).toList();
  }

  Future<List<StoreRequest>> listRequests(String storeId, {String? status}) async {
    final data = await Backend.rpc('list_store_requests', {
      'p_store_id': storeId,
      'p_status': status,
      'p_limit': 100,
    });
    return _rows(data).map((m) => StoreRequest.fromJson(m, _img)).toList();
  }

  Future<StoreRequest> getRequest(String requestId) async {
    final data = await Backend.rpc('get_store_request', {'p_request_id': requestId});
    if (data is! Map) throw ApiException('NOT_FOUND', 'Permintaan tidak ditemukan.');
    return StoreRequest.fromJson(Map<String, dynamic>.from(data), _img);
  }

  Future<StoreCalendar> getCalendar(String storeId, {required DateTime from, int days = 62}) async {
    final data = await Backend.rpc('get_store_calendar', {
      'p_store_id': storeId,
      'p_from': dateKey(from),
      'p_days': days,
    });
    if (data is! Map) throw ApiException('INTERNAL', 'Kalender tidak bisa dimuat.');
    return StoreCalendar.fromJson(Map<String, dynamic>.from(data), _img);
  }

  // ─── Permintaan ───────────────────────────────────────────
  Future<void> confirmRequest(StoreRequest r, {required String unitId, required String operationId}) async {
    await Backend.call('rentals', 'confirm_request', {
      'operation_id': operationId,
      'request_id': r.id,
      'expected_revision': r.revision,
      'unit_id': unitId,
    });
  }

  /// [reason]: dates_unavailable | size_unavailable | not_rentable | other
  Future<void> declineRequest(StoreRequest r,
      {required String reason, String? message, required String operationId}) async {
    await Backend.call('rentals', 'decline_request', {
      'operation_id': operationId,
      'request_id': r.id,
      'expected_revision': r.revision,
      'reason': reason,
      'message': (message == null || message.trim().isEmpty) ? null : message.trim(),
    });
  }

  // ─── Kalender ─────────────────────────────────────────────
  /// Sewa dari WhatsApp/Instagram/datang langsung. [lastDay] inklusif; server menambah hari laundry.
  Future<void> recordOfflineOrder({
    required String operationId,
    required String unitId,
    required DateTime firstDay,
    required DateTime lastDay,
    required String source,
    String? customerName,
    String? customerPhone,
    String? note,
  }) async {
    final customer = <String, String>{
      if (customerName != null && customerName.trim().isNotEmpty) 'name': customerName.trim(),
      if (customerPhone != null && customerPhone.trim().isNotEmpty) 'phone': customerPhone.trim(),
    };
    await Backend.call('rentals', 'record_offline_order', {
      'operation_id': operationId,
      'unit_id': unitId,
      'rent_start': dateKey(firstDay),
      'rent_end_exclusive': dateKey(lastDay.add(const Duration(days: 1))),
      'source': source,
      if (customer.isNotEmpty) 'customer': customer,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }

  /// [kind]: laundry | maintenance. [lastDay] inklusif.
  Future<void> blockUnit({
    required String operationId,
    required String unitId,
    required DateTime firstDay,
    required DateTime lastDay,
    required String kind,
    String? note,
  }) async {
    await Backend.call('rentals', 'block_unit', {
      'operation_id': operationId,
      'unit_id': unitId,
      'start': dateKey(firstDay),
      'end_exclusive': dateKey(lastDay.add(const Duration(days: 1))),
      'kind': kind,
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
    });
  }

  Future<void> releaseBlock(String allocationId) async {
    await Backend.call('rentals', 'release_block', {'allocation_id': allocationId});
  }

  /// Membatalkan order yang belum berjalan; kalender langsung kosong kembali.
  /// Untuk order dari app, penyewa otomatis diberi tahu.
  Future<void> cancelOrder({required String orderId, required int version, String? reason}) async {
    await Backend.call('rentals', 'cancel_order', {
      'order_id': orderId,
      'expected_version': version,
      'reason': (reason == null || reason.trim().isEmpty) ? null : reason.trim(),
    });
  }
}
