import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../firebase_options.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: DefaultFirebaseOptions.databaseUrl,
  ).ref();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _db.child('users').child(user.uid).get().timeout(const Duration(seconds: 4));
      if (snapshot.exists && snapshot.value != null) {
        return AppUser.fromMap(
          Map<String, dynamic>.from(snapshot.value as Map),
          user.uid,
        );
      }
    } catch (_) {}
    return AppUser(id: user.uid, email: user.email ?? '', name: user.displayName ?? '');
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUp(String email, String password, String name) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.child('users').child(credential.user!.uid).set({
      'email': email,
      'name': name,
      'profileImageUrl': null,
      'phoneNumber': null,
      'address': null,
    });

    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateProfileImage(String imageUrl) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.child('users').child(user.uid).update({
        'profileImageUrl': imageUrl,
      });
    }
  }

  Future<void> updateUserProfile({
    required String name,
    String? phoneNumber,
    String? address,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.child('users').child(user.uid).update({
        'name': name,
        'phoneNumber': phoneNumber,
        'address': address,
      });
      await user.updateDisplayName(name);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}
