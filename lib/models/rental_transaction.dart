enum RentalStatus { pending, active, completed, cancelled }

class RentalTransaction {
  final String id;
  final String userId;
  final String costumeId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final RentalStatus status;
  final String? size;
  final DateTime createdAt;

  RentalTransaction({
    required this.id,
    required this.userId,
    required this.costumeId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    this.size,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory RentalTransaction.fromMap(Map<String, dynamic> map, String id) {
    return RentalTransaction(
      id: id,
      userId: map['userId'] ?? '',
      costumeId: map['costumeId'] ?? '',
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(map['endDate'] ?? DateTime.now().toIso8601String()),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      status: RentalStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => RentalStatus.pending,
      ),
      size: map['size'] as String?,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'costumeId': costumeId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'totalPrice': totalPrice,
      'status': status.name,
      if (size != null) 'size': size,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
