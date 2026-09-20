class Review {
  final String id;
  final String userId;
  final String costumeId;
  final String storeId;
  final String rentalId;
  final String text;
  final double costumeRating;
  final double storeRating;
  final String? userPhotoUrl;
  final String userName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.userId,
    required this.costumeId,
    required this.storeId,
    required this.rentalId,
    required this.text,
    required this.costumeRating,
    required this.storeRating,
    this.userPhotoUrl,
    required this.userName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      userId: map['userId'] ?? '',
      costumeId: map['costumeId'] ?? '',
      storeId: map['storeId'] ?? '',
      rentalId: map['rentalId'] ?? '',
      text: map['text'] ?? '',
      costumeRating: (map['costumeRating'] ?? 0).toDouble(),
      storeRating: (map['storeRating'] ?? 0).toDouble(),
      userPhotoUrl: map['userPhotoUrl'],
      userName: map['userName'] ?? 'Anonymous',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'costumeId': costumeId,
      'storeId': storeId,
      'rentalId': rentalId,
      'text': text,
      'costumeRating': costumeRating,
      'storeRating': storeRating,
      'userPhotoUrl': userPhotoUrl,
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
