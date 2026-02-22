import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('valid emails pass', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('user.name@domain.co.in'), isNull);
      expect(Validators.email('a@b.cd'), isNull);
    });

    test('invalid emails rejected', () {
      expect(Validators.email('notanemail'), isNotNull);
      expect(Validators.email('missing@'), isNotNull);
      expect(Validators.email('@nodomain.com'), isNotNull);
      expect(Validators.email('spaces in@email.com'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.email(null), isNotNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
    });
  });

  group('Validators.password', () {
    test('valid passwords pass', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('abcdefgh'), isNull);
      expect(Validators.password('Tabish%%Khan721'), isNull);
    });

    test('too short rejected', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('ab'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.password(null), isNotNull);
      expect(Validators.password(''), isNotNull);
    });
  });

  group('Validators.fullName', () {
    test('valid names pass', () {
      expect(Validators.fullName('Ab'), isNull);
      expect(Validators.fullName('Tabish Khan'), isNull);
    });

    test('too short rejected', () {
      expect(Validators.fullName('A'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.fullName(null), isNotNull);
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('   '), isNotNull);
    });
  });

  group('Validators.indianMobile', () {
    test('valid 10-digit numbers starting 6-9 pass', () {
      expect(Validators.indianMobile('9876543210'), isNull);
      expect(Validators.indianMobile('6000000000'), isNull);
      expect(Validators.indianMobile('7123456789'), isNull);
      expect(Validators.indianMobile('8999999999'), isNull);
    });

    test('invalid numbers rejected', () {
      expect(Validators.indianMobile('12345'), isNotNull);
      expect(Validators.indianMobile('0123456789'), isNotNull);
      expect(Validators.indianMobile('5123456789'), isNotNull);
      expect(Validators.indianMobile('abcdefghij'), isNotNull);
      expect(Validators.indianMobile('98765432101'), isNotNull); // 11 digits
    });

    test('null/empty returns error', () {
      expect(Validators.indianMobile(null), isNotNull);
      expect(Validators.indianMobile(''), isNotNull);
    });
  });

  group('Validators.pan', () {
    test('valid PAN passes', () {
      expect(Validators.pan('ABCDE1234F'), isNull);
      expect(Validators.pan('abcde1234f'), isNull); // lowercase accepted (toUpperCase inside)
    });

    test('invalid PAN rejected', () {
      expect(Validators.pan('ABCDE123F'), isNotNull); // too short
      expect(Validators.pan('12345ABCDE'), isNotNull);
      expect(Validators.pan('ABCDE12345'), isNotNull); // last char is digit
    });

    test('null/empty returns error', () {
      expect(Validators.pan(null), isNotNull);
      expect(Validators.pan(''), isNotNull);
    });
  });

  group('Validators.aadhaarLast4', () {
    test('exactly 4 digits passes', () {
      expect(Validators.aadhaarLast4('1234'), isNull);
      expect(Validators.aadhaarLast4('0000'), isNull);
    });

    test('wrong length or letters rejected', () {
      expect(Validators.aadhaarLast4('123'), isNotNull);
      expect(Validators.aadhaarLast4('12345'), isNotNull);
      expect(Validators.aadhaarLast4('abcd'), isNotNull);
      expect(Validators.aadhaarLast4('12a4'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.aadhaarLast4(null), isNotNull);
      expect(Validators.aadhaarLast4(''), isNotNull);
    });
  });

  group('Validators.ifsc', () {
    test('valid IFSC passes', () {
      expect(Validators.ifsc('SBIN0001234'), isNull);
      expect(Validators.ifsc('HDFC0BRANCH'), isNull);
      expect(Validators.ifsc('sbin0001234'), isNull); // lowercase accepted
    });

    test('invalid IFSC rejected', () {
      expect(Validators.ifsc('SBIN001234'), isNotNull); // 5th char not 0
      expect(Validators.ifsc('SBI0001234'), isNotNull); // only 3 letters
      expect(Validators.ifsc('12340001234'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.ifsc(null), isNotNull);
      expect(Validators.ifsc(''), isNotNull);
    });
  });

  group('Validators.vehicleNumber', () {
    test('valid Indian vehicle numbers pass', () {
      expect(Validators.vehicleNumber('MH12AB1234'), isNull);
      expect(Validators.vehicleNumber('DL1C1234'), isNull);
      expect(Validators.vehicleNumber('KA 01 AB 1234'), isNull);
    });

    test('invalid vehicle numbers rejected', () {
      expect(Validators.vehicleNumber('123'), isNotNull);
      expect(Validators.vehicleNumber('INVALID'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.vehicleNumber(null), isNotNull);
      expect(Validators.vehicleNumber(''), isNotNull);
    });
  });

  group('Validators.required', () {
    test('non-empty passes', () {
      expect(Validators.required('hello'), isNull);
      expect(Validators.required('a'), isNull);
    });

    test('null/empty/whitespace fails', () {
      expect(Validators.required(null), isNotNull);
      expect(Validators.required(''), isNotNull);
      expect(Validators.required('   '), isNotNull);
    });
  });

  group('Validators.positiveNumber', () {
    test('positive numbers pass', () {
      expect(Validators.positiveNumber('1'), isNull);
      expect(Validators.positiveNumber('25.5'), isNull);
      expect(Validators.positiveNumber('0.001'), isNull);
    });

    test('zero, negative, non-numeric rejected', () {
      expect(Validators.positiveNumber('0'), isNotNull);
      expect(Validators.positiveNumber('-5'), isNotNull);
      expect(Validators.positiveNumber('abc'), isNotNull);
    });

    test('null/empty returns error', () {
      expect(Validators.positiveNumber(null), isNotNull);
      expect(Validators.positiveNumber(''), isNotNull);
    });
  });

  group('Validators.formatIndianMobile', () {
    test('10 digits → +91XXXXXXXXXX', () {
      expect(Validators.formatIndianMobile('9876543210'), '+919876543210');
    });

    test('12 digits with 91 prefix → +91XXXXXXXXXX', () {
      expect(Validators.formatIndianMobile('919876543210'), '+919876543210');
    });

    test('already formatted returned as-is', () {
      expect(Validators.formatIndianMobile('+919876543210'), '+919876543210');
    });
  });

  group('Validators.displayIndianMobile', () {
    test('formats correctly', () {
      expect(Validators.displayIndianMobile('+919876543210'), '+91 98765 43210');
      expect(Validators.displayIndianMobile('9876543210'), '+91 98765 43210');
      expect(Validators.displayIndianMobile('919876543210'), '+91 98765 43210');
    });

    test('null/empty returns dash', () {
      expect(Validators.displayIndianMobile(null), '-');
      expect(Validators.displayIndianMobile(''), '-');
    });
  });

  group('Validators.maskAccountNumber', () {
    test('masks all but last 4', () {
      expect(Validators.maskAccountNumber('1234567890'), '****7890');
      expect(Validators.maskAccountNumber('12345678901234'), '****1234');
    });

    test('short numbers returned as-is', () {
      expect(Validators.maskAccountNumber('1234'), '1234');
      expect(Validators.maskAccountNumber('12'), '12');
    });
  });
}
