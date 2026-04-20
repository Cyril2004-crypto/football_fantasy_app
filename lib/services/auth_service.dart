import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import 'supabase_service.dart';

class AuthService {
  factory AuthService() => _instance;

  AuthService._internal();

  static final AuthService _instance = AuthService._internal();

  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '811534522991-4gub8ofhl2k14bogkgfm5ulri89h9f5r.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    clientId: _googleWebClientId,
  );
  final SupabaseService _supabaseService = SupabaseService();

  // Get current user
  User? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return null;

    return User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastLogin: firebaseUser.metadata.lastSignInTime,
    );
  }

  // Auth state stream
  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        lastLogin: firebaseUser.metadata.lastSignInTime,
      );
    });
  }

  // Sign in with email and password
  Future<User> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _trySyncFirebaseUser(
        firebaseUid: credential.user!.uid,
        email: credential.user!.email ?? email,
        firebaseIdToken: (await credential.user!.getIdToken()) ?? '',
        displayName: credential.user!.displayName,
      );

      final firebaseUser = credential.user!;
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        lastLogin: firebaseUser.metadata.lastSignInTime,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up with email and password
  Future<User> signUpWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(displayName);
      await _trySyncFirebaseUser(
        firebaseUid: credential.user!.uid,
        email: credential.user!.email ?? email,
        firebaseIdToken: (await credential.user!.getIdToken()) ?? '',
        displayName: displayName,
      );

      final firebaseUser = credential.user!;
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        lastLogin: firebaseUser.metadata.lastSignInTime,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Google
  Future<User> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user!;

      await _trySyncFirebaseUser(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        firebaseIdToken: (await firebaseUser.getIdToken()) ?? '',
        displayName: firebaseUser.displayName,
      );

      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
        createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
        lastLogin: firebaseUser.metadata.lastSignInTime,
      );
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get ID token for API calls
  Future<String?> getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  Future<void> _trySyncFirebaseUser({
    required String firebaseUid,
    required String email,
    required String firebaseIdToken,
    String? displayName,
  }) async {
    try {
      await _supabaseService.syncFirebaseUser(
        firebaseUid: firebaseUid,
        email: email,
        firebaseIdToken: firebaseIdToken,
        displayName: displayName,
      );
    } catch (e) {
      // Do not block authentication on profile sync outages.
      // The user is already authenticated with Firebase at this point.
      // ignore: avoid_print
      print('! Supabase profile sync error: $e');
    }
  }

  // Handle auth exceptions
  String _handleAuthException(dynamic e) {
    if (e is firebase_auth.FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Invalid password';
        case 'email-already-in-use':
          return 'Email is already registered';
        case 'weak-password':
          return 'Password is too weak';
        case 'invalid-email':
          return 'Invalid email address';
        case 'user-disabled':
          return 'This account has been disabled';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    return e.toString();
  }
}
