import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/order_id_parser.dart';

class ScannerService {
  String? extractOrderId(Barcode barcode) {
    final raw = barcode.rawValue;

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final result = OrderIdParser.parse(raw);
    return result.orderId;
  }
}
