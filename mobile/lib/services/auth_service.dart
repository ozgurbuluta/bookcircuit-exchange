import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../config/env.dart';

/// Authentication (spec §5): Apple, Google, email link. No password flow.
///
/// Console prerequisites are listed in docs/SETUP_AUTH.md — until the
/// providers are enabled there, these calls surface provider errors that the
/// UI shows as a friendly message.
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static const String _pendingEmailKey = 'pending_email_link_email';

  // ---- Apple ----

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Sign in with Apple. Returns the Firebase credential; on first sign-in
  /// Apple also supplies the user's name, which we pass along for bootstrap.
  static Future<({UserCredential credential, String? displayName})>
      signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final credential = await _auth.signInWithCredential(oauthCredential);

    // Apple sends the name only on the very first authorization.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    final displayName = [givenName, familyName]
        .where((p) => p != null && p.isNotEmpty)
        .join(' ');

    return (
      credential: credential,
      displayName: displayName.isEmpty ? null : displayName,
    );
  }

  // ---- Google ----

  static Future<UserCredential> signInWithGoogle() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize();
    final account = await signIn.authenticate();
    final googleAuth = account.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  // ---- Email link (passwordless — decision D2) ----

  /// Sends the sign-in link and remembers the email locally so the flow can
  /// complete when the link opens the app.
  static Future<void> sendSignInLink(String email) async {
    final actionCodeSettings = ActionCodeSettings(
      url: '${Env.webUrl}/finishSignIn',
      handleCodeInApp: true,
      iOSBundleId: 'com.turtleturningpages.turtleTurningPages',
    );

    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingEmailKey, email);
  }

  /// Whether [link] is a Firebase email sign-in link.
  static bool isSignInLink(String link) => _auth.isSignInWithEmailLink(link);

  /// The email waiting for link completion, if any.
  static Future<String?> pendingEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingEmailKey);
  }

  /// Completes the email-link sign-in for the locally stored email.
  /// Returns null when no email is pending (e.g. link opened on another
  /// device) — the UI should re-ask for the email in that case.
  static Future<UserCredential?> completeSignInWithLink(String link) async {
    final email = await pendingEmail();
    if (email == null) return null;

    final credential =
        await _auth.signInWithEmailLink(email: email, emailLink: link);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingEmailKey);
    return credential;
  }

  // ---- Session ----

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
