/// Sanitizes user input before processing by the bot engine.
/// Prevents injection attacks, normalizes text, and enforces length limits.
class InputSanitizer {
  static const int maxLength = 500;

  /// Sanitize user input: trim, remove control chars, strip tags, truncate.
  String sanitize(String input) {
    var result = input;

    // 1. Trim whitespace
    result = result.trim();

    // 2. Remove control characters (except newline and tab)
    result = result.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // 3. Strip HTML/script tags
    result = result.replaceAll(RegExp(r'<[^>]*>', multiLine: true), '');

    // 4. Remove potential script injection patterns
    result = result.replaceAll(RegExp(r'javascript:', caseSensitive: false), '');
    result = result.replaceAll(RegExp(r'on\w+\s*=', caseSensitive: false), '');

    // 5. Normalize Unicode to NFC (collapse combining characters)
    // Dart strings are already UTF-16; we normalize common diacritics
    result = _normalizeUnicode(result);

    // 6. Collapse multiple whitespace into single space (preserve newlines)
    result = result.replaceAll(RegExp(r'[^\S\n]+'), ' ');

    // 7. Truncate to max length
    if (result.length > maxLength) {
      result = result.substring(0, maxLength);
    }

    return result.trim();
  }

  /// Basic Unicode normalization — collapse zero-width chars and
  /// excessive combining marks that could be used for obfuscation.
  String _normalizeUnicode(String input) {
    // Remove zero-width characters (used for invisible text injection)
    var result = input.replaceAll(RegExp(r'[\u200B-\u200F\u2028-\u202F\uFEFF]'), '');

    // Remove excessive combining marks (more than 3 in a row)
    result = result.replaceAll(RegExp(r'(\p{M}{4,})', unicode: true), '');

    return result;
  }
}
