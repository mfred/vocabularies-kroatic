import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'no-user', message: 'Login fehlgeschlagen.');
    }
    return user;
  }

  Future<User> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-user', message: 'Registrierung fehlgeschlagen.');
    }
    await user.updateDisplayName(displayName.trim());
    // Double-Opt-In: Bestätigungs-Mail direkt nach Anlegen versenden.
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // Nicht blockierend — User kann die Mail auch später erneut anfordern.
    }
    await user.reload();
    return _auth.currentUser ?? user;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Verschickt erneut die Bestätigungs-Mail an den aktuell eingeloggten User.
  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-user', message: 'Nicht eingeloggt.');
    }
    await user.sendEmailVerification();
  }

  /// Lädt den User-State neu und gibt zurück, ob die Email mittlerweile
  /// bestätigt ist. Wird vom Verify-Email-Screen aufgerufen, wenn der User
  /// den Bestätigungs-Link extern geklickt hat.
  Future<bool> reloadAndIsVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();
}

String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'Diese E-Mail-Adresse ist ungültig.';
    case 'user-disabled':
      return 'Dieses Konto wurde deaktiviert.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'E-Mail oder Passwort stimmt nicht.';
    case 'email-already-in-use':
      return 'Mit dieser E-Mail existiert bereits ein Konto.';
    case 'weak-password':
      return 'Das Passwort ist zu schwach (mind. 6 Zeichen).';
    case 'network-request-failed':
      return 'Keine Verbindung zum Server. Bist du online?';
    default:
      return e.message ?? 'Unbekannter Fehler (${e.code}).';
  }
}
