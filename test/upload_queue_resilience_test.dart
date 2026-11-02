import 'package:flutter_test/flutter_test.dart';
import 'package:packproof_app/controllers/recording_controller.dart';
import 'package:packproof_app/services/upload_queue_service.dart';

void main() {
  group('Category 5 & 6: Upload Queue Resilience & Error Classification Tests', () {
    test('QUEUE-03: Correctly identifies transient network errors for automatic retry', () {
      // 1. Socket timeouts
      expect(UploadQueueService.isTransientError('SocketException: OS Error: Connection timed out'), isTrue);

      // 2. Client & HTTP interruptions
      expect(UploadQueueService.isTransientError('ClientException: Connection closed before full header was received'), isTrue);
      expect(UploadQueueService.isTransientError('Upload interrupted: connection reset by peer'), isTrue);

      // 3. Google OAuth Token availability errors
      expect(UploadQueueService.isTransientError('Google Drive access token not available. Please connect Google Drive.'), isTrue);

      // 4. Server 5xx errors
      expect(UploadQueueService.isTransientError('Server error 503 Service Unavailable'), isTrue);
      expect(UploadQueueService.isTransientError('502 Bad Gateway'), isTrue);

      // 5. Permanent errors should NOT be classified as transient
      expect(UploadQueueService.isTransientError('404 File Not Found in Drive'), isFalse);
      expect(UploadQueueService.isTransientError('403 Insufficient Permissions / Storage Quota Exceeded'), isFalse);
    });

    test('QUEUE-01 & QUEUE-05: Enqueuing items and clearing completed items', () {
      final item1 = UploadQueueItem(
        id: 'item-1',
        orderId: 'PK-DEX1',
        filePath: '/dummy/1.mp4',
        createdAt: DateTime.now(),
        flowType: RecordingFlowType.packing,
      );

      final item2 = UploadQueueItem(
        id: 'item-2',
        orderId: 'PK-DEX2',
        filePath: '/dummy/2.mp4',
        createdAt: DateTime.now(),
        flowType: RecordingFlowType.returnRecording,
      );

      expect(item1.isPending, isTrue);
      expect(item1.isCompleted, isFalse);
      expect(item1.flowLabel, equals('Packing'));
      expect(item2.flowLabel, equals('Return'));

      // Mark item1 completed
      item1.isCompleted = true;
      expect(item1.isPending, isFalse);

      // Mark item2 with transient error
      item2.error = 'SocketException: Network down';
      expect(item2.isPending, isFalse);
    });
  });
}
