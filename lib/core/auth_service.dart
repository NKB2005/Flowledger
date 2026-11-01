import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'bank_sms_service.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static bool _googleSignInInitialized = false;

  static Future<void> initializeGoogleSignIn() async {
    if (_googleSignInInitialized || kIsWeb) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '416120557559-pk4bnir3kq2fous9tbid87ep1ofnls5r.apps.googleusercontent.com',
      );
      _googleSignInInitialized = true;
    } catch (_) {}
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(googleProvider);
    }

    await initializeGoogleSignIn();
    try {
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw FirebaseAuthException(
          code: 'null-id-token',
          message:
              'Google did not return an ID token. Please verify that your SHA-1 fingerprint is added in the Firebase Console.',
        );
      }
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'google-canceled',
          message:
              'Google Sign-In was cancelled. If the popup closed immediately, please add your SHA-1 fingerprint to the Firebase Console.',
        );
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    BankSmsService.stopListening();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  String errorMessage(Object error) {
    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          return 'Sign-in cancelled.';
        case GoogleSignInExceptionCode.clientConfigurationError:
          return 'Google Sign-In configuration error. Please ensure the SHA-1 fingerprint is added in Firebase Console.';
        default:
          return error.description ?? 'Google Sign-In failed. Please try again.';
      }
    }
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          return 'Invalid email or password. If you do not have an account yet, switch to "Create account" to register.';
        case 'email-already-in-use':
          return 'An account already exists for this email. Switch to "Sign in" to log in.';
        case 'weak-password':
          return 'Choose a stronger password with at least 6 characters.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'network-request-failed':
          return 'Check your internet connection and try again.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email using another sign-in provider.';
        case 'popup-closed-by-user':
          return 'Sign-in popup was closed.';
        case 'google-canceled':
          return 'Google Sign-In cancelled. Please ensure your SHA-1 fingerprint is registered in Firebase Console.';
        default:
          return error.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Authentication error: $error';
  }
}

String displayNameForUser(User? user) {
  final displayName = user?.displayName?.trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;

  final emailName = user?.email?.split('@').first.trim();
  if (emailName != null && emailName.isNotEmpty) return emailName;
  return 'Alex';
}

String initialsForUser(User? user) {
  final name = displayNameForUser(user).trim();
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.length > 1) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  final compactName = parts.first;
  return compactName.substring(0, compactName.length > 1 ? 2 : 1).toUpperCase();
}
