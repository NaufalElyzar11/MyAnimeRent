import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;

  void clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  AuthProvider() {
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        _user = await _authService.getCurrentAppUser();
        _isLoggedIn = true;
      } else {
        _user = null;
        _isLoggedIn = false;
      }
      notifyListeners();
    });
  }

  Future<bool> signIn(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      _error = 'Email and password cannot be empty';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signIn(cleanEmail, cleanPassword);
      _user = await _authService.getCurrentAppUser();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String email, String password, String name) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();
    final cleanName = name.trim();

    if (cleanName.isEmpty || cleanEmail.isEmpty || cleanPassword.isEmpty) {
      _error = 'Name, email, and password cannot be empty';
      notifyListeners();
      return false;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      _error = 'The email address is badly formatted';
      notifyListeners();
      return false;
    }

    if (cleanPassword.length < 6) {
      _error = 'Password should be at least 6 characters';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signUp(cleanEmail, cleanPassword, cleanName);
      _user = await _authService.getCurrentAppUser();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = e.message ?? 'Sign up failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    _user = await _authService.getCurrentAppUser();
    notifyListeners();
  }

  Future<bool> updateProfileImage(String imageUrl) async {
    try {
      await _authService.updateProfileImage(imageUrl);
      if (_user != null) {
        _user = AppUser(
          id: _user!.id,
          email: _user!.email,
          name: _user!.name,
          profileImageUrl: imageUrl,
          phoneNumber: _user!.phoneNumber,
          address: _user!.address,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserProfile({
    required String name,
    String? phoneNumber,
    String? address,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _authService.updateUserProfile(
        name: name,
        phoneNumber: phoneNumber,
        address: address,
      );
      if (_user != null) {
        _user = AppUser(
          id: _user!.id,
          email: _user!.email,
          name: name,
          profileImageUrl: _user!.profileImageUrl,
          phoneNumber: phoneNumber,
          address: address,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
