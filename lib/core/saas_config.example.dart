import 'package:url_launcher/url_launcher.dart';

class SaasConfig {
  /// Supabase Project URL (e.g. https://your-project.supabase.co)
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';

  /// Supabase Publishable / Anon Public Key
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  /// Owner: Your WhatsApp contact number (e.g. 03001234567)
  static const String ownerWhatsApp = '03001234567';

  /// Owner: Your contact name
  static const String ownerContactName = 'PackProof Admin';

  /// Checks if Supabase has been configured with real credentials
  static bool get isConfigured =>
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;

  /// Helper to open WhatsApp directly with a pre-filled message
  static Future<void> contactOwnerViaWhatsApp({String? customMessage}) async {
    final message = customMessage ??
        'Hello, I would like to purchase / renew my PackProof membership.';

    var cleanPhone = ownerWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '92${cleanPhone.substring(1)}';
    }

    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
