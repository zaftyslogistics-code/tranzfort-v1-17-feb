class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
  static final _indianMobileRegex = RegExp(r'^[6-9]\d{9}$');
  static final _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final _aadhaarRegex = RegExp(r'^\d{4}$');
  static final _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final _vehicleRegex =
      RegExp(r'^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{4}$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    if (!_emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name is too short';
    return null;
  }

  static String? indianMobile(String? value) {
    if (value == null || value.trim().isEmpty) return 'Mobile number is required';
    final digits = value.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (!_indianMobileRegex.hasMatch(digits)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }
    return null;
  }

  static String? pan(String? value) {
    if (value == null || value.trim().isEmpty) return 'PAN is required';
    if (!_panRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid PAN (e.g., ABCDE1234F)';
    }
    return null;
  }

  static String? aadhaarLast4(String? value) {
    if (value == null || value.trim().isEmpty) return 'Aadhaar last 4 digits required';
    if (!_aadhaarRegex.hasMatch(value.trim())) {
      return 'Enter exactly 4 digits';
    }
    return null;
  }

  static String? ifsc(String? value) {
    if (value == null || value.trim().isEmpty) return 'IFSC code is required';
    if (!_ifscRegex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid IFSC (e.g., SBIN0001234)';
    }
    return null;
  }

  static String? vehicleNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vehicle number is required';
    final normalized = value.trim().toUpperCase();
    if (!_vehicleRegex.hasMatch(normalized)) {
      return 'Enter a valid vehicle number';
    }
    return null;
  }

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Value']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    final num = double.tryParse(value.trim());
    if (num == null || num <= 0) return 'Enter a valid positive number';
    return null;
  }

  static String formatIndianMobile(String mobile) {
    final digits = mobile.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 10) {
      return '+91$digits';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+$digits';
    }
    return mobile;
  }

  /// Display-friendly format: +91 98765 43210
  static String displayIndianMobile(String? mobile) {
    if (mobile == null || mobile.isEmpty) return '-';
    final digits = mobile.replaceAll(RegExp(r'[^\d]'), '');
    String tenDigits;
    if (digits.length == 12 && digits.startsWith('91')) {
      tenDigits = digits.substring(2);
    } else if (digits.length == 10) {
      tenDigits = digits;
    } else {
      return mobile;
    }
    return '+91 ${tenDigits.substring(0, 5)} ${tenDigits.substring(5)}';
  }

  static String maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return '****${accountNumber.substring(accountNumber.length - 4)}';
  }
}
