import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/utils/result.dart';

void main() {
  group('Success', () {
    test('creates with data', () {
      const result = Success(42);
      expect(result.data, 42);
    });

    test('isSuccess returns true', () {
      const result = Success('hello');
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
    });

    test('dataOrNull returns data', () {
      const Result<int> result = Success(99);
      expect(result.dataOrNull, 99);
    });

    test('errorMessage returns null', () {
      const Result<int> result = Success(1);
      expect(result.errorMessage, isNull);
    });

    test('equality works', () {
      expect(const Success(1), equals(const Success(1)));
      expect(const Success(1), isNot(equals(const Success(2))));
    });

    test('toString includes data', () {
      expect(const Success(42).toString(), 'Success(42)');
    });
  });

  group('Failure', () {
    test('creates with message and error', () {
      const result = Failure<int>('not found', error: AppError.notFound);
      expect(result.message, 'not found');
      expect(result.error, AppError.notFound);
    });

    test('isFailure returns true', () {
      const result = Failure<int>('err');
      expect(result.isFailure, true);
      expect(result.isSuccess, false);
    });

    test('dataOrNull returns null', () {
      const Result<int> result = Failure('err');
      expect(result.dataOrNull, isNull);
    });

    test('errorMessage returns message', () {
      const Result<int> result = Failure('bad request');
      expect(result.errorMessage, 'bad request');
    });

    test('default error is unknown', () {
      const result = Failure<int>('err');
      expect(result.error, AppError.unknown);
    });

    test('equality works', () {
      expect(
        const Failure<int>('err', error: AppError.server),
        equals(const Failure<int>('err', error: AppError.server)),
      );
      expect(
        const Failure<int>('err', error: AppError.server),
        isNot(equals(const Failure<int>('err', error: AppError.network))),
      );
    });

    test('toString includes error and message', () {
      expect(
        const Failure<int>('oops', error: AppError.auth).toString(),
        'Failure(AppError.auth: oops)',
      );
    });
  });

  group('when()', () {
    test('calls onSuccess for Success', () {
      const Result<int> result = Success(10);
      final value = result.when(
        onSuccess: (data) => 'got $data',
        onFailure: (msg, err) => 'fail',
      );
      expect(value, 'got 10');
    });

    test('calls onFailure for Failure', () {
      const Result<int> result = Failure('err', error: AppError.network);
      final value = result.when(
        onSuccess: (data) => 'ok',
        onFailure: (msg, err) => 'fail: $msg ($err)',
      );
      expect(value, 'fail: err (AppError.network)');
    });
  });

  group('AppError', () {
    test('all values exist', () {
      expect(AppError.values.length, 6);
      expect(AppError.values, contains(AppError.network));
      expect(AppError.values, contains(AppError.auth));
      expect(AppError.values, contains(AppError.notFound));
      expect(AppError.values, contains(AppError.businessRule));
      expect(AppError.values, contains(AppError.server));
      expect(AppError.values, contains(AppError.unknown));
    });
  });
}
