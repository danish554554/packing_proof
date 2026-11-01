import 'package:url_launcher/url_launcher.dart';

class SaasConfig {
  /// Owner: Replace these with your Supabase Project URL and Anon Public Key
  /// Found in: Supabase Dashboard -> Project Settings -> API
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Owner: Your WhatsApp number with country code (e.g. 923001234567)
  /// When a seller's 30-day membership expires or they hit their quota,
  /// tapping "Renew / Upgrade" will open a WhatsApp chat directly with you.
  static const String ownerWhatsApp = '923001234567';

  /// Owner: Your email / contact name
  static const String ownerContactName = 'Danish (PackProof Admin)';

  /// Checks if Supabase has been configured with real credentials
  static bool get isConfigured =>
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;

  /// Helper to open WhatsApp directly with a pre-filled message
  static Future<void> contactOwnerViaWhatsApp({String? customMessage}) async {
    final message = customMessage ??
        'Hello Danish, I would like to purchase / renew my PackProof membership.';
    final cleanPhone = ownerWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
