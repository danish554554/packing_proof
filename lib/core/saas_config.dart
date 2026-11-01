import 'package:url_launcher/url_launcher.dart';

class SaasConfig {
  /// Supabase Project URL
  static const String supabaseUrl = 'https://fhcssagybeqccydpqzmc.supabase.co';

  /// Supabase Publishable / Anon Public Key
  static const String supabaseAnonKey =
      'sb_publishable_OqZn-8zmQ4b4rDj7ARr0FQ_5mTCYEXJ';

  /// Owner: Your WhatsApp contact number
  static const String ownerWhatsApp = '03125572205';

  /// Owner: Your contact name
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
