import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/event_safety.dart';
import '../models/store_catalog.dart';
import 'supabase_service.dart';

/// Kelola katalog & profil toko dari app. Semua perubahan lewat Edge Function `catalog` / `stores`
/// (izin staf, kelengkapan listing, pembersihan metadata foto diperiksa server).
class StoreCatalogService {
  StoreCatalogService() {
    EventSafety.requireCloudAccess();
  }

  static const uploadTimeout = Duration(seconds: 60);

  /// Versi teks persetujuan publikasi yang ditampilkan di layar profil toko app.
  static const consentVersion = 'app-2026-11';

  String _img(String path) => Backend.catalogImageUrl(path);

  List<Map<String, dynamic>> _rows(dynamic data) =>
      data is List ? data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : const [];

  // ─── Bacaan ───────────────────────────────────────────────
  Future<List<StoreProductSummary>> listProducts(String storeId) async {
    final data = await Backend.rpc('list_store_products', {'p_store_id': storeId, 'p_status': null});
    return _rows(data).map((m) => StoreProductSummary.fromJson(m, _img)).toList();
  }

  Future<StoreProductDetail> getProduct(String productId) async {
    final data = await Backend.rpc('get_store_product', {'p_product_id': productId});
    if (data is! Map) throw ApiException('NOT_FOUND', 'Listing tidak ditemukan.');
    return StoreProductDetail.fromJson(Map<String, dynamic>.from(data), _img);
  }

  Future<StoreProfile> getStore(String storeId) async {
    final data = await Backend.rpc('get_my_store', {'p_store_id': storeId});
    if (data is! Map) throw ApiException('NOT_FOUND', 'Toko tidak ditemukan.');
    return StoreProfile.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<City>> listCities() async {
    try {
      final rows = await Backend.client
          .from('cities')
          .select('code, name, province')
          .order('name')
          .timeout(Backend.rpcTimeout);
      return rows.map(City.fromJson).toList();
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    } catch (_) {
      throw ApiException('TEMPORARILY_UNAVAILABLE', 'Daftar kota belum bisa dimuat.');
    }
  }

  // ─── Listing ──────────────────────────────────────────────
  /// Buat listing baru ([storeId]) atau ubah ([productId] + [expectedRevision]).
  /// [product] hanya berisi field yang ingin disimpan. Hasil: product_id, revision, status, missing_for_publish.
  Future<Map<String, dynamic>> saveProduct({
    required String operationId,
    String? storeId,
    String? productId,
    int? expectedRevision,
    required Map<String, dynamic> product,
  }) =>
      Backend.call('catalog', 'save_product', {
        'operation_id': operationId,
        if (productId == null) 'store_id': storeId,
        if (productId != null) 'product_id': productId,
        if (productId != null) 'expected_revision': expectedRevision,
        'product': product,
      });

  /// [action]: publish_product | unpublish_product | archive_product | restore_product
  Future<Map<String, dynamic>> setStatus(String action,
          {required String productId, required int expectedRevision, required String operationId}) =>
      Backend.call('catalog', action, {
        'operation_id': operationId,
        'product_id': productId,
        'expected_revision': expectedRevision,
      });

  /// Mengunggah satu foto: server membuat izin unggah ke folder privat, app mengunggah,
  /// lalu server memeriksa isi file, membuang metadata (lokasi GPS, dll.) dan memasangnya.
  Future<Map<String, dynamic>> uploadImage(String productId, Uint8List bytes, String contentType) async {
    final prep = await Backend.call('catalog', 'prepare_image_upload', {
      'product_id': productId,
      'content_type': contentType,
    });
    try {
      await Backend.client.storage
          .from(prep['bucket'].toString())
          .uploadBinaryToSignedUrl(
            prep['path'].toString(),
            prep['token'].toString(),
            bytes,
            FileOptions(contentType: contentType),
          )
          .timeout(uploadTimeout);
    } on StorageException catch (e) {
      throw ApiException('TEMPORARILY_UNAVAILABLE', 'Foto gagal diunggah (${e.message}). Coba lagi.');
    } catch (_) {
      throw ApiException('TEMPORARILY_UNAVAILABLE', 'Foto gagal diunggah. Periksa koneksi lalu coba lagi.');
    }
    return Backend.call('catalog', 'finalize_image_upload', {'intent_id': prep['intent_id']});
  }

  Future<Map<String, dynamic>> removeImage(String imageId,
          {required int expectedRevision, required String operationId}) =>
      Backend.call('catalog', 'remove_image', {
        'operation_id': operationId,
        'image_id': imageId,
        'expected_revision': expectedRevision,
      });

  /// Urutan baru foto; foto pertama menjadi sampul.
  Future<Map<String, dynamic>> reorderImages(String productId, List<String> imageIds,
          {required int expectedRevision, required String operationId}) =>
      Backend.call('catalog', 'reorder_images', {
        'operation_id': operationId,
        'product_id': productId,
        'expected_revision': expectedRevision,
        'image_ids': imageIds,
      });

  // ─── Profil toko (khusus owner) ─────────────────────────────
  Future<Map<String, dynamic>> updateStore(String storeId,
          {required int expectedRevision, required String operationId, required Map<String, dynamic> store}) =>
      Backend.call('stores', 'update_store', {
        'operation_id': operationId,
        'store_id': storeId,
        'expected_revision': expectedRevision,
        'store': store,
      });

  Future<Map<String, dynamic>> publishStore(String storeId,
          {required int expectedRevision, required String operationId}) =>
      Backend.call('stores', 'publish_store', {
        'operation_id': operationId,
        'store_id': storeId,
        'expected_revision': expectedRevision,
        'consent': true,
        'consent_version': consentVersion,
      });

  Future<Map<String, dynamic>> unpublishStore(String storeId,
          {required int expectedRevision, required String operationId}) =>
      Backend.call('stores', 'unpublish_store', {
        'operation_id': operationId,
        'store_id': storeId,
        'expected_revision': expectedRevision,
      });
}

/// Jenis file dari isi (bukan nama): hanya JPEG, PNG, WebP yang diterima server.
String? detectImageType(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length >= 12 &&
      b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && // RIFF
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}
