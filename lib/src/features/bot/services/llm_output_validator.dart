/// Validates and post-processes LLM output before displaying to the user.
/// Enforces length limits, language consistency, content filtering,
/// and hallucination guards per rule_engine_first_ai_second_strategy.md.
class LlmOutputValidator {
  static const int maxResponseLength = 500;

  static const _blockedTerms = <String>[
    'rivigo',
    'blackbuck',
    'porter',
    'vahak',
    'fr8',
  ];

  /// Validate and clean LLM response. Returns cleaned text or null if invalid.
  ValidationResult validate(String response, {String? userLocale}) {
    if (response.trim().isEmpty) {
      return const ValidationResult(
        isValid: false,
        reason: 'empty_response',
      );
    }

    var cleaned = response.trim();
    final issues = <String>[];

    // 1. Length check — truncate if too long
    if (cleaned.length > maxResponseLength) {
      cleaned = '${cleaned.substring(0, maxResponseLength - 3)}...';
      issues.add('truncated');
    }

    // 2. Content filter — block competitor names and harmful content
    final lowerCleaned = cleaned.toLowerCase();
    for (final term in _blockedTerms) {
      if (lowerCleaned.contains(term)) {
        cleaned = cleaned.replaceAll(
          RegExp(term, caseSensitive: false),
          '***',
        );
        issues.add('content_filtered');
      }
    }

    // 3. Language consistency check
    if (userLocale == 'hi' && !_containsDevanagari(cleaned)) {
      issues.add('language_mismatch');
      // Don't reject — just flag. The response may still be useful Hinglish.
    }

    // 4. Hallucination guard — check for fabricated phone numbers, emails
    if (_containsFabricatedContact(cleaned)) {
      issues.add('possible_hallucination');
      // Remove phone numbers and emails from response
      cleaned = cleaned.replaceAll(
        RegExp(r'\b\d{10,12}\b'),
        '[number removed]',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b'),
        '[email removed]',
      );
    }

    // 5. Extract implied actions (e.g., "aap load post kar sakte hain")
    final impliedAction = _extractImpliedAction(cleaned);

    return ValidationResult(
      isValid: true,
      cleanedText: cleaned,
      issues: issues,
      impliedAction: impliedAction,
    );
  }

  bool _containsDevanagari(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  bool _containsFabricatedContact(String text) {
    // Check for 10+ digit numbers (Indian phone numbers)
    if (RegExp(r'\b[6-9]\d{9}\b').hasMatch(text)) return true;
    // Check for email patterns
    if (RegExp(r'\b[\w.+-]+@[\w-]+\.[\w.]+\b').hasMatch(text)) return true;
    return false;
  }

  String? _extractImpliedAction(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('post load') ||
        lower.contains('load post') ||
        lower.contains('load banao') ||
        lower.contains('load post karo')) {
      return 'postLoad';
    }
    if (lower.contains('find load') ||
        lower.contains('load dhundh') ||
        lower.contains('load search')) {
      return 'findLoads';
    }
    if (lower.contains('book') || lower.contains('book karo')) {
      return 'bookLoad';
    }
    if (lower.contains('navigate') ||
        lower.contains('raasta') ||
        lower.contains('route')) {
      return 'navigateTo';
    }
    if (lower.contains('status') ||
        lower.contains('trip check') ||
        lower.contains('kahan pahuncha')) {
      return 'checkStatus';
    }
    return null;
  }
}

class ValidationResult {
  final bool isValid;
  final String? cleanedText;
  final String? reason;
  final List<String> issues;
  final String? impliedAction;

  const ValidationResult({
    required this.isValid,
    this.cleanedText,
    this.reason,
    this.issues = const [],
    this.impliedAction,
  });

  bool get wasModified => issues.isNotEmpty;
  bool get hasImpliedAction => impliedAction != null;
}
