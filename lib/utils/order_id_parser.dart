class OrderIdParser {
  static ParseOrderResult parse(String rawInput) {
    final String raw = rawInput.trim();

    if (raw.isEmpty) {
      return const ParseOrderResult(
        success: false,
        message: 'Scanned value is empty.',
      );
    }

    final String normalized = _normalizeWhitespace(raw);

    // 1) Exact order number from labeled text
    final String? exactOrderFromText = _extractLabeledValue(
      normalized,
      const [
        r'order\s*(?:id|no|number)?',
        r'order\s*#',
      ],
    );

    if (exactOrderFromText != null) {
      final String cleaned = sanitizeForFolderName(exactOrderFromText);
      if (_isStrongOrderNumber(cleaned)) {
        return ParseOrderResult(
          success: true,
          orderId: cleaned,
          message: 'Exact order number extracted from label text.',
          rawValue: raw,
          detectedType: DetectedIdType.orderNumber,
        );
      }
    }

    // 2) Exact order number from URL
    final String? exactOrderFromUrl = _extractFromUrlByKeys(
      normalized,
      const [
        'order',
        'orderid',
        'order_id',
        'orderno',
        'order_no',
        'order-number',
      ],
    );

    if (exactOrderFromUrl != null) {
      final String cleaned = sanitizeForFolderName(exactOrderFromUrl);
      if (_isStrongOrderNumber(cleaned)) {
        return ParseOrderResult(
          success: true,
          orderId: cleaned,
          message: 'Exact order number extracted from URL.',
          rawValue: raw,
          detectedType: DetectedIdType.orderNumber,
        );
      }
    }

    // 3) Courier-pattern exact tracking ID from raw text
    final String? courierTracking = _extractCourierTrackingId(normalized);
    if (courierTracking != null) {
      return ParseOrderResult(
        success: true,
        orderId: courierTracking,
        message: 'Exact courier tracking ID extracted.',
        rawValue: raw,
        detectedType: DetectedIdType.trackingId,
      );
    }

    // 4) Tracking from explicit labels
    final String? exactTrackingFromText = _extractLabeledValue(
      normalized,
      const [
        r'tracking\s*(?:id|no|number)?',
        r'awb',
        r'shipment\s*(?:id|no|number)?',
        r'consignment\s*(?:id|no|number)?',
        r'cn',
        r'reference',
      ],
    );

    if (exactTrackingFromText != null) {
      final String cleaned = sanitizeForFolderName(exactTrackingFromText);
      if (_isStrongTrackingId(cleaned)) {
        return ParseOrderResult(
          success: true,
          orderId: cleaned,
          message: 'Exact full tracking ID extracted from label text.',
          rawValue: raw,
          detectedType: DetectedIdType.trackingId,
        );
      }
    }

    // 5) Tracking from URL
    final String? exactTrackingFromUrl = _extractFromUrlByKeys(
      normalized,
      const [
        'tracking',
        'trackingid',
        'tracking_id',
        'trackingno',
        'tracking_no',
        'awb',
        'awbno',
        'awb_no',
        'shipment',
        'shipmentid',
        'shipment_id',
        'cn',
        'reference',
      ],
    );

    if (exactTrackingFromUrl != null) {
      final String cleaned = sanitizeForFolderName(exactTrackingFromUrl);
      if (_isStrongTrackingId(cleaned)) {
        return ParseOrderResult(
          success: true,
          orderId: cleaned,
          message: 'Exact full tracking ID extracted from URL.',
          rawValue: raw,
          detectedType: DetectedIdType.trackingId,
        );
      }
    }

    // 6) Whole value checks
    final String sanitizedWhole = sanitizeForFolderName(normalized);

    if (_isStrongOrderNumber(sanitizedWhole)) {
      return ParseOrderResult(
        success: true,
        orderId: sanitizedWhole,
        message: 'Whole scanned value looks like an exact order number.',
        rawValue: raw,
        detectedType: DetectedIdType.orderNumber,
      );
    }

    if (_isStrongTrackingId(sanitizedWhole)) {
      return ParseOrderResult(
        success: true,
        orderId: sanitizedWhole,
        message: 'Whole scanned value looks like an exact full tracking ID.',
        rawValue: raw,
        detectedType: DetectedIdType.trackingId,
      );
    }

    // 7) Numeric fallback only for strong order number
    final List<String> numericCandidates = _extractNumericCandidates(normalized);

    if (numericCandidates.isNotEmpty) {
      numericCandidates.sort((a, b) => b.length.compareTo(a.length));
      final String candidate = sanitizeForFolderName(numericCandidates.first);

      if (_isStrongOrderNumber(candidate)) {
        return ParseOrderResult(
          success: true,
          orderId: candidate,
          message: 'Numeric order number detected as fallback.',
          rawValue: raw,
          detectedType: DetectedIdType.orderNumber,
        );
      }
    }

    return ParseOrderResult(
      success: false,
      message:
          'Could not detect an exact order number or exact full tracking ID. Please scan again or enter manually.',
      rawValue: raw,
      detectedType: DetectedIdType.unknown,
    );
  }

  static String sanitizeForFolderName(String input) {
    String value = input.trim();

    value = value.replaceAll(RegExp(r'[\\/:*?"<>|#%&{}$!@+=`~]'), '');
    value = value.replaceAll(RegExp(r'\s+'), '_');
    value = value.replaceAll(RegExp(r'_+'), '_');
    value = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    value = value.replaceAll(RegExp(r'^[._-]+'), '');
    value = value.replaceAll(RegExp(r'[._-]+$'), '');

    if (value.length > 80) {
      value = value.substring(0, 80);
    }

    return value;
  }

  static String _normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _extractFromUrlByKeys(String input, List<String> keys) {
    final Uri? uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme) return null;

    final Map<String, String> params = uri.queryParameters.map(
      (key, value) => MapEntry(key.toLowerCase(), value),
    );

    for (final key in keys) {
      final String? value = params[key.toLowerCase()];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  static String? _extractLabeledValue(String input, List<String> labelPatterns) {
    for (final label in labelPatterns) {
      final RegExp pattern = RegExp(
        '($label)\\s*[:\\-]?\\s*([A-Za-z0-9._-]{6,50})',
        caseSensitive: false,
      );

      final Match? match = pattern.firstMatch(input);
      if (match != null && match.groupCount >= 2) {
        final String? value = match.group(2);
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }

    return null;
  }

  static String? _extractCourierTrackingId(String input) {
    // Split by common separators and also inspect full string.
    final List<String> chunks = <String>[
      input,
      ...input.split(RegExp(r'[,;\n\r]+')),
    ];

    // Known Pakistan courier-style patterns based on your use case.
    final List<RegExp> patterns = <RegExp>[
      RegExp(r'\bPK-DEX[A-Za-z0-9-]{5,30}\b', caseSensitive: false),
      RegExp(r'\bLCS[A-Za-z0-9-]{5,30}\b', caseSensitive: false),
      RegExp(r'\bTCS[A-Za-z0-9-]{5,30}\b', caseSensitive: false),

      // Generic prefix + mixed alphanumeric body, useful for variations.
      RegExp(r'\b[A-Z]{2,6}-[A-Z]{2,6}[A-Za-z0-9-]{4,30}\b'),
      RegExp(r'\b[A-Z]{2,6}[A-Za-z0-9-]{6,30}\b'),
    ];

    for (final rawChunk in chunks) {
      final String chunk = rawChunk.trim();
      if (chunk.isEmpty) continue;

      // Skip obvious price-looking chunks
      if (_looksLikePrice(chunk)) continue;

      for (final pattern in patterns) {
        final Match? match = pattern.firstMatch(chunk);
        if (match != null) {
          final String candidate = sanitizeForFolderName(match.group(0)!);
          if (_isStrongTrackingId(candidate) && !_looksLikePrice(candidate)) {
            return candidate;
          }
        }
      }
    }

    return null;
  }

  static bool _looksLikePrice(String value) {
    final String normalized = value.replaceAll(',', '').trim();
    return RegExp(r'^\d+(\.\d{2})$').hasMatch(normalized);
  }

  static List<String> _extractNumericCandidates(String input) {
    final Iterable<Match> matches = RegExp(r'\d{8,20}').allMatches(input);
    return matches.map((m) => m.group(0)!).toSet().toList();
  }

  static bool _isStrongOrderNumber(String value) {
    if (value.isEmpty) return false;
    return RegExp(r'^\d{8,20}$').hasMatch(value);
  }

  static bool _isStrongTrackingId(String value) {
    if (value.isEmpty) return false;
    if (value.length < 8 || value.length > 40) return false;

    final bool hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final bool hasDigit = RegExp(r'\d').hasMatch(value);
    final bool validChars = RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(value);

    return hasLetter && hasDigit && validChars;
  }
}

enum DetectedIdType {
  orderNumber,
  trackingId,
  unknown,
}

class ParseOrderResult {
  final bool success;
  final String? orderId;
  final String message;
  final String? rawValue;
  final DetectedIdType detectedType;

  const ParseOrderResult({
    required this.success,
    this.orderId,
    required this.message,
    this.rawValue,
    this.detectedType = DetectedIdType.unknown,
  });
}