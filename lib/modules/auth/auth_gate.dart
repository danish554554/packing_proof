import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/saas_config.dart';
import '../../services/saas_auth_service.dart';
import '../../ui/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final saasAuth = context.watch<SaasAuthService>();

    if (!saasAuth.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FA),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFFF5A1F),
          ),
        ),
      );
    }

    if (!saasAuth.isAuthenticated) {
      return const LoginScreen();
    }

    final seller = saasAuth.currentSeller;
    if (seller == null || !seller.isActive) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.block_outlined,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Account Deactivated',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your seller license has been deactivated or removed by the administrator. Please contact the owner to reactivate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => SaasConfig.contactOwnerViaWhatsApp(
                    customMessage:
                        'Hi, my account (${seller?.email}) was deactivated. Please help reactivate my membership.',
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Contact Admin on WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => saasAuth.logout(),
                  child: const Text('Switch Account'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
