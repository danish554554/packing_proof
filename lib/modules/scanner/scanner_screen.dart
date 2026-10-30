import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../utils/order_id_parser.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.appBarTitle = 'Scan Order',
    this.statusHint = 'Point camera at Daraz barcode or QR label',
    this.tipText = 'Tip: for best result, scan the label area that shows the exact order number or full tracking ID.',
  });

  final String appBarTitle;
  final String statusHint;
  final String tipText;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isHandlingScan = false;
  bool _scanPaused = false;
  String _statusText = '';
  String? _lastRawValue;
  String? _lastParsedOrderId;

  @override
  void initState() {
    super.initState();
    _statusText = widget.statusHint;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isHandlingScan || _scanPaused) return;
    if (capture.barcodes.isEmpty) return;

    final String? rawValue = capture.barcodes.first.rawValue;

    if (rawValue == null || rawValue.trim().isEmpty) return;

    _isHandlingScan = true;

    final ParseOrderResult result = OrderIdParser.parse(rawValue);

    if (!mounted) {
      _isHandlingScan = false;
      return;
    }

    setState(() {
      _lastRawValue = rawValue;
      _lastParsedOrderId = result.orderId;
      _statusText = result.message;
    });

    if (!result.success || result.orderId == null) {
      _isHandlingScan = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      return;
    }

    _scanPaused = true;
    await _scannerController.stop();

    if (!mounted) {
      _isHandlingScan = false;
      return;
    }

    final bool? confirmed = await _showConfirmDialog(
      rawValue: rawValue,
      parsedValue: result.orderId!,
      helperMessage: result.message,
      detectedType: result.detectedType,
    );

    if (!mounted) {
      _isHandlingScan = false;
      return;
    }

    if (confirmed == true) {
      final String finalValue = _lastParsedOrderId ?? result.orderId!;
      Navigator.pop(context, finalValue);
      _isHandlingScan = false;
      return;
    }

    _scanPaused = false;
    _isHandlingScan = false;
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (mounted) {
      await _scannerController.start();
    }
  }

  Future<bool?> _showConfirmDialog({
    required String rawValue,
    required String parsedValue,
    required String helperMessage,
    required DetectedIdType detectedType,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: parsedValue);

    final String titleText = switch (detectedType) {
      DetectedIdType.orderNumber => 'Confirm Order Number',
      DetectedIdType.trackingId => 'Confirm Full Tracking ID',
      DetectedIdType.unknown => 'Confirm Value',
    };

    final String fieldLabel = switch (detectedType) {
      DetectedIdType.orderNumber => 'Detected Order Number',
      DetectedIdType.trackingId => 'Detected Full Tracking ID',
      DetectedIdType.unknown => 'Detected Value',
    };

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(titleText),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  helperMessage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Text(
                  fieldLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Edit if needed',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Raw scanned text',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    rawValue,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Only continue if this is the exact order number or exact full courier tracking ID you want to search later in Google Drive.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Scan Again'),
            ),
            ElevatedButton(
              onPressed: () {
                final String cleaned =
                    OrderIdParser.sanitizeForFolderName(controller.text);

                if (cleaned.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter the exact full order number or full tracking ID.',
                      ),
                    ),
                  );
                  return;
                }

                _lastParsedOrderId = cleaned;
                Navigator.pop(context, true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        actions: [
          IconButton(
            onPressed: () => _scannerController.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _handleDetection,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusText,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_lastParsedOrderId != null)
                  Text('Detected value: $_lastParsedOrderId'),
                if (_lastRawValue != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Raw scan: $_lastRawValue',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  widget.tipText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
