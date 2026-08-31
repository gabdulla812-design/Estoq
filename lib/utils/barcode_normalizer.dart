class BarcodeNormalizer {
  const BarcodeNormalizer._();

  static String normalize(String rawValue) {
    var value = rawValue.trim();
    if (value.isEmpty) return value;

    value = value.replaceAll('\u001D', '');

    if (value.length >= 3 && value[0] == ']' && value.substring(1, 3).toLowerCase() == 'd2') {
      value = value.substring(3);
    }

    final parenthesized = RegExp(r'^\(01\)(\d{14})').firstMatch(value);
    final compact = RegExp(r'^01(\d{14})').firstMatch(value);
    final gtin14 = parenthesized?.group(1) ?? compact?.group(1);

    if (gtin14 != null && _isValidGtin(gtin14)) {
      return _canonicalizeGtin14(gtin14);
    }

    if (RegExp(r'^\d{14}$').hasMatch(value) && _isValidGtin(value)) {
      return _canonicalizeGtin14(value);
    }

    return value;
  }

  static String _canonicalizeGtin14(String gtin14) {
    return gtin14.startsWith('0') ? gtin14.substring(1) : gtin14;
  }

  static bool _isValidGtin(String digits) {
    if (!RegExp(r'^\d{8,14}$').hasMatch(digits)) return false;

    var sum = 0;
    var weightThree = true;
    for (var i = digits.length - 2; i >= 0; i--) {
      final digit = int.parse(digits[i]);
      sum += digit * (weightThree ? 3 : 1);
      weightThree = !weightThree;
    }

    final expectedCheckDigit = (10 - (sum % 10)) % 10;
    return expectedCheckDigit == int.parse(digits[digits.length - 1]);
  }
}
