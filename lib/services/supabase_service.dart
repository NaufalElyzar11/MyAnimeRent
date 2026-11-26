import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/event_safety.dart';

/// Error terstruktur dari backend. [code] mengikuti kontrak API (UNAUTHENTICATED, FORBIDDEN,
/// NOT_FOUND, VALIDATION_ERROR, CONFLICT, UNIT_UNAVAILABLE, RATE_LIMITED,
/// TEMPORARILY_UNAVAILABLE, INTERNAL); [reason] alasan spesifik (mis. STALE_REVISION).
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.reason, this.details, this.status});

  final String code;
  final String message;
  final String? reason;
  final Map<String, dynamic>? details;
  final int? status;

  bool get isNetwork => code == 'TEMPORARILY_UNAVAILABLE';
  bool get needsLogin => code == 'UNAUTHENTICATED';

  @override
  String toString() => message;
}

const _networkMessage =
    'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.';

const _sqlStates = {
  'MR401': 'UNAUTHENTICATED',
  'MR402': 'FEATURE_NOT_AVAILABLE',
  'MR403': 'FORBIDDEN',
  'MR404': 'NOT_FOUND',
  'MR409': 'CONFLICT',
  'MR422': 'VALIDATION_ERROR',
  'MR429': 'RATE_LIMITED',
  '42501': 'FORBIDDEN',
};

/// Akses tunggal ke Supabase. Setiap pemanggilan memeriksa [EventSafety] sehingga
/// flavor event (offline) tidak pernah menyentuh jaringan.
abstract final class Backend {
  /// Batas tunggu agar layar tidak memutar loading selamanya saat server tak terjangkau
  /// (mis. alamat salah, HP di jaringan lain, firewall). Fungsi Edge diberi waktu lebih
  /// karena bisa lambat saat pertama kali dipanggil (cold start).
  static const rpcTimeout = Duration(seconds: 15);
  static const functionTimeout = Duration(seconds: 25);

  static SupabaseClient get client {
    EventSafety.requireCloudAccess();
    return Supabase.instance.client;
  }

  static User? get currentUser => client.auth.currentUser;

  /// Memanggil aksi Edge Function: body `{action, ...input}` → `data` dari amplop sukses.
  static Future<Map<String, dynamic>> call(
    String function,
    String action, [
    Map<String, dynamic> input = const {},
  ]) async {
    final functions = client.functions; // di luar try: mode event harus melempar StateError
    final FunctionResponse res;
    try {
      res = await functions
          .invoke(function, body: {'action': action, ...input})
          .timeout(functionTimeout);
    } on FunctionException catch (e) {
      throw _fromFunction(e);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('TEMPORARILY_UNAVAILABLE', _networkMessage);
    }
    final body = res.data;
    if (body is Map && body['ok'] == true) {
      final data = body['data'];
      return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    }
    throw ApiException('INTERNAL', 'Respons server tidak dikenal.');
  }

  static ApiException _fromFunction(FunctionException e) {
    final body = e.details;
    if (body is Map && body['error'] is Map) {
      final err = Map<String, dynamic>.from(body['error'] as Map);
      final details = err['details'];
      return ApiException(
        (err['code'] ?? 'INTERNAL').toString(),
        (err['message'] ?? 'Terjadi kesalahan.').toString(),
        reason: err['reason']?.toString(),
        details: details is Map ? Map<String, dynamic>.from(details) : null,
        status: e.status,
      );
    }
    if (e.status == 401) {
      return ApiException('UNAUTHENTICATED', 'Silakan masuk terlebih dahulu.', status: 401);
    }
    return ApiException('TEMPORARILY_UNAVAILABLE', _networkMessage, status: e.status);
  }

  /// Memanggil fungsi Postgres (RPC) publik/milik sendiri.
  static Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) async {
    final db = client; // di luar try: mode event harus melempar StateError
    try {
      return await db.rpc(fn, params: params).timeout(rpcTimeout);
    } on PostgrestException catch (e) {
      throw fromPostgrest(e);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('TEMPORARILY_UNAVAILABLE', _networkMessage);
    }
  }

  static ApiException fromPostgrest(PostgrestException e) {
    final code = _sqlStates[e.code] ?? 'INTERNAL';
    final message = switch (code) {
      'UNAUTHENTICATED' => 'Silakan masuk terlebih dahulu.',
      'FORBIDDEN' => 'Anda tidak punya akses untuk tindakan ini.',
      'NOT_FOUND' => 'Data tidak ditemukan atau tidak tersedia.',
      'VALIDATION_ERROR' => 'Ada isian yang belum benar.',
      'RATE_LIMITED' => 'Terlalu banyak permintaan. Coba lagi sebentar lagi.',
      _ => 'Terjadi kesalahan di server.',
    };
    return ApiException(code, message, reason: e.message);
  }

  /// URL publik foto katalog dari path storage (bucket `catalog`).
  static String catalogImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    return client.storage.from('catalog').getPublicUrl(path);
  }
}

/// UUID v4 acak untuk operation_id / idempotency key (dibuat sekali per aksi pengguna).
String newOperationId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

/// Tanggal kalender (tanpa jam) sebagai YYYY-MM-DD.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseDate(Object? v) => v == null ? null : DateTime.tryParse(v.toString());
