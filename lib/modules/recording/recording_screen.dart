import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../controllers/recording_controller.dart';
import '../../services/google_drive_service.dart';
import '../../services/saas_auth_service.dart';
import '../../services/upload_queue_service.dart';
import '../history/history_service.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCameraError = false;
  bool _isPreparingSave = false;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isCameraError = true;
        });
        return;
      }

      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraError = true;
      });
    }
  }

  Future<String> _getLocalFilePath(
    String orderId,
    RecordingFlowType flowType, {
    String? sellerId,
  }) async {
    final now = DateTime.now();
    final docsDir = await getApplicationDocumentsDirectory();
    String? orderFolder;

    if (flowType == RecordingFlowType.returnRecording) {
      orderFolder = await HistoryService().findExistingOrderFolderPath(
        orderId,
        sellerId: sellerId,
      );
    }

    if (orderFolder == null || orderFolder.isEmpty) {
      final dateFolderName =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (sellerId != null && sellerId.isNotEmpty) {
        orderFolder = '${docsDir.path}/sellers/$sellerId/$dateFolderName/$orderId';
      } else {
        orderFolder = '${docsDir.path}/$dateFolderName/$orderId';
      }
    }

    await Directory(orderFolder).create(recursive: true);

    return '$orderFolder/${flowType.filePrefix}_${orderId}_${now.millisecondsSinceEpoch}.mp4';
  }

  Future<void> startRecording() async {
    final recordingController = context.read<RecordingController>();

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _cameraController!.value.isRecordingVideo) {
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      await recordingController.startRecording();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Start recording failed: $e')),
      );
    }
  }

  Future<void> stopRecording() async {
    final recordingController = context.read<RecordingController>();
    final uploadQueueService = context.read<UploadQueueService>();
    final driveService = context.read<GoogleDriveService>();
    final orderId = recordingController.currentOrderId;
    final flowType = recordingController.currentFlowType;

    if (orderId == null || orderId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order ID missing. Please scan again.')),
      );
      return;
    }

    if (_cameraController == null ||
        !_cameraController!.value.isRecordingVideo ||
        _isPreparingSave) {
      return;
    }

    setState(() {
      _isPreparingSave = true;
    });

    try {
      final file = await _cameraController!.stopVideoRecording();
      await recordingController.stopRecording(file.path);

      String? targetDriveFolderId;
      if (flowType == RecordingFlowType.returnRecording) {
        targetDriveFolderId =
            await driveService.findExistingOrderFolderId(orderId: orderId);

        if (targetDriveFolderId == null || targetDriveFolderId.isEmpty) {
          throw Exception(
            'No existing PackProof folder was found in Google Drive for tracking ID $orderId.',
          );
        }
      }

      if (!mounted) return;
      final seller = context.read<SaasAuthService>().currentSeller;
      final newPath = await _getLocalFilePath(
        orderId,
        flowType,
        sellerId: seller?.id,
      );
      final savedFile = await File(file.path).copy(newPath);

      await recordingController.stopRecording(savedFile.path);
      recordingController.queueUpload();

      await uploadQueueService.enqueue(
        orderId: orderId,
        filePath: savedFile.path,
        flowType: flowType,
        targetDriveFolderId: targetDriveFolderId,
      );

      if (mounted) {
        context.read<SaasAuthService>().recordVideoUsage(
              trackingNumber: orderId,
              orderType: flowType == RecordingFlowType.returnRecording
                  ? 'return'
                  : 'packing',
            );
      }

      recordingController.reset();

      if (!mounted) return;

      final savedLabel = flowType == RecordingFlowType.returnRecording
          ? 'Return video saved and queued in the original folder'
          : 'Packing video saved and queued for upload';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedLabel: $orderId'),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      recordingController.failUploading(e.toString());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording save failed: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingSave = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recordingController = context.watch<RecordingController>();
    final flowType = recordingController.currentFlowType;
    final title = flowType == RecordingFlowType.returnRecording
        ? 'Record Return'
        : 'Record Packing';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _isCameraError
          ? const Center(child: Text('Camera not available'))
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CameraPreview(_cameraController!),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${flowType.label}: ${recordingController.currentOrderId ?? ''}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isPreparingSave
                              ? null
                              : recordingController.isRecording
                                  ? stopRecording
                                  : startRecording,
                          child: Text(
                            recordingController.isRecording
                                ? _isPreparingSave
                                    ? 'Saving...'
                                    : 'Stop Recording & Queue Upload'
                                : 'Start Recording',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
    );
  }
}
