import 'dart:io';

import 'package:path_provider/path_provider.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.orderId,
    required this.fileName,
    required this.filePath,
    required this.recordedAt,
    required this.sizeBytes,
  });

  final String orderId;
  final String fileName;
  final String filePath;
  final DateTime recordedAt;
  final int sizeBytes;
}

class HistoryService {
  Future<List<HistoryEntry>> getAllVideos() async {
    final dir = await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      return <HistoryEntry>[];
    }

    final entries = <HistoryEntry>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.mp4')) {
        continue;
      }

      final stat = await entity.stat();
      final segments = entity.path.split(Platform.pathSeparator);
      final orderId =
          segments.length >= 2 ? segments[segments.length - 2] : 'Unknown';

      entries.add(
        HistoryEntry(
          orderId: orderId,
          fileName: entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path.split(Platform.pathSeparator).last,
          filePath: entity.path,
          recordedAt: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }

    entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return entries;
  }

  Future<String?> findExistingOrderFolderPath(String orderId) async {
    final dir = await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      return null;
    }

    final matchingDirectories = <Directory>[];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is Directory && _folderName(entity.path) == orderId) {
        matchingDirectories.add(entity);
      }
    }

    if (matchingDirectories.isEmpty) {
      return null;
    }

    matchingDirectories.sort((a, b) => b.path.compareTo(a.path));
    return matchingDirectories.first.path;
  }

  String _folderName(String path) => path.split(Platform.pathSeparator).last;
}
