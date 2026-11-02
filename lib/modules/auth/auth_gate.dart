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

    // Total Lockout: If subscription has expired after 30 days, block dashboard completely
    if (seller.isExpired) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      color: Color(0xFFDC2626),
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Membership Expired',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${seller.plan.toUpperCase()} PLAN • EXPIRED',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB91C1C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your 30-day membership for ${seller.email} ended on ${seller.expiresAt.day}/${seller.expiresAt.month}/${seller.expiresAt.year}.\n\nAll packing proofs and video recording features are locked until your subscription is renewed.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4B5563),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => SaasConfig.contactOwnerViaWhatsApp(
                        customMessage:
                            'Hi Danish! My PackProof subscription for ${seller.email} has expired. I want to pay and renew my ${seller.plan.toUpperCase()} membership.',
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                      label: const Text(
                        'Pay & Renew via WhatsApp',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Checking subscription status...'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        await saasAuth.refreshStatus();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Already Paid? Check Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => saasAuth.logout(),
                    child: const Text(
                      'Sign Out / Switch Account',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
