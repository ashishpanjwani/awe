import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wanderwell/models/user.dart' as models;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Lazily initialize GoogleSignIn only on mobile platforms to avoid web assertions
  GoogleSignIn? _googleSignIn;

  models.User? _currentUser;
  models.User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  Future<void> initialize() async {
    // Keep current user in sync, but don't block UI if Firestore is offline
    _auth.authStateChanges().listen((firebase_auth.User? firebaseUser) async {
      if (firebaseUser != null) {
        // Optimistically set from FirebaseAuth profile
        _currentUser = _fromFirebaseUser(firebaseUser);
        // Try to enrich from Firestore (with offline cache fallback)
        await _loadUserData(firebaseUser.uid);
      } else {
        _currentUser = null;
      }
    });

    final firebaseUser = _auth.currentUser;
    if (firebaseUser != null) {
      _currentUser = _fromFirebaseUser(firebaseUser);
      await _loadUserData(firebaseUser.uid);
    }
  }

  Future<void> _loadUserData(String uid) async {
    try {
      // Prefer server if available
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _currentUser = models.User.fromJson({...doc.data()!, 'id': uid});
        return;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        // Fallback to cache when offline
        try {
          final cached = await _firestore
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.cache));
          if (cached.exists) {
            _currentUser = models.User.fromJson({...cached.data()!, 'id': uid});
            return;
          }
        } catch (_) {
          // Ignore cache errors
        }
      }
      // Log other Firestore exceptions
      print('Error loading user data: [$e]');
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  models.User _fromFirebaseUser(firebase_auth.User fUser) {
    final now = DateTime.now();
    return models.User(
      id: fUser.uid,
      name: fUser.displayName ?? 'User',
      email: fUser.email ?? '',
      photoUrl: fUser.photoURL,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<models.User?> signInWithGoogle() async {
    try {
      firebase_auth.UserCredential userCredential;

      if (kIsWeb) {
        // On web, use FirebaseAuth with popup/redirect instead of google_sign_in package
        final provider = firebase_auth.GoogleAuthProvider();
        // Add scopes to align with mobile sign-in
        provider
            .addScope('email')
            .addScope('profile');
        userCredential = await _auth.signInWithPopup(provider);
      } else {
        // Mobile (Android/iOS): use google_sign_in to retrieve tokens
        _googleSignIn ??= GoogleSignIn(scopes: ['email', 'profile']);
        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = firebase_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) return null;

      final now = DateTime.now();
      final userDoc = _firestore.collection('users').doc(firebaseUser.uid);

      // Optimistically set current user from FirebaseAuth profile
      _currentUser = _fromFirebaseUser(firebaseUser);

      // Try to read existing user from server first, fallback to cache if offline
      try {
        final serverDoc = await userDoc.get();
        if (serverDoc.exists) {
          _currentUser = models.User.fromJson({...serverDoc.data()!, 'id': firebaseUser.uid});
        } else {
          // Create the user document (will queue if offline)
          await userDoc.set(_currentUser!.toJson(), SetOptions(merge: true));
        }
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          // Offline: try cache, and queue a write for basic profile
          try {
            final cachedDoc = await userDoc.get(const GetOptions(source: Source.cache));
            if (cachedDoc.exists) {
              _currentUser = models.User.fromJson({...cachedDoc.data()!, 'id': firebaseUser.uid});
            }
          } catch (_) {}
          try {
            await userDoc.set(_currentUser!.toJson(), SetOptions(merge: true));
          } catch (_) {}
        } else {
          rethrow;
        }
      }

      return _currentUser;
    } catch (error) {
      print('Error signing in with Google: $error');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        // Only sign out of GoogleSignIn on mobile
        try {
          _googleSignIn ??= GoogleSignIn();
          await _googleSignIn!.signOut();
        } catch (_) {}
      }
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  /// Permanently deletes the currently signed-in user account.
  /// Attempts to remove the user document in Firestore and then delete the
  /// FirebaseAuth user. If recent login is required, the caller should prompt
  /// the user to reauthenticate and try again.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[AuthService] deleteAccount called with no signed-in user');
      return;
    }
    try {
      // Best-effort: delete Firestore user profile first
      try {
        await _firestore.collection('users').doc(user.uid).delete();
      } catch (e) {
        debugPrint('[AuthService] Failed to delete user doc: $e');
      }

      // Delete the FirebaseAuth user
      await user.delete();
      _currentUser = null;
      debugPrint('[AuthService] Account deleted for uid=${user.uid}');
    } on firebase_auth.FirebaseAuthException catch (e) {
      // Common case: requires-recent-login
      debugPrint('[AuthService] deleteAccount auth error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] deleteAccount unexpected error: $e');
      rethrow;
    }
  }

  String getGreeting() {
    final fullName = _currentUser?.name ?? '';
    final email = _currentUser?.email ?? '';
    final name = _extractFirstName(fullName, email) ?? 'Traveler';
    // Simplified per request: always greet with "Hi" and first name only
    return 'Hi, $name 👋';
  }

  String? _extractFirstName(String? displayName, String? email) {
    final dn = (displayName ?? '').trim();
    if (dn.isNotEmpty) {
      final parts = dn.split(RegExp(r"\s+"));
      if (parts.isNotEmpty) return parts.first;
    }
    final em = (email ?? '').trim();
    if (em.isNotEmpty && em.contains('@')) {
      final local = em.split('@').first;
      if (local.isNotEmpty) return local;
    }
    return null;
  }
}
