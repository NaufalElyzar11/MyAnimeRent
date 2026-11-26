import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/event_safety.dart';
import '../models/user.dart';
import 'supabase_service.dart';

/// Akun lewat Supabase Auth (sama dengan website). Profil di tabel `profiles` (RLS: milik sendiri).
class AuthService {
  AuthService() {
    EventSafety.requireCloudAccess();
  }

  GoTrueClient get _auth => Backend.client.auth;

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  Future<AppUser?> getCurrentAppUser() async {
    final user = currentUser;
    if (user == null) return null;
    var name = (user.userMetadata?['display_name'] ?? '').toString();
    String? phone;
    try {
      final row = await Backend.client
          .from('profiles')
          .select('display_name, phone')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 6));
      if (row != null) {
        name = (row['display_name'] ?? name).toString();
        phone = row['phone']?.toString();
      }
    } catch (_) {
      // Profil tetap bisa ditampilkan dari data akun bila jaringan lambat.
    }
    return AppUser(id: user.id, email: user.email ?? '', name: name, phoneNumber: phone);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    EventSafety.requireCloudAccess();
    return _auth.signInWithPassword(email: email, password: password);
  }

  /// Bila konfirmasi email aktif, [AuthResponse.session] bernilai null sampai email dikonfirmasi.
  Future<AuthResponse> signUp(String email, String password, String name) async {
    EventSafety.requireCloudAccess();
    return _auth.signUp(email: email, password: password, data: {'display_name': name});
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateUserProfile({required String name, String? phoneNumber}) async {
    EventSafety.requireCloudAccess();
    final user = currentUser;
    if (user == null) throw ApiException('UNAUTHENTICATED', 'Silakan masuk terlebih dahulu.');
    try {
      await Backend.client
          .from('profiles')
          .update({'display_name': name, 'phone': normalizePhone(phoneNumber)})
          .eq('user_id', user.id);
    } on PostgrestException catch (e) {
      throw Backend.fromPostgrest(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    EventSafety.requireCloudAccess();
    await _auth.resetPasswordForEmail(email.trim());
  }

  /// 0812… / 62812… / +62 812-… → +62812…; null bila kosong. Melempar bila formatnya salah.
  static String? normalizePhone(String? input) {
    final raw = (input ?? '').replaceAll(RegExp(r'[\s\-().]'), '');
    if (raw.isEmpty) return null;
    String e164;
    if (raw.startsWith('+')) {
      e164 = raw;
    } else if (raw.startsWith('62')) {
      e164 = '+$raw';
    } else if (raw.startsWith('0')) {
      e164 = '+62${raw.substring(1)}';
    } else {
      e164 = '+62$raw';
    }
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(e164)) {
      throw ApiException('VALIDATION_ERROR', 'Nomor HP tidak valid. Contoh: 0812 3456 7890');
    }
    return e164;
  }

  /// Pesan ramah untuk error Supabase Auth.
  static String messageFor(Object error) {
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Email atau kata sandi salah.';
        case 'email_not_confirmed':
          return 'Email belum dikonfirmasi. Buka tautan di email pendaftaran.';
        case 'user_already_exists':
        case 'email_exists':
          return 'Email ini sudah terdaftar. Silakan masuk.';
        case 'weak_password':
          return 'Kata sandi terlalu lemah. Gunakan minimal 8 karakter.';
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
          return 'Terlalu banyak percobaan. Coba lagi beberapa menit lagi.';
      }
      return error.message;
    }
    if (error is ApiException) return error.message;
    return 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.';
  }
}
