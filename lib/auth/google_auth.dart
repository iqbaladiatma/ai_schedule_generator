// lib/auth/google_auth.dart
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:ai_schedule_generator/config/secret.dart';

final GoogleSignIn googleSignIn = GoogleSignIn(
  clientId: webClientId,
  scopes: [
    'email',
    'https://www.googleapis.com/auth/calendar',
  ],
);

/// Attempts silent sign in first. Returns the account or null.
Future<GoogleSignInAccount?> signInWithGoogle() async {
  try {
    // On web, signIn() is deprecated and unreliable due to COOP/popup issues.
    // Use signInSilently first.
    final silentAccount = await googleSignIn.signInSilently(suppressErrors: true);
    if (silentAccount != null) {
      return silentAccount;
    }

    // If silent sign-in fails, try signIn() as fallback.
    // On web this may still fail due to popup blocking; 
    // the UI should handle this by showing renderButton instead.
    if (!kIsWeb) {
      return await googleSignIn.signIn();
    }

    // On web, return null so the UI can show the Google renderButton
    return null;
  } catch (e) {
    debugPrint("Google Sign-In error: $e");
    return null;
  }
}

Future<void> signOutFromGoogle() async {
  await googleSignIn.signOut();
}