import 'package:flutter/material.dart';

import '../models/rental_request.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/supabase_service.dart';

/// Permintaan sewa milik penyewa. Booking terjadi di server: permintaan → toko mengonfirmasi.
class RentalProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final AuthService _authService = AuthService();

  List<RentalRequest> _requests = [];
  bool _isLoading = false;
  String? _message;

  List<RentalRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get message => _message;

  Future<void> loadRequests() async {
    if (_authService.currentUser == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _requests = await _dbService.listMyRequests();
      _message = null;
    } catch (e) {
      _message = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<RentalRequest?> getRequest(String id) => _dbService.getMyRequest(id);

  /// Mengirim permintaan. [idempotencyKey] harus sama untuk percobaan ulang tombol yang sama.
  Future<({String requestId, String requestCode})> createRequest({
    required String idempotencyKey,
    required String productId,
    String? variantId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
    required bool contactConsent,
  }) async {
    if (_authService.currentUser == null) {
      throw ApiException('UNAUTHENTICATED', 'Silakan masuk terlebih dahulu.');
    }
    final created = await _dbService.createRequest(
      idempotencyKey: idempotencyKey,
      productId: productId,
      variantId: variantId,
      rentStart: startDate,
      rentEndExclusive: DateTime(endDate.year, endDate.month, endDate.day + 1),
      note: note,
      contactConsent: contactConsent,
    );
    loadRequests();
    return created;
  }

  Future<void> cancel(RentalRequest request, {required String operationId, String? reason}) async {
    await _dbService.cancelMyRequest(request, operationId: operationId, reason: reason);
    await loadRequests();
  }

  void clear() {
    _requests = [];
    _message = null;
    notifyListeners();
  }
}
