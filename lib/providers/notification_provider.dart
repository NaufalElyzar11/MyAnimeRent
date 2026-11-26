import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../models/app_notification.dart';
import '../services/database_service.dart';

/// Kotak masuk notifikasi + pembaruan langsung (Realtime) selama app terbuka.
class NotificationProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<AppNotification> _items = [];
  RealtimeChannel? _channel;
  String? _userId;
  bool _isLoading = false;

  List<AppNotification> get items => _items;
  bool get isLoading => _isLoading;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  /// Callback opsional untuk notifikasi baru (mis. menyegarkan daftar permintaan).
  void Function(AppNotification)? onNew;

  Future<void> start(String userId) async {
    if (_userId == userId) return;
    await stop();
    _userId = userId;
    _channel = _dbService.subscribeNotifications(userId, (n) {
      if (_items.any((x) => x.id == n.id)) return;
      _items = [n, ..._items];
      notifyListeners();
      onNew?.call(n);
    });
    await load();
  }

  Future<void> load() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _dbService.getNotifications();
    } catch (_) {
      // Daftar lama tetap ditampilkan.
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    _items = [for (final x in _items) x.id == n.id ? x.markedRead() : x];
    notifyListeners();
    try {
      await _dbService.markNotificationsRead([n.id]);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final ids = _items.where((n) => !n.isRead).map((n) => n.id).toList();
    if (ids.isEmpty) return;
    _items = [for (final x in _items) x.markedRead()];
    notifyListeners();
    try {
      await _dbService.markNotificationsRead(ids);
    } catch (_) {}
  }

  Future<void> stop() async {
    final channel = _channel;
    _channel = null;
    _userId = null;
    _items = [];
    if (channel != null) await _dbService.unsubscribe(channel);
    notifyListeners();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) _dbService.unsubscribe(channel);
    super.dispose();
  }
}
