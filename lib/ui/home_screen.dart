import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/recording_controller.dart';
import '../core/saas_config.dart';
import '../models/seller_profile.dart';
import '../modules/history/history_screen.dart';
import '../modules/queue/upload_queue_screen.dart';
import '../modules/recording/recording_screen.dart';
import '../modules/scanner/scanner_screen.dart';
import '../modules/settings/settings_screen.dart';
import '../services/saas_auth_service.dart';
import '../services/upload_queue_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Color _primary = Color(0xFFFF5A1F);
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Whenever app is resumed from background or reopened, resume any pending uploads and refresh license!
      if (mounted) {
        context.read<UploadQueueService>().resumeQueue();
        context.read<SaasAuthService>().refreshStatus();
      }
    }
  }

  void _showLicenseDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required String whatsappMsg,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock_clock_outlined, color: _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: _textDark, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogCtx);
              SaasConfig.contactOwnerViaWhatsApp(customMessage: whatsappMsg);
            },
            icon: const Icon(Icons.chat, size: 18),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startFlow(
    BuildContext context, {
    required RecordingFlowType flowType,
  }) async {
    final saasAuth = context.read<SaasAuthService>();
    final seller = saasAuth.currentSeller;

    if (seller != null) {
      if (!seller.isActive) {
        _showLicenseDialog(
          context,
          title: 'Account Deactivated',
          message:
              'Your seller account has been deactivated by the administrator. Please contact the owner to reactivate.',
          buttonText: 'Contact on WhatsApp',
          whatsappMsg:
              'Hi Danish! My account (${seller.email}) is marked as deactivated. Please reactivate my membership.',
        );
        return;
      }

      if (seller.isExpired) {
        _showLicenseDialog(
          context,
          title: '30-Day Membership Expired',
          message:
              'Your monthly subscription ended on ${seller.expiresAt.day}/${seller.expiresAt.month}/${seller.expiresAt.year}. Please pay your renewal fee to continue recording packing proofs.',
          buttonText: 'Pay & Renew on WhatsApp',
          whatsappMsg:
              'Hi Danish! My 30-day membership for ${seller.email} has expired. I want to pay the monthly fee to renew.',
        );
        return;
      }

      if (seller.isQuotaReached) {
        _showLicenseDialog(
          context,
          title: 'Monthly Order Limit Reached',
          message:
              'You have recorded all ${seller.monthlyQuota} orders allowed in your ${seller.planDisplayName} plan this month. Please upgrade your plan to record more.',
          buttonText: 'Upgrade on WhatsApp',
          whatsappMsg:
              'Hi Danish! I reached my monthly limit (${seller.videosThisMonth}/${seller.monthlyQuota} orders) on ${seller.email}. I want to upgrade my plan.',
        );
        return;
      }
    }

    final isReturn = flowType == RecordingFlowType.returnRecording;
    final scannedOrderId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          appBarTitle: isReturn ? 'Scan Return Tracking ID' : 'Scan Packing Order',
          statusHint: isReturn
              ? 'Point camera at the return tracking label'
              : 'Point camera at Daraz barcode or QR label',
          tipText: isReturn
              ? 'Scan the exact tracking ID used in the original packing record so the return video is saved in the same folder.'
              : 'Tip: for best result, scan the label area that shows the exact order number or full tracking ID.',
        ),
      ),
    );

    if (!context.mounted ||
        scannedOrderId == null ||
        scannedOrderId.trim().isEmpty) {
      return;
    }

    context.read<RecordingController>().setOrder(
          scannedOrderId,
          flowType: flowType,
        );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordingScreen(),
      ),
    );
  }

  void _openQueue(BuildContext context, {QueueFilter filter = QueueFilter.all}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadQueueScreen(initialFilter: filter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saasAuth = context.watch<SaasAuthService>();
    final uploadQueue = context.watch<UploadQueueService>();

    final today = uploadQueue.todayCompletedCount;
    final uploading = uploadQueue.uploadingCount;
    final pending = uploadQueue.pendingCount;
    final failed = uploadQueue.failedCount;
    final recentUploads = uploadQueue.recentCompletedItems.take(5).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'PACKPROOF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ready to Pack',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              _SaaSMembershipBanner(seller: saasAuth.currentSeller),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.today_outlined,
                      value: today,
                      label: 'Today',
                      onTap: () => _openQueue(context, filter: QueueFilter.done),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.cloud_upload_outlined,
                      value: uploading,
                      label: 'Uploading',
                      highlightColor: uploading > 0 ? _primary : null,
                      onTap: () => _openQueue(context, filter: QueueFilter.active),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule_outlined,
                      value: pending,
                      label: 'Pending',
                      highlightColor: pending > 0 ? const Color(0xFFF59E0B) : null,
                      onTap: () => _openQueue(context, filter: QueueFilter.pending),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.error_outline,
                      value: failed,
                      label: 'Failed',
                      highlightColor: failed > 0 ? const Color(0xFFDC2626) : null,
                      onTap: () => _openQueue(context, filter: QueueFilter.failed),
                    ),
                  ),
                ],
              ),
              if (uploading > 0 || pending > 0) ...[
                const SizedBox(height: 10),
                _ActiveUploadBanner(
                  uploadingCount: uploading,
                  pendingCount: pending,
                  onTap: () => _openQueue(context, filter: QueueFilter.all),
                ),
              ],
              const SizedBox(height: 14),
              const Text(
                'RECENT UPLOADS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                  ),
                  child: recentUploads.isEmpty
                      ? const _EmptyUploadsState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: recentUploads.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = recentUploads[index];
                            return _RecentUploadTile(item: item);
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startFlow(
                        context,
                        flowType: RecordingFlowType.packing,
                      ),
                      icon: const Icon(Icons.inventory_2_outlined, size: 20),
                      label: const Text(
                        'Record Packing',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _startFlow(
                        context,
                        flowType: RecordingFlowType.returnRecording,
                      ),
                      icon: const Icon(Icons.assignment_return_outlined, size: 20),
                      label: const Text(
                        'Record Return',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UploadQueueScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HistoryScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
          }
        },
      ),
    );
  }
}

class _ActiveUploadBanner extends StatelessWidget {
  final int uploadingCount;
  final int pendingCount;
  final VoidCallback onTap;

  const _ActiveUploadBanner({
    required this.uploadingCount,
    required this.pendingCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = uploadingCount > 0
        ? 'Uploading $uploadingCount video${uploadingCount == 1 ? '' : 's'} to Drive...'
        : 'Queued for upload ($pendingCount)';
    const subtitle = 'Videos auto-upload & resume safely if interrupted';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEFE8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFD4C2)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFFFF5A1F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFFF5A1F),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFFFF5A1F),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color? highlightColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.highlightColor,
    this.onTap,
  });

  static const Color _primary = Color(0xFFFF5A1F);
  static const Color _card = Colors.white;
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final iconColor = highlightColor ?? _primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlightColor != null
                ? highlightColor!.withValues(alpha: 0.4)
                : _border,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: highlightColor ?? _textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: _textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentUploadTile extends StatelessWidget {
  const _RecentUploadTile({required this.item});

  final UploadQueueItem item;

  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _success = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_circle_outline, color: _success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.orderId,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.flowLabel} • Uploaded to Drive',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUploadsState extends StatelessWidget {
  const _EmptyUploadsState();

  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 22,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'No uploads yet today',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Recorded videos will appear here after upload.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: _border),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.inventory_2_outlined,
                label: 'Pack',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.cloud_upload_outlined,
                label: 'Queue',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.history_outlined,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _primary = Color(0xFFFF5A1F);
  static const Color _textMuted = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? _primary : _textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _primary : _textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaaSMembershipBanner extends StatelessWidget {
  final SellerProfile? seller;

  const _SaaSMembershipBanner({this.seller});

  static const Color _border = Color(0xFFE5E7EB);
  static const Color _textDark = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    if (seller == null) return const SizedBox.shrink();

    final isExpired = seller!.isExpired;
    final isQuotaReached = seller!.isQuotaReached;
    final hasWarning = isExpired || isQuotaReached;
    final days = seller!.daysRemaining;

    final badgeBg = hasWarning
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFEFF6FF);
    final badgeText = hasWarning
        ? const Color(0xFFDC2626)
        : const Color(0xFF2563EB);

    final statusText = isExpired
        ? 'Membership Expired'
        : isQuotaReached
            ? 'Monthly Quota Full'
            : '$days days left';

    final usageText = seller!.isUnlimited
        ? '${seller!.videosThisMonth} orders'
        : '${seller!.videosThisMonth}/${seller!.monthlyQuota} orders';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasWarning ? const Color(0xFFFECACA) : _border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              seller!.plan.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: badgeText,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$statusText • $usageText',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasWarning ? const Color(0xFFDC2626) : _textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasWarning)
            InkWell(
              onTap: () => SaasConfig.contactOwnerViaWhatsApp(
                customMessage:
                    'Hi Danish! I need to renew / upgrade my PackProof subscription (${seller!.email}).',
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'Renew',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
