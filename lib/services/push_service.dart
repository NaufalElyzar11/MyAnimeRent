import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// Push notification lewat Firebase Cloud Messaging. Token perangkat didaftarkan ke Supabase
/// (`register_push_token`); server (Edge Function worker) yang mengirim push.
/// Semua langkah bersifat opsional: bila Firebase tidak tersedia, notifikasi tetap ada di app.
abstract final class PushService {
  static StreamSubscription<String>? _refresh;
  static StreamSubscription<RemoteMessage>? _opened;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) &&
      Firebase.apps.isNotEmpty;

  static String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Dipanggil setelah login.
  static Future<void> register() async {
    if (!_supported) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _send(token);
      _refresh ??= messaging.onTokenRefresh.listen((t) => _send(t));
    } catch (e) {
      debugPrint('Push tidak aktif: $e');
    }
  }

  static Future<void> _send(String token) async {
    try {
      await Backend.rpc('register_push_token', {'p_token': token, 'p_platform': _platform});
    } catch (e) {
      debugPrint('Gagal mendaftarkan token push: $e');
    }
  }

  /// Dipanggil sebelum logout agar perangkat ini tidak menerima push akun tersebut lagi.
  static Future<void> unregister() async {
    if (!_supported) return;
    try {
      await _refresh?.cancel();
      _refresh = null;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await Backend.rpc('unregister_push_token', {'p_token': token});
    } catch (e) {
      debugPrint('Gagal melepas token push: $e');
    }
  }

  /// Membuka layar permintaan saat notifikasi diketuk (app di latar belakang atau tertutup).
  static Future<void> listenTaps(void Function(String requestId) openRequest) async {
    if (!_supported) return;
    void handle(RemoteMessage m) {
      final id = m.data['request_id']?.toString();
      if (id != null && id.isNotEmpty) openRequest(id);
    }

    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) handle(initial);
      _opened ??= FirebaseMessaging.onMessageOpenedApp.listen(handle);
    } catch (e) {
      debugPrint('Push tap tidak aktif: $e');
    }
  }
}
