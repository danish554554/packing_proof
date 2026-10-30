import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../modules/history/history_screen.dart';
import '../../services/upload_queue_service.dart';
import '../../ui/home_screen.dart';
import '../settings/settings_screen.dart';

class UploadQueueScreen extends StatefulWidget {
  const UploadQueueScreen({
    super.key,
    this.initialFilter = QueueFilter.all,
  });

  final QueueFilter initialFilter;

  @override
  State<UploadQueueScreen> createState() => _UploadQueueScreenState();
}

class _UploadQueueScreenState extends State<UploadQueueScreen> {
  late QueueFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final uploadQueue = context.watch<UploadQueueService>();
    final allItems = uploadQueue.items;
    final filteredItems = _applyFilter(allItems);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Queue',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${allItems.length} item${allItems.length == 1 ? '' : 's'} in queue',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _selectedFilter == QueueFilter.all,
                      onTap: () => setState(() => _selectedFilter = QueueFilter.all),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Active',
                      selected: _selectedFilter == QueueFilter.active,
                      onTap: () => setState(() => _selectedFilter = QueueFilter.active),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Pending',
                      selected: _selectedFilter == QueueFilter.pending,
                      onTap: () => setState(() => _selectedFilter = QueueFilter.pending),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Done',
                      selected: _selectedFilter == QueueFilter.done,
                      onTap: () => setState(() => _selectedFilter = QueueFilter.done),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Failed',
                      selected: _selectedFilter == QueueFilter.failed,
                      onTap: () => setState(() => _selectedFilter = QueueFilter.failed),
                    ),
                  ],
                ),
              ),
              if (uploadQueue.failedCount > 0 &&
                  (_selectedFilter == QueueFilter.failed ||
                      _selectedFilter == QueueFilter.all)) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${uploadQueue.failedCount} failed upload${uploadQueue.failedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => uploadQueue.retryAllFailed(),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry all'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5A1F),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Expanded(
                child: filteredItems.isEmpty
                    ? const _EmptyQueueState()
                    : ListView.separated(
                        itemCount: filteredItems.length,
                        padding: const EdgeInsets.only(bottom: 16),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          return _QueueItemCard(
                            item: item,
                            onRetry: (!item.isCompleted && !item.isUploading)
                                ? () => uploadQueue.retryItem(item)
                                : null,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HistoryScreen(),
              ),
            );
          }
          else if (index == 3) {
  Navigator.pushReplacement(
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

  List<UploadQueueItem> _applyFilter(List<UploadQueueItem> items) {
    switch (_selectedFilter) {
      case QueueFilter.all:
        return items;
      case QueueFilter.active:
        return items.where((item) => item.isUploading).toList();
      case QueueFilter.pending:
        return items
            .where(
              (item) =>
                  !item.isUploading &&
                  !item.isCompleted &&
                  item.error == null,
            )
            .toList();
      case QueueFilter.done:
        return items.where((item) => item.isCompleted).toList();
      case QueueFilter.failed:
        return items.where((item) => item.error != null).toList();
    }
  }
}

enum QueueFilter {
  all,
  active,
  pending,
  done,
  failed,
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _primary = Color(0xFFFF5A1F);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _primary : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _primary : _border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : _textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyQueueState extends StatelessWidget {
  const _EmptyQueueState();

  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 28,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Queue is empty',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Record a packing video to get started.\nYour uploads will appear here automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
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

class _QueueItemCard extends StatelessWidget {
  final UploadQueueItem item;
  final VoidCallback? onRetry;

  const _QueueItemCard({
    required this.item,
    required this.onRetry,
  });

  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _success = Color(0xFF16A34A);
  static const Color _error = Color(0xFFDC2626);
  static const Color _warning = Color(0xFFF59E0B);
  static const Color _primary = Color(0xFFFF5A1F);

  @override
  Widget build(BuildContext context) {
    final visualState = _getVisualState(item);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visualState.softColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  visualState.icon,
                  color: visualState.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${item.flowLabel} • ${item.orderId}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ),
              _StatusBadge(
                label: visualState.label,
                color: visualState.color,
                softColor: visualState.softColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.filePath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: _textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatDateTime(item.createdAt),
            style: const TextStyle(
              fontSize: 12,
              color: _textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.retryCount > 0 &&
              item.error == null &&
              !item.isUploading &&
              !item.isCompleted) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: _warning,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Auto-retrying upload shortly (attempt ${item.retryCount}/5)...',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _warning,
                  ),
                ),
              ],
            ),
          ],
          if (item.error != null) ...[
            const SizedBox(height: 12),
            Text(
              item.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: _error,
                height: 1.4,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(item.error != null ? 'Retry upload' : 'Upload now'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _QueueVisualState _getVisualState(UploadQueueItem item) {
    if (item.isCompleted) {
      return const _QueueVisualState(
        label: 'Done',
        color: _success,
        softColor: Color(0xFFEAF8EE),
        icon: Icons.check_circle_outline,
      );
    }

    if (item.isUploading) {
      return const _QueueVisualState(
        label: 'Active',
        color: _primary,
        softColor: Color(0xFFFFEFE8),
        icon: Icons.cloud_upload_outlined,
      );
    }

    if (item.error != null) {
      return const _QueueVisualState(
        label: 'Failed',
        color: _error,
        softColor: Color(0xFFFDECEC),
        icon: Icons.error_outline,
      );
    }

    return const _QueueVisualState(
      label: 'Pending',
      color: _warning,
      softColor: Color(0xFFFFF7E6),
      icon: Icons.schedule_outlined,
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour == 0
            ? 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year} • $hour:$minute $suffix';
  }
}

class _QueueVisualState {
  final String label;
  final Color color;
  final Color softColor;
  final IconData icon;

  const _QueueVisualState({
    required this.label,
    required this.color,
    required this.softColor,
    required this.icon,
  });
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color softColor;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              label: 'Home',
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
              icon: Icons.history,
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
  static const Color _muted = Color(0xFF9CA3AF);

  @override
  Widget build(BuildContext context) {
    final color = selected ? _primary : _muted;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}