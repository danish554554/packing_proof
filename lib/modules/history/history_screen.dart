import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../modules/queue/upload_queue_screen.dart';
import '../../services/saas_auth_service.dart';
import '../../ui/home_screen.dart';
import '../settings/settings_screen.dart';
import 'history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _bg = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF111827);
  static const Color _textMuted = Color(0xFF6B7280);
  static const Color _primary = Color(0xFFFF5A1F);

  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Packing', 'Return'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seller = context.watch<SaasAuthService>().currentSeller;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: FutureBuilder<List<HistoryEntry>>(
            future: HistoryService().getAllVideos(sellerId: seller?.id),
            builder: (context, snapshot) {
              final allEntries = snapshot.data ?? const <HistoryEntry>[];

              // Apply search & filter
              final filteredEntries = allEntries.where((entry) {
                final matchesSearch = _searchQuery.isEmpty ||
                    entry.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    entry.fileName.toLowerCase().contains(_searchQuery.toLowerCase());

                if (!matchesSearch) return false;

                if (_selectedFilter == 'Packing') {
                  return !entry.fileName.toLowerCase().contains('return');
                } else if (_selectedFilter == 'Return') {
                  return entry.fileName.toLowerCase().contains('return');
                }
                return true;
              }).toList();

              final historyGroups = _buildGroups(filteredEntries);
              final totalCount = allEntries.length;

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _primary),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'History',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalCount saved proof${totalCount == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: _textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Modern Search Box
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      style: const TextStyle(fontSize: 14, color: _textDark),
                      decoration: InputDecoration(
                        hintText: 'Search by Daraz tracking number...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9CA3AF),
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Color(0xFF9CA3AF),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Packing', 'Return'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? _primary : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? _primary
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : _textMuted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // List of proof groups
                  Expanded(
                    child: historyGroups.isEmpty
                        ? (_searchQuery.isNotEmpty || _selectedFilter != 'All'
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.search_off_rounded,
                                      size: 48,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No proofs matching "$_searchQuery"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: _textDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Try a different tracking number or filter',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const _EmptyHistoryState())
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: historyGroups.length,
                            itemBuilder: (context, index) {
                              final group = historyGroups[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
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
    final Map<String, List<HistoryItem>> grouped =
        <String, List<HistoryItem>>{};

    for (final entry in entries) {
      final key = _formatDateKey(entry.recordedAt);
      grouped.putIfAbsent(key, () => <HistoryItem>[]).add(
            HistoryItem(
              orderId: entry.orderId,
              fileName: entry.fileName,
              filePath: entry.filePath,
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
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day) {
      return 'Yesterday';
    }
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

class _VideoProofThumbnail extends StatelessWidget {
  final String orderId;
  final String? durationLabel;
  final VoidCallback? onTap;

  const _VideoProofThumbnail({
    required this.orderId,
    this.durationLabel = '0:24s',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        height: 74,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF3F3028),
              Color(0xFF221A16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.16,
              child: const Icon(
                Icons.inventory_2_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            Positioned(
              right: 5,
              bottom: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  durationLabel ?? '0:24s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItem item;

  const _HistoryCard({
    required this.item,
  });

  static const Color _textDark = Color(0xFF111827);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _success = Color(0xFF16A34A);

  void _shareProof(BuildContext context) async {
    try {
      if (item.filePath != null) {
        final file = File(item.filePath!);
        if (await file.exists()) {
          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'PackProof Daraz Claim Proof: Order #${item.orderId}',
          );
          return;
        }
      }
      await Share.share(
        'PackProof Daraz Claim Proof: Order #${item.orderId}\nUploaded to Google Drive',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.orderId,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                  letterSpacing: -0.3,
                ),
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: item.orderId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied tracking: ${item.orderId}'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: Color(0xFFFF5A1F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VideoProofThumbnail(
                orderId: item.orderId,
                durationLabel: '0:24s',
                onTap: () => _shareProof(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video Duration: 0:24s',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'File Size:  ${item.sizeLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: _success,
                          size: 15,
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Uploaded to Google Drive',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF15803D),
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _shareProof(context),
              icon: const Icon(Icons.share_outlined, size: 15),
              label: const Text(
                'Share Claim Proof',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textDark,
                side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
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
  final String? filePath;

  const HistoryItem({
    required this.orderId,
    required this.fileName,
    required this.timeLabel,
    required this.sizeLabel,
    this.filePath,
  });
}
