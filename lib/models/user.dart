class AppUser {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? profileImageUrl;
  final String? phoneNumber;
  final String? address;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'user',
    this.profileImageUrl,
    this.phoneNumber,
    this.address,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: (map['role'] ?? 'user').toString(),
      profileImageUrl: map['profileImageUrl'],
      phoneNumber: map['phoneNumber'],
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'phoneNumber': phoneNumber,
      'address': address,
    };
  }
}
