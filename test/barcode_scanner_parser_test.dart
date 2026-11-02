import 'package:flutter_test/flutter_test.dart';
import 'package:packproof_app/utils/order_id_parser.dart';

void main() {
  group('Category 3: Barcode & Daraz Tracking ID Parser Tests', () {
    test('SCAN-01: Correctly parses Daraz DEX, Leopard, Trax and Courier Barcodes', () {
      // 1. Daraz Express (DEX) standard format
      final dexResult = OrderIdParser.parse('PK-DEX211562582');
      expect(dexResult.success, isTrue);
      expect(dexResult.orderId, equals('PK-DEX211562582'));
      expect(dexResult.detectedType, equals(DetectedIdType.trackingId));

      // 2. Daraz Leopard Courier (LCS) format
      final lcsResult = OrderIdParser.parse('PK-LCS9876543210');
      expect(lcsResult.success, isTrue);
      expect(lcsResult.orderId, anyOf(equals('PK-LCS9876543210'), equals('LCS9876543210')));
      expect(lcsResult.detectedType, equals(DetectedIdType.trackingId));

      // 3. PostEx / Trax tracking format
      final postexResult = OrderIdParser.parse('PXT-98234821');
      expect(postexResult.success, isTrue);
      expect(postexResult.orderId, equals('PXT-98234821'));
    });

    test('SCAN-02: Sanitizes illegal filesystem characters from scanned strings', () {
      final dirtyInput = 'PK-DEX/2115:62582*?';
      final sanitized = OrderIdParser.sanitizeForFolderName(dirtyInput);

      // Verify no illegal characters for Windows/Android paths (/ \ : * ? " < > |)
      expect(sanitized.contains('/'), isFalse);
      expect(sanitized.contains(':'), isFalse);
      expect(sanitized.contains('*'), isFalse);
      expect(sanitized.contains('?'), isFalse);
    });

    test('SCAN-03: Extracts tracking ID from multi-line text label or receipt', () {
      final multiLineLabel = '''
DARAZ LOGISTICS
Seller: Danish Store
Tracking ID: PK-DEX211562582
Order No: 154829104829
Destination: Lahore
''';

      final result = OrderIdParser.parse(multiLineLabel);
      expect(result.success, isTrue);
      // Labeled order or tracking takes priority
      expect(result.orderId?.isNotEmpty, isTrue);
      expect(result.orderId == '154829104829' || result.orderId == 'PK-DEX211562582', isTrue);
    });

    test('SCAN-04: Gracefully handles blank or corrupted scan input', () {
      final emptyResult = OrderIdParser.parse('');
      expect(emptyResult.success, isFalse);
      expect(emptyResult.orderId, isNull);

      final whitespaceResult = OrderIdParser.parse('    ');
      expect(whitespaceResult.success, isFalse);
      expect(whitespaceResult.orderId, isNull);
    });
  });
}
