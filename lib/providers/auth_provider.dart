import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() : _authService = AuthService() {
    _isLoggedIn = _authService.currentUser != null;
    if (_isLoggedIn) refreshUser();
    _sub = _authService.authStateChanges.listen(_onAuthState);
  }

  final AuthService _authService;
  StreamSubscription<AuthState>? _sub;

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  String? _info;
  bool _isLoggedIn = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Pesan non-error, mis. "cek email untuk konfirmasi".
  String? get info => _info;
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _authService.currentUser?.id;

  Future<void> _onAuthState(AuthState state) async {
    final loggedIn = state.session != null;
    if (loggedIn == _isLoggedIn && (_user != null || !loggedIn)) return;
    _isLoggedIn = loggedIn;
    _user = loggedIn ? await _authService.getCurrentAppUser() : null;
    notifyListeners();
  }

  void clearError() {
    if (_error != null || _info != null) {
      _error = null;
      _info = null;
      notifyListeners();
    }
  }

  void _start() {
    _isLoading = true;
    _error = null;
    _info = null;
    notifyListeners();
  }

  void _fail(Object e) {
    _error = AuthService.messageFor(e);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || password.isEmpty) {
      _error = 'Email dan kata sandi wajib diisi.';
      notifyListeners();
      return false;
    }
    _start();
    try {
      await _authService.signIn(cleanEmail, password);
      _user = await _authService.getCurrentAppUser();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  /// true = akun dibuat. Bila konfirmasi email aktif, pengguna belum login dan [info] berisi petunjuk.
  Future<bool> signUp(String email, String password, String name) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanEmail.isEmpty || password.isEmpty) {
      _error = 'Nama, email, dan kata sandi wajib diisi.';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      _error = 'Format email tidak valid.';
      notifyListeners();
      return false;
    }
    if (password.length < 8) {
      _error = 'Kata sandi minimal 8 karakter.';
      notifyListeners();
      return false;
    }
    _start();
    try {
      final res = await _authService.signUp(cleanEmail, password, cleanName);
      if (res.session == null) {
        _info = 'Akun dibuat. Buka tautan konfirmasi di email $cleanEmail, lalu masuk.';
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _user = await _authService.getCurrentAppUser();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<void> signOut() async {
    await PushService.unregister();
    try {
      await _authService.signOut();
    } catch (_) {
      // Sesi lokal tetap dibersihkan walau server tidak terjangkau.
    }
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    _user = await _authService.getCurrentAppUser();
    notifyListeners();
  }

  Future<bool> updateUserProfile({required String name, String? phoneNumber}) async {
    _start();
    try {
      final phone = AuthService.normalizePhone(phoneNumber);
      await _authService.updateUserProfile(name: name, phoneNumber: phone);
      _user = _user?.copyWith(name: name, phoneNumber: phone);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.trim().isEmpty) {
      _error = 'Masukkan alamat email akun Anda.';
      notifyListeners();
      return false;
    }
    _start();
    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _fail(e);
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
