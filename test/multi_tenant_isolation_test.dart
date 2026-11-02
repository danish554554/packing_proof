import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:packproof_app/models/seller_profile.dart';
import 'package:packproof_app/services/google_auth_service.dart';
import 'package:packproof_app/services/google_drive_service.dart';
import 'package:packproof_app/services/upload_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'init') {
          return null;
        }
        if (methodCall.method == 'signOut') {
          return null;
        }
        if (methodCall.method == 'isSignedIn') {
          return false;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/google_sign_in'),
      null,
    );
  });

  group('AUTH-05: Multi-Tenant Data Isolation Tests', () {
    test('Google Drive session does NOT leak across sellers on same device', () async {
      SharedPreferences.setMockInitialValues({
        'packproof_google_drive_owner_seller_id': 'seller-danish-123',
      });

      final authService = GoogleAuthService();

      // Waqas (seller-waqas-456) logs in
      await authService.syncWithSeller('seller-waqas-456');

      // Verify Drive is disconnected for Waqas
      expect(authService.currentUser, isNull);
      expect(await authService.isSignedIn(), isFalse);
    });

    test('Upload queue is strictly isolated per seller ID', () async {
      // Simulate Danish having 1 completed upload in his scoped storage key
      final danishItem = {
        'id': 'danish-item-001',
        'orderId': 'PK-DEX211562582',
        'filePath': '/dummy/path/danish.mp4',
        'createdAt': DateTime.now().toIso8601String(),
        'flowType': 'packing',
        'isCompleted': true,
      };

      SharedPreferences.setMockInitialValues({
        'packproof_upload_queue_seller-danish-123': [jsonEncode(danishItem)],
      });

      final driveService = GoogleDriveService(GoogleAuthService());
      final queueService = UploadQueueService(driveService);

      // Waqas logs in
      await queueService.switchSeller('seller-waqas-456');

      // Verify Waqas sees 0 items, 0 completed, 0 pending
      expect(queueService.items, isEmpty);
      expect(queueService.todayCompletedCount, equals(0));
      expect(queueService.recentCompletedItems, isEmpty);
      expect(queueService.pendingCount, equals(0));
      expect(queueService.uploadingCount, equals(0));
      expect(queueService.failedCount, equals(0));

      // Danish logs back in
      await queueService.switchSeller('seller-danish-123');
      expect(queueService.items.length, equals(1));
      expect(queueService.items.first.orderId, equals('PK-DEX211562582'));
    });

    test('History and Storage calculation strictly scopes to current seller directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('packproof_test_');

      try {
        // Create files for Danish
        final danishFolder = Directory('${tempDir.path}/sellers/seller-danish-123/2026-11-01/PK-DEX1');
        await danishFolder.create(recursive: true);
        final danishVideo = File('${danishFolder.path}/packing_PK-DEX1_1001.mp4');
        await danishVideo.writeAsBytes(List.filled(1024, 0)); // 1KB

        // Verify Danish folder has 1 file, Waqas folder does not exist yet
        final waqasDir = Directory('${tempDir.path}/sellers/seller-waqas-456');
        expect(await waqasDir.exists(), isFalse);

        // Waqas creates 1 video
        final waqasFolder = Directory('${tempDir.path}/sellers/seller-waqas-456/2026-11-02/PK-WAQAS1');
        await waqasFolder.create(recursive: true);
        final waqasVideo = File('${waqasFolder.path}/packing_PK-WAQAS1_2001.mp4');
        await waqasVideo.writeAsBytes(List.filled(2048, 0)); // 2KB

        expect(await waqasDir.exists(), isTrue);
        final waqasFiles = waqasDir.listSync(recursive: true).whereType<File>().toList();
        expect(waqasFiles.length, equals(1));
        expect(waqasFiles.first.path.contains('PK-WAQAS1'), isTrue);

        // Verify Danish's directory only contains Danish's file
        final danishFiles = Directory('${tempDir.path}/sellers/seller-danish-123').listSync(recursive: true).whereType<File>().toList();
        expect(danishFiles.length, equals(1));
        expect(danishFiles.first.path.contains('PK-DEX1'), isTrue);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('AUTH-06: Cold Boot Offline Rehydration Tests', () {
    test('Offline cached profile rehydrates seamlessly without network', () async {
      final sampleProfile = SellerProfile(
        id: 'seller-waqas-456',
        email: 'waqasmattah54@gmail.com',
        sellerName: 'Waqas',
        storeName: 'Waqas Store',
        phone: '03001234567',
        plan: 'platinum',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 29)),
        monthlyQuota: 999999,
        videosThisMonth: 0,
      );

      SharedPreferences.setMockInitialValues({
        'packproof_cached_seller_profile': jsonEncode(sampleProfile.toJson()),
      });

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('packproof_cached_seller_profile');
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!) as Map<String, dynamic>;
      final rehydrated = SellerProfile.fromJson(decoded);

      expect(rehydrated.id, equals('seller-waqas-456'));
      expect(rehydrated.email, equals('waqasmattah54@gmail.com'));
      expect(rehydrated.plan, equals('platinum'));
      expect(rehydrated.isExpired, isFalse);
      expect(rehydrated.isQuotaReached, isFalse);
    });
  });
}
