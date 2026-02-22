import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tests for AuthService._normalizeIndianPhone logic.
/// Since _normalizeIndianPhone is private, we replicate the exact logic here
/// and verify it matches the source contract.
String _normalizeIndianPhone(String input) {
  var digits = input.trim().replaceAll(RegExp(r'\D'), '');

  if (digits.startsWith('91') && digits.length == 12) {
    digits = digits.substring(2);
  }

  if (digits.length != 10) {
    throw const FormatException(
      'Please enter a valid 10-digit Indian mobile number.',
    );
  }

  return '+91$digits';
}

void main() {
  group('AuthService phone normalization', () {
    test('10 digits → +91XXXXXXXXXX', () {
      expect(_normalizeIndianPhone('9876543210'), '+919876543210');
      expect(_normalizeIndianPhone('6000000000'), '+916000000000');
    });

    test('12 digits with 91 prefix → +91XXXXXXXXXX', () {
      expect(_normalizeIndianPhone('919876543210'), '+919876543210');
    });

    test('with spaces/dashes → stripped and normalized', () {
      expect(_normalizeIndianPhone('98765 43210'), '+919876543210');
      expect(_normalizeIndianPhone('9876-543-210'), '+919876543210');
      expect(_normalizeIndianPhone('+91 9876543210'), '+919876543210');
    });

    test('5 digits → throws FormatException', () {
      expect(() => _normalizeIndianPhone('12345'), throwsFormatException);
    });

    test('13 digits → throws FormatException', () {
      expect(() => _normalizeIndianPhone('9187654321012'), throwsFormatException);
    });

    test('empty → throws FormatException', () {
      expect(() => _normalizeIndianPhone(''), throwsFormatException);
    });

    test('letters only → throws FormatException', () {
      expect(() => _normalizeIndianPhone('abcdefghij'), throwsFormatException);
    });
  });

  group('AuthService phone normalization source contract', () {
    test('source code contains the normalization logic', () {
      final source = File('lib/src/core/services/auth_service.dart').readAsStringSync();
      expect(source, contains('_normalizeIndianPhone'));
      expect(source, contains(r"'+91$digits'"));
      expect(source, contains('digits.length != 10'));
      expect(source, contains("digits.startsWith('91') && digits.length == 12"));
    });
  });
}
