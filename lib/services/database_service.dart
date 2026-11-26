import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/event_safety.dart';
import '../models/app_notification.dart';
import '../models/availability.dart';
import '../models/costume.dart';
import '../models/rental_request.dart';
import '../models/store.dart';
import 'supabase_service.dart';

/// Semua data aplikasi lewat Supabase:
/// - baca publik: fungsi RPC (`search_products`, `get_public_product_by_id`, …)
/// - milik sendiri: tabel dengan RLS (`wishlists`, `notifications`, `request_messages`)
/// - perubahan penting: Edge Functions (`rentals`, `events`) — server yang memeriksa aturan.
class DatabaseService {
  DatabaseService() {
    EventSafety.requireCloudAccess();
  }

  String _img(String path) => Backend.catalogImageUrl(path);

  List<Map<String, dynamic>> _rows(dynamic data) =>
      data is List ? data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

  // ─── Katalog publik ─────────────────────────────────────────
  Future<List<Costume>> searchProducts({
    String? query,
    String? cityCode,
    String? size,
    String? storeSlug,
    bool includeShipping = true,
    int? maxPriceIdr,
    int limit = 24,
    int offset = 0,
  }) async {
    final data = await Backend.rpc('search_products', {
      'p_query': (query == null || query.trim().isEmpty) ? null : query.trim(),
      'p_city_code': cityCode,
      'p_include_shipping': includeShipping,
      'p_size': size,
      'p_max_price_idr': maxPriceIdr,
      'p_store_slug': storeSlug,
      'p_limit': limit,
      'p_offset': offset,
    });
    return _rows(data).map((m) => Costume.fromCard(m, _img)).toList();
  }

  /// Seluruh katalog publik (maks. [maxPages] × 24 listing) untuk beranda.
  Future<List<Costume>> getCostumes({int maxPages = 4, String? storeSlug}) async {
    final all = <Costume>[];
    for (var page = 0; page < maxPages; page++) {
      final batch = await searchProducts(storeSlug: storeSlug, offset: page * 24);
      all.addAll(batch);
      if (batch.length < 24) break;
    }
    return all;
  }

  Future<Costume?> getCostumeById(String id) async {
    final data = await Backend.rpc('get_public_product_by_id', {'p_product_id': id});
    return data is Map ? Costume.fromDetail(Map<String, dynamic>.from(data), _img) : null;
  }

  Future<List<Costume>> getCostumesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final data = await Backend.rpc('get_public_products_by_ids', {'p_ids': ids});
    return _rows(data).map((m) => Costume.fromCard(m, _img)).toList();
  }

  /// Kota (kode wilayah) untuk filter pencarian.
  Future<List<({String code, String name})>> listCities() async {
    try {
      final rows = await Backend.client.from('cities').select('code, name').order('name').timeout(Backend.rpcTimeout);
      return [for (final r in rows) (code: r['code'].toString(), name: (r['name'] ?? '').toString())];
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    } catch (_) {
      throw ApiException('TEMPORARILY_UNAVAILABLE', 'Daftar kota belum bisa dimuat.');
    }
  }

  Future<List<Store>> getStores({String? cityCode}) async {
    final data = await Backend.rpc('list_public_stores', {'p_city_code': cityCode, 'p_limit': 100});
    return _rows(data).map((m) => Store.fromList(m, _img)).toList();
  }

  Future<Store?> getStoreBySlug(String slug) async {
    final data = await Backend.rpc('get_public_store', {'p_slug': slug});
    return data is Map ? Store.fromPublic(Map<String, dynamic>.from(data)) : null;
  }

  /// Tanggal terisi per ukuran; bila [rentStart] diisi, tiap ukuran diberi status untuk tanggal itu.
  Future<ProductAvailability?> getAvailability(
    String productId, {
    DateTime? rentStart,
    DateTime? rentEndExclusive,
    int days = 120,
  }) async {
    final data = await Backend.rpc('get_product_availability', {
      'p_product_id': productId,
      'p_days': days,
      'p_rent_start': rentStart == null ? null : dateKey(rentStart),
      'p_rent_end_exclusive': rentEndExclusive == null ? null : dateKey(rentEndExclusive),
    });
    return data is Map ? ProductAvailability.fromJson(Map<String, dynamic>.from(data)) : null;
  }

  /// Klik tombol WhatsApp toko (best-effort; kegagalan tidak memblokir tombol).
  Future<void> recordContactClick(String productId) async {
    try {
      await Backend.call('events', 'record', {'type': 'contact_click', 'product_id': productId, 'source': 'app'});
    } catch (_) {}
  }

  // ─── Wishlist (RLS: milik sendiri) ─────────────────────────
  Future<List<String>> getWishlistIds(String userId) async {
    try {
      final rows = await Backend.client
          .from('wishlists')
          .select('product_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return rows.map((r) => r['product_id'].toString()).toList();
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    }
  }

  Future<void> addToWishlist(String userId, String productId) async {
    try {
      await Backend.client.from('wishlists').insert({'user_id': userId, 'product_id': productId});
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // sudah ada di wishlist
      throw Backend.fromPostgrest(e);
    }
  }

  Future<void> removeFromWishlist(String userId, String productId) async {
    try {
      await Backend.client.from('wishlists').delete().eq('user_id', userId).eq('product_id', productId);
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    }
  }

  // ─── Permintaan sewa ───────────────────────────────────────
  /// [idempotencyKey] dibuat sekali per tombol "Kirim" dan dipakai ulang saat retry.
  Future<({String requestId, String requestCode})> createRequest({
    required String idempotencyKey,
    required String productId,
    String? variantId,
    required DateTime rentStart,
    required DateTime rentEndExclusive,
    String? note,
    required bool contactConsent,
  }) async {
    final data = await Backend.call('rentals', 'create_request', {
      'idempotency_key': idempotencyKey,
      'product_id': productId,
      'variant_id': variantId,
      'rent_start': dateKey(rentStart),
      'rent_end_exclusive': dateKey(rentEndExclusive),
      'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
      'contact_consent': contactConsent,
      'source': 'app',
    });
    return (requestId: data['request_id'].toString(), requestCode: data['request_code'].toString());
  }

  Future<List<RentalRequest>> listMyRequests() async {
    final data = await Backend.rpc('list_my_requests', {'p_limit': 100});
    return _rows(data).map((m) => RentalRequest.fromJson(m, _img)).toList();
  }

  Future<RentalRequest?> getMyRequest(String id) async {
    final data = await Backend.rpc('list_my_requests', {'p_request_id': id});
    final rows = _rows(data);
    return rows.isEmpty ? null : RentalRequest.fromJson(rows.first, _img);
  }

  Future<void> cancelMyRequest(RentalRequest request, {required String operationId, String? reason}) async {
    await Backend.call('rentals', 'cancel_my_request', {
      'operation_id': operationId,
      'request_id': request.id,
      'expected_revision': request.revision,
      'reason': reason,
    });
  }

  Future<List<RequestMessage>> getMessages(String requestId) async {
    try {
      final rows = await Backend.client
          .from('request_messages')
          .select('id, author_role, body, created_at')
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      return rows.map(RequestMessage.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    }
  }

  Future<void> postMessage(String requestId, String body, {required String operationId}) async {
    await Backend.call('rentals', 'post_message', {
      'operation_id': operationId,
      'request_id': requestId,
      'body': body,
    });
  }

  // ─── Notifikasi (RLS: milik sendiri) ───────────────────────
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    try {
      final rows = await Backend.client
          .from('notifications')
          .select('id, kind, title, body, data, read_at, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(AppNotification.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    }
  }

  Future<void> markNotificationsRead(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await Backend.client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .inFilter('id', ids);
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    }
  }

  /// Notifikasi baru secara langsung selama app terbuka (Realtime, tetap mengikuti RLS).
  RealtimeChannel subscribeNotifications(String userId, void Function(AppNotification) onInsert) {
    return Backend.client
        .channel('notifikasi-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => onInsert(AppNotification.fromJson(payload.newRecord)),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    try {
      await Backend.client.removeChannel(channel);
    } catch (_) {}
  }
}
