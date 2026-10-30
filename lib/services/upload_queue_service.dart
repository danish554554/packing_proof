import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/recording_controller.dart';
import 'google_drive_service.dart';

class UploadQueueItem {
  UploadQueueItem({
    required this.id,
    required this.orderId,
    required this.filePath,
    required this.createdAt,
    this.flowType = RecordingFlowType.packing,
    this.targetDriveFolderId,
    this.retryCount = 0,
  });

  factory UploadQueueItem.fromJson(Map<String, dynamic> json) {
    final item = UploadQueueItem(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      flowType: _flowTypeFromName(json['flowType'] as String?),
      targetDriveFolderId: json['targetDriveFolderId'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
    );

    item.isUploading = json['isUploading'] as bool? ?? false;
    item.isCompleted = json['isCompleted'] as bool? ?? false;
    item.uploadedDriveFileId = json['uploadedDriveFileId'] as String?;
    item.uploadedDriveFileName = json['uploadedDriveFileName'] as String?;
    item.error = json['error'] as String?;
    item.webViewLink = json['webViewLink'] as String?;

    return item;
  }

  final String id;
  final String orderId;
  final String filePath;
  final DateTime createdAt;
  final RecordingFlowType flowType;
  final String? targetDriveFolderId;

  int retryCount = 0;
  bool isUploading = false;
  bool isCompleted = false;
  String? uploadedDriveFileId;
  String? uploadedDriveFileName;
  String? error;
  String? webViewLink;

  bool get isPending => !isUploading && !isCompleted && error == null;

  String get flowLabel => flowType.label;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'orderId': orderId,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'flowType': flowType.name,
      'targetDriveFolderId': targetDriveFolderId,
      'retryCount': retryCount,
      'isUploading': isUploading,
      'isCompleted': isCompleted,
      'uploadedDriveFileId': uploadedDriveFileId,
      'uploadedDriveFileName': uploadedDriveFileName,
      'error': error,
      'webViewLink': webViewLink,
    };
  }

  static RecordingFlowType _flowTypeFromName(String? value) {
    for (final item in RecordingFlowType.values) {
      if (item.name == value) {
        return item;
      }
    }
    return RecordingFlowType.packing;
  }
}

class UploadQueueService extends ChangeNotifier {
  UploadQueueService(this._driveService);

  static const String _storageKey = 'packproof_upload_queue_v2';
  static const int _maxAutoRetries = 5;

  GoogleDriveService _driveService;
  final Queue<UploadQueueItem> _pendingQueue = Queue<UploadQueueItem>();
  final List<UploadQueueItem> _allItems = <UploadQueueItem>[];

  bool _isProcessing = false;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;

  List<UploadQueueItem> get items =>
      List<UploadQueueItem>.unmodifiable(_allItems);

  List<UploadQueueItem> get recentCompletedItems {
    final completed = _allItems.where((item) => item.isCompleted).toList();
    completed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return completed;
  }

  int get pendingCount => _allItems.where((item) => item.isPending).length;

  int get uploadingCount =>
      _allItems.where((item) => item.isUploading).length;

  int get failedCount => _allItems.where((item) => item.error != null).length;

  int get completedCount =>
      _allItems.where((item) => item.isCompleted).length;

  int get todayCompletedCount {
    final now = DateTime.now();
    return _allItems.where((item) {
      return item.isCompleted &&
          item.createdAt.year == now.year &&
          item.createdAt.month == now.month &&
          item.createdAt.day == now.day;
    }).length;
  }

  static bool isTransientError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('upload interrupted') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('httpexception') ||
        lower.contains('timeoutexception') ||
        lower.contains('connection closed') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('broken pipe') ||
        lower.contains('network') ||
        lower.contains('failed host lookup') ||
        lower.contains('handshake') ||
        lower.contains('access token') ||
        lower.contains('token unavailable') ||
        lower.contains('not available') ||
        lower.contains('500') ||
        lower.contains('502') ||
        lower.contains('503') ||
        lower.contains('504');
  }

  void updateDriveService(GoogleDriveService driveService) {
    _driveService = driveService;
    // When Drive service updates (e.g., auth becomes ready), resume pending uploads automatically
    if (_isInitialized) {
      resumeQueue();
    }
  }

  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ?? <String>[];

    _allItems
      ..clear()
      ..addAll(
        rawList.map((raw) {
          final item = UploadQueueItem.fromJson(
            jsonDecode(raw) as Map<String, dynamic>,
          );

          final file = File(item.filePath);
          final bool fileExists = file.existsSync();

          if (!item.isCompleted) {
            item.isUploading = false;

            if (!fileExists) {
              item.error = 'Video file missing from local storage.';
            } else if (item.error == null || isTransientError(item.error!)) {
              // Video was uploading or interrupted when app closed.
              // Clear error so it stays in PENDING and is NOT marked as failed!
              item.error = null;
            }
          }

          return item;
        }),
      );

    _pendingQueue
      ..clear()
      ..addAll(_allItems.where((item) => item.isPending));

    _sortItems();
    _isInitialized = true;
    notifyListeners();

    if (_pendingQueue.isNotEmpty) {
      // Delay slightly on cold start to let silent sign-in initialize
      Future.delayed(const Duration(milliseconds: 1000), () {
        resumeQueue();
      });
    }
  }

  Future<void> resumeQueue() async {
    if (!_isInitialized) {
      return;
    }

    // Ensure all pending/recoverable items are queued in chronological order
    for (final item in _allItems) {
      if (item.isPending && !_pendingQueue.any((queued) => queued.id == item.id)) {
        _pendingQueue.add(item);
      }
    }

    if (_pendingQueue.isNotEmpty && !_isProcessing) {
      await _processQueue();
    }
  }

  Future<UploadQueueItem> enqueue({
    required String orderId,
    required String filePath,
    required RecordingFlowType flowType,
    String? targetDriveFolderId,
  }) async {
    final item = UploadQueueItem(
      id: '${DateTime.now().microsecondsSinceEpoch}_$orderId',
      orderId: orderId,
      filePath: filePath,
      createdAt: DateTime.now(),
      flowType: flowType,
      targetDriveFolderId: targetDriveFolderId,
    );

    _pendingQueue.add(item);
    _allItems.insert(0, item);
    await _persist();
    notifyListeners();

    _processQueue();
    return item;
  }

  Future<void> retryItem(UploadQueueItem item) async {
    if (item.isUploading || item.isCompleted) {
      return;
    }

    item.error = null;
    item.isUploading = false;
    item.retryCount = 0;

    if (!_pendingQueue.any((queued) => queued.id == item.id)) {
      _pendingQueue.addFirst(item);
    }

    await _persist();
    notifyListeners();

    await _processQueue();
  }

  Future<void> retryAllFailed() async {
    var hasRetries = false;
    for (final item in _allItems) {
      if (item.error != null && !item.isCompleted) {
        final file = File(item.filePath);
        if (file.existsSync()) {
          item.error = null;
          item.isUploading = false;
          item.retryCount = 0;
          if (!_pendingQueue.any((queued) => queued.id == item.id)) {
            _pendingQueue.add(item);
          }
          hasRetries = true;
        }
      }
    }

    if (hasRetries) {
      await _persist();
      notifyListeners();
      await _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      while (_pendingQueue.isNotEmpty) {
        final item = _pendingQueue.removeFirst();

        if (item.isCompleted) {
          continue;
        }

        final file = File(item.filePath);
        if (!await file.exists()) {
          item.isUploading = false;
          item.isCompleted = false;
          item.error = 'Video file is missing from local storage.';
          await _persist();
          notifyListeners();
          continue;
        }

        item.isUploading = true;
        item.error = null;
        await _persist();
        notifyListeners();

        try {
          final result = await _driveService.uploadVideo(
            orderId: item.orderId,
            filePath: item.filePath,
            flowType: item.flowType,
            existingFolderId: item.targetDriveFolderId,
          );

          item.isUploading = false;
          item.isCompleted = true;
          item.uploadedDriveFileId = result.fileId;
          item.uploadedDriveFileName = result.fileName;
          item.webViewLink = result.webViewLink;
          item.error = null;
          item.retryCount = 0;
        } catch (e) {
          item.isUploading = false;
          item.isCompleted = false;
          final errorStr = e.toString();

          if (isTransientError(errorStr) && item.retryCount < _maxAutoRetries) {
            item.retryCount++;
            // Keep error as NULL so this video stays in PENDING, never in FAILED!
            item.error = null;

            // Re-queue the item for automatic retry
            if (!_pendingQueue.any((queued) => queued.id == item.id)) {
              _pendingQueue.add(item);
            }

            await _persist();
            notifyListeners();

            // Wait a brief backoff (e.g. 2s, 4s...) before attempting the next upload
            await Future.delayed(Duration(seconds: 2 * item.retryCount));
            continue;
          } else {
            // Fatal error or retries fully exhausted
            item.error = errorStr;
          }
        }

        await _persist();
        notifyListeners();
      }
    } finally {
      _isProcessing = false;
      await _persist();
      _sortItems();
      notifyListeners();
    }
  }

  void _sortItems() {
    _allItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _allItems.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_storageKey, payload);
  }
}
