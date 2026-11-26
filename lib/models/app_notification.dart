import '../services/supabase_service.dart' show parseDate;

/// Notifikasi dalam aplikasi (tabel `notifications`).
class AppNotification {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.data = const {},
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;
  String? get requestId => data['request_id']?.toString();

  AppNotification markedRead() => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        data: data,
        readAt: readAt ?? DateTime.now(),
        createdAt: createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> m) => AppNotification(
        id: m['id'].toString(),
        kind: (m['kind'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        body: m['body']?.toString(),
        data: m['data'] is Map ? Map<String, dynamic>.from(m['data'] as Map) : const {},
        readAt: parseDate(m['read_at']),
        createdAt: parseDate(m['created_at']) ?? DateTime.now(),
      );
}
