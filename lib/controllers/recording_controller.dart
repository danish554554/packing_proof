import 'package:flutter/material.dart';

enum RecordingFlowType { packing, returnRecording }

extension RecordingFlowTypeLabel on RecordingFlowType {
  String get label {
    switch (this) {
      case RecordingFlowType.packing:
        return 'Packing';
      case RecordingFlowType.returnRecording:
        return 'Return';
    }
  }

  String get filePrefix {
    switch (this) {
      case RecordingFlowType.packing:
        return 'packing';
      case RecordingFlowType.returnRecording:
        return 'return';
    }
  }
}

class RecordingController extends ChangeNotifier {
  String? currentOrderId;
  RecordingFlowType currentFlowType = RecordingFlowType.packing;
  bool isRecording = false;
  bool isUploading = false;
  bool isQueuedForUpload = false;
  String? videoPath;
  String? uploadedDriveFileId;
  String? uploadedDriveFileName;
  String? uploadError;

  void setOrder(
    String orderId, {
    RecordingFlowType flowType = RecordingFlowType.packing,
  }) {
    currentOrderId = orderId;
    currentFlowType = flowType;
    isQueuedForUpload = false;
    uploadError = null;
    notifyListeners();
  }

  Future<void> startRecording() async {
    isRecording = true;
    isQueuedForUpload = false;
    uploadError = null;
    notifyListeners();
  }

  Future<void> stopRecording(String path) async {
    isRecording = false;
    videoPath = path;
    notifyListeners();
  }

  void queueUpload() {
    isUploading = true;
    isQueuedForUpload = true;
    uploadError = null;
    notifyListeners();
  }

  void finishUploading({
    String? driveFileId,
    String? driveFileName,
  }) {
    isUploading = false;
    isQueuedForUpload = false;
    uploadedDriveFileId = driveFileId;
    uploadedDriveFileName = driveFileName;
    uploadError = null;
    notifyListeners();
  }

  void failUploading(String message) {
    isUploading = false;
    uploadError = message;
    notifyListeners();
  }

  void reset() {
    currentOrderId = null;
    currentFlowType = RecordingFlowType.packing;
    isRecording = false;
    isUploading = false;
    isQueuedForUpload = false;
    videoPath = null;
    uploadedDriveFileId = null;
    uploadedDriveFileName = null;
    uploadError = null;
    notifyListeners();
  }
}
