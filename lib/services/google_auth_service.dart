import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GoogleAuthService extends ChangeNotifier {
  static const List<String> scopes = <String>[
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ];

  static const String _driveOwnerKey = 'packproof_google_drive_owner_seller_id';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: scopes,
    serverClientId:
        '442402513623-v865sd82vvq8mvv3lthai273mi868cjo.apps.googleusercontent.com',
  );

  GoogleSignInAccount? _currentUser;
  Future<GoogleSignInAccount?>? _silentSignInFuture;
  String? _currentSellerId;

  GoogleSignInAccount? get currentUser => _currentUser;

  /// Sync Google Drive connection with the active SaaS seller
  Future<void> syncWithSeller(String? sellerId) async {
    _currentSellerId = sellerId;

    if (sellerId == null || sellerId.isEmpty) {
      if (_currentUser != null || await _googleSignIn.isSignedIn()) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      _currentUser = null;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final connectedSellerId = prefs.getString(_driveOwnerKey);

    // If Google Drive on device was connected by another seller (or none), disconnect!
    if (connectedSellerId == null || connectedSellerId != sellerId) {
      if (_currentUser != null || await _googleSignIn.isSignedIn()) {
        try {
          await _googleSignIn.signOut();
        } catch (_) {}
      }
      _currentUser = null;
      notifyListeners();
      return;
    }

    // This seller previously connected their Drive on this device; restore silently
    await signInSilently();
  }

  Future<GoogleSignInAccount?> signIn({String? sellerId}) async {
    final activeSellerId = sellerId ?? _currentSellerId;
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      _currentUser = account;

      if (account != null && activeSellerId != null && activeSellerId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_driveOwnerKey, activeSellerId);
      }

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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_driveOwnerKey);
    } catch (_) {}

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    _currentUser = null;
    notifyListeners();
  }

  Future<bool> isSignedIn() async {
    if (_currentSellerId != null) {
      final prefs = await SharedPreferences.getInstance();
      final connectedSellerId = prefs.getString(_driveOwnerKey);
      if (connectedSellerId != _currentSellerId) {
        return false;
      }
    }
    return _currentUser != null;
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
