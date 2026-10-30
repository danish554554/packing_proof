import 'package:flutter/material.dart';

import '../../modules/queue/upload_queue_screen.dart';
import '../../ui/home_screen.dart';
import '../settings/settings_screen.dart';
import 'history_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: FutureBuilder<List<HistoryEntry>>(
            future: HistoryService().getAllVideos(),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? const <HistoryEntry>[];
              final historyGroups = _buildGroups(entries);
              final totalCount = entries.length;

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$totalCount ${totalCount == 1 ? 'recording' : 'recordings'} saved',
                    style: const TextStyle(
                      fontSize: 14,
                      color: _textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: historyGroups.isEmpty
                        ? const _EmptyHistoryState()
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: historyGroups.length,
                            itemBuilder: (context, index) {
                              final group = historyGroups[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _HistoryGroupSection(group: group),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const UploadQueueScreen(),
              ),
            );
          } else if (index == 3) {
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

  List<HistoryDayGroup> _buildGroups(List<HistoryEntry> entries) {
    final Map<String, List<HistoryItem>> grouped = <String, List<HistoryItem>>{};

    for (final entry in entries) {
      final key = _formatDateKey(entry.recordedAt);
      grouped.putIfAbsent(key, () => <HistoryItem>[]).add(
            HistoryItem(
              orderId: entry.orderId,
              fileName: entry.fileName,
              timeLabel: _formatTime(entry.recordedAt),
              sizeLabel: _formatBytes(entry.sizeBytes),
            ),
          );
    }

    return grouped.entries
        .map(
          (entry) => HistoryDayGroup(
            title: entry.key,
            items: entry.value,
          ),
        )
        .toList();
  }

  String _formatDateKey(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour == 0
            ? 12
            : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

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
                'No recordings yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your packing videos will appear here organized by date' ,
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

class _HistoryGroupSection extends StatelessWidget {
  final HistoryDayGroup group;

  const _HistoryGroupSection({
    required this.group,
  });

  static const Color _textMuted = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        ...group.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HistoryCard(item: item),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;

  const _HistoryCard({
    required this.item,
  });

  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _primary = Color(0xFFFF5A1F);

  @override
  Widget build(BuildContext context) {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFE8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.videocam_outlined,
              color: _primary,
              size: 22,
            ),
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
                const SizedBox(height: 6),
                Text(
                  item.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.folder_outlined,
                      size: 14,
                      color: _textMuted,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.sizeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

class HistoryDayGroup {
  final String title;
  final List<HistoryItem> items;

  const HistoryDayGroup({
    required this.title,
    required this.items,
  });
}

class HistoryItem {
  final String orderId;
  final String fileName;
  final String timeLabel;
  final String sizeLabel;

  const HistoryItem({
    required this.orderId,
    required this.fileName,
    required this.timeLabel,
    required this.sizeLabel,
  });
}
