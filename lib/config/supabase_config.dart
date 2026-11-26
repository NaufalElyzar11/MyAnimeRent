/// Alamat & kunci Supabase diberikan saat build, bukan ditulis di kode:
///
///   flutter run --dart-define-from-file=env/local.json
///
/// Hanya kunci *publishable* yang boleh ada di app. Kunci secret/service_role tidak pernah.
abstract final class SupabaseConfig {
  /// Emulator Android menjangkau komputer lewat 10.0.2.2. Untuk HP fisik pakai IP LAN komputer,
  /// untuk Chrome/Windows pakai http://127.0.0.1:54321.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://10.0.2.2:54321',
  );

  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
