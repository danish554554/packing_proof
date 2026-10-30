import 'dart:io';

import 'package:path_provider/path_provider.dart';

class StorageStats {
  const StorageStats({
    required this.videoCount,
    required this.totalBytes,
  });

  final int videoCount;
  final int totalBytes;

  double get totalMb => totalBytes / (1024 * 1024);
}

class StorageService {
  Future<StorageStats> getStorageStats() async {
    final dir = await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      return const StorageStats(videoCount: 0, totalBytes: 0);
    }

    var count = 0;
    var totalBytes = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.mp4')) {
        final stat = await entity.stat();
        count += 1;
        totalBytes += stat.size;
      }
    }

    return StorageStats(videoCount: count, totalBytes: totalBytes);
  }
}
