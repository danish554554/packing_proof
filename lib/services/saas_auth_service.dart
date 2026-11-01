import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/saas_config.dart';
import '../models/seller_profile.dart';

class SaasAuthService extends ChangeNotifier {
  static const String _cacheKey = 'packproof_cached_seller_profile';

  SellerProfile? _currentSeller;
  bool _isLoading = false;
  String? _authError;
  bool _isInitialized = false;

  SellerProfile? get currentSeller => _currentSeller;
  bool get isLoading => _isLoading;
  String? get authError => _authError;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentSeller != null;

  /// Initialize service on app launch
  Future<void> init() async {
    if (_isInitialized) return;

    // Load locally cached profile first for fast startup
    final prefs = await SharedPreferences.getInstance();
    final cachedRaw = prefs.getString(_cacheKey);
    if (cachedRaw != null) {
      try {
        final decoded = jsonDecode(cachedRaw) as Map<String, dynamic>;
        _currentSeller = SellerProfile.fromJson(decoded);
        notifyListeners();
      } catch (_) {
        await prefs.remove(_cacheKey);
      }
    }

    if (SaasConfig.isConfigured) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await refreshStatus();
      } else {
        // If no active session, clear profile
        _currentSeller = null;
        await prefs.remove(_cacheKey);
        notifyListeners();
      }
    } else {
      // In demo / unconfigured mode: provide an initial active demo profile
      // so testing remains seamless until owner plugs in real Supabase keys
      if (_currentSeller == null) {
        _currentSeller = SellerProfile(
          id: 'demo-seller-id',
          email: 'demo@packproof.com',
          sellerName: 'Demo Daraz Seller',
          storeName: 'Daraz Flagship Store',
          phone: '03001234567',
          plan: 'gold',
          isActive: true,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          monthlyQuota: 200,
          videosThisMonth: 12,
        );
        notifyListeners();
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Sign in seller with Email & Password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    try {
      if (!SaasConfig.isConfigured) {
        // Demo mode login
        if (password.length < 4) {
          throw Exception('Password must be at least 4 characters');
        }
        _currentSeller = SellerProfile(
          id: 'demo-seller-id',
          email: email.trim(),
          sellerName: email.split('@').first,
          storeName: 'Daraz Store',
          phone: '',
          plan: 'silver',
          isActive: true,
          expiresAt: DateTime.now().add(const Duration(days: 30)),
          monthlyQuota: 100,
          videosThisMonth: 0,
        );
        await _saveToCache(_currentSeller!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw Exception('User authentication failed.');
      }

      // Fetch seller profile from `sellers` table
      final data = await Supabase.instance.client
          .from('sellers')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        // User was deleted or has no profile
        await Supabase.instance.client.auth.signOut();
        throw Exception(
          'Your seller account was not found. Please contact the Admin to register.',
        );
      }

      final profile = SellerProfile.fromJson(data);
      if (!profile.isActive) {
        await Supabase.instance.client.auth.signOut();
        throw Exception(
          'Your account has been deactivated. Please contact the Admin on WhatsApp to reactivate.',
        );
      }

      _currentSeller = profile;
      await _saveToCache(profile);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _authError = _friendlyErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Refresh latest subscription status & quota from Supabase
  Future<void> refreshStatus() async {
    if (!SaasConfig.isConfigured || _currentSeller == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        await logout();
        return;
      }

      final data = await Supabase.instance.client
          .from('sellers')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) {
        // Owner deleted the user from Supabase!
        await logout();
        return;
      }

      final updated = SellerProfile.fromJson(data);
      _currentSeller = updated;
      await _saveToCache(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh seller status: $e');
    }
  }

  /// Securely increments video usage when a recording is completed
  Future<bool> recordVideoUsage({
    required String trackingNumber,
    required String orderType,
  }) async {
    if (_currentSeller == null) return false;

    // Local increment for immediate responsive UI feedback
    final newCount = _currentSeller!.videosThisMonth + 1;
    _currentSeller = _currentSeller!.copyWith(videosThisMonth: newCount);
    await _saveToCache(_currentSeller!);
    notifyListeners();

    if (!SaasConfig.isConfigured) {
      return true;
    }

    try {
      // Call secure RPC function on Supabase
      final res = await Supabase.instance.client.rpc(
        'record_order_proof',
        params: {
          'p_tracking_number': trackingNumber,
          'p_order_type': orderType,
        },
      );

      if (res != null && res['success'] == true) {
        final serverCount = res['videos_recorded_this_month'] as int?;
        if (serverCount != null) {
          _currentSeller =
              _currentSeller!.copyWith(videosThisMonth: serverCount);
          await _saveToCache(_currentSeller!);
          notifyListeners();
        }
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('Failed to report usage to cloud: $e');
      return true; // Still allow local recording to not block seller packing flow
    }
  }

  /// Sign out
  Future<void> logout() async {
    try {
      if (SaasConfig.isConfigured) {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (_) {}

    _currentSeller = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    notifyListeners();
  }

  Future<void> _saveToCache(SellerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(profile.toJson()));
  }

  String _friendlyErrorMessage(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_grant')) {
      return 'Invalid email or password. Please verify and try again.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'Network connection error. Please check your internet.';
    }
    if (e is AuthException) {
      return e.message;
    }
    return e.toString().replaceAll('Exception: ', '');
  }
}
