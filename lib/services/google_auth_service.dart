import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService extends ChangeNotifier {
  static const List<String> scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: scopes,
    serverClientId:
        '442402513623-v865sd82vvq8mvv3lthai273mi868cjo.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  Future<GoogleSignInAccount?>? _silentSignInFuture;

  GoogleSignInAccount? get currentUser =>
      _currentUser ?? _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      _currentUser = account;
      notifyListeners();
      return account;
    } catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    if (_silentSignInFuture != null) {
      return _silentSignInFuture;
    }

    _silentSignInFuture = _performSignInSilently();
    try {
      final account = await _silentSignInFuture;
      return account;
    } finally {
      _silentSignInFuture = null;
    }
  }

  Future<GoogleSignInAccount?> _performSignInSilently() async {
    try {
      final GoogleSignInAccount? account =
          await _googleSignIn.signInSilently();
      if (_currentUser?.id != account?.id) {
        _currentUser = account;
        notifyListeners();
      } else {
        _currentUser = account;
      }
      return account;
    } catch (e) {
      // Silent sign-in may return null or error if user has never signed in
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> isSignedIn() async {
    final bool signedIn = await _googleSignIn.isSignedIn();

    if (signedIn && _currentUser == null) {
      _currentUser =
          _googleSignIn.currentUser ?? await signInSilently();
      notifyListeners();
    }

    return signedIn;
  }

  Future<String?> getAccessToken() async {
    GoogleSignInAccount? user = currentUser;

    user ??= await signInSilently();

    if (user == null) {
      return null;
    }

    try {
      final GoogleSignInAuthentication auth = await user.authentication;
      return auth.accessToken;
    } catch (_) {
      // Token might be expired; try to refresh once silently
      user = await signInSilently();
      if (user != null) {
        final GoogleSignInAuthentication auth = await user.authentication;
        return auth.accessToken;
      }
      return null;
    }
  }

  String _friendlyAuthError(Object error) {
    final raw = error.toString();

    if (raw.contains('ApiException: 10')) {
      return 'Google Sign-In configuration error (ApiException 10). '
          'Please verify Firebase package name, SHA-1, SHA-256, '
          'Google Sign-In provider, and regenerate google-services.json.';
    }

    if (raw.toLowerCase().contains('network')) {
      return 'Network error while connecting to Google. Please check internet.';
    }

    if (raw.toLowerCase().contains('canceled') ||
        raw.toLowerCase().contains('cancelled')) {
      return 'Google sign-in was cancelled.';
    }

    return raw;
  }
}
