/// Pengguna yang sedang login. Email dari Supabase Auth; nama & nomor dari tabel `profiles`.
/// Peran (owner/staf toko, admin) tidak disimpan di sini: hak akses selalu diperiksa server.
class AppUser {
  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.phoneNumber,
    this.profileImageUrl,
  });

  final String id;
  final String email;
  final String name;

  /// Format internasional (+62…), sesuai kolom `profiles.phone`.
  final String? phoneNumber;

  /// Foto profil belum didukung backend baru (selalu null).
  final String? profileImageUrl;

  AppUser copyWith({String? name, String? phoneNumber}) => AppUser(
        id: id,
        email: email,
        name: name ?? this.name,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        profileImageUrl: profileImageUrl,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return email.isNotEmpty ? email[0].toUpperCase() : '?';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
