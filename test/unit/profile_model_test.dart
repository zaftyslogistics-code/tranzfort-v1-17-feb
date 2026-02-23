import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/models/profile_model.dart';

void main() {
  final fullJson = {
    'id': 'user-001',
    'full_name': 'Rajesh Kumar',
    'mobile': '+919876543210',
    'email': 'rajesh@example.com',
    'current_role': 'supplier',
    'avatar_url': 'https://example.com/avatar.jpg',
    'verification_status': 'verified',
    'is_banned': false,
    'ban_reason': null,
    'preferred_language': 'hi',
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-02-01T00:00:00Z',
  };

  group('ProfileModel.fromJson', () {
    test('all fields parse correctly', () {
      final model = ProfileModel.fromJson(fullJson);
      expect(model.id, 'user-001');
      expect(model.fullName, 'Rajesh Kumar');
      expect(model.mobile, '+919876543210');
      expect(model.email, 'rajesh@example.com');
      expect(model.currentRole, 'supplier');
      expect(model.avatarUrl, 'https://example.com/avatar.jpg');
      expect(model.verificationStatus, 'verified');
      expect(model.isBanned, false);
      expect(model.banReason, isNull);
      expect(model.preferredLanguage, 'hi');
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
    });

    test('nullable fields default correctly', () {
      final minJson = {'id': 'user-2'};
      final model = ProfileModel.fromJson(minJson);
      expect(model.fullName, '');
      expect(model.mobile, '');
      expect(model.email, '');
      expect(model.currentRole, isNull);
      expect(model.avatarUrl, isNull);
      expect(model.verificationStatus, 'unverified');
      expect(model.isBanned, false);
      expect(model.banReason, isNull);
      expect(model.preferredLanguage, isNull);
    });
  });

  group('ProfileModel.toJson', () {
    test('round-trip key fields', () {
      final model = ProfileModel.fromJson(fullJson);
      final json = model.toJson();
      expect(json['id'], 'user-001');
      expect(json['full_name'], 'Rajesh Kumar');
      expect(json['mobile'], '+919876543210');
      expect(json['verification_status'], 'verified');
    });

    test('excludes null optional fields', () {
      final model = ProfileModel(
        id: 'u1',
        fullName: 'Test',
        mobile: '1234',
        email: 'test@test.com',
      );
      final json = model.toJson();
      expect(json.containsKey('current_role'), false);
      expect(json.containsKey('avatar_url'), false);
      expect(json.containsKey('preferred_language'), false);
    });
  });

  group('role helpers', () {
    test('isSupplier', () {
      final model = ProfileModel.fromJson(fullJson);
      expect(model.isSupplier, true);
      expect(model.isTrucker, false);
    });

    test('isTrucker', () {
      final model = ProfileModel.fromJson({...fullJson, 'current_role': 'trucker'});
      expect(model.isTrucker, true);
      expect(model.isSupplier, false);
    });

    test('isVerified', () {
      final model = ProfileModel.fromJson(fullJson);
      expect(model.isVerified, true);
    });

    test('unverified by default', () {
      final model = ProfileModel.fromJson({'id': 'u1'});
      expect(model.isVerified, false);
    });
  });

  group('copyWith', () {
    test('changes specified fields only', () {
      final original = ProfileModel.fromJson(fullJson);
      final updated = original.copyWith(fullName: 'New Name', isBanned: true);
      expect(updated.fullName, 'New Name');
      expect(updated.isBanned, true);
      expect(updated.id, original.id);
      expect(updated.mobile, original.mobile);
      expect(updated.email, original.email);
      expect(updated.currentRole, original.currentRole);
    });
  });

  group('equality', () {
    test('same id equals', () {
      final a = ProfileModel.fromJson(fullJson);
      final b = ProfileModel.fromJson({...fullJson, 'full_name': 'Different'});
      expect(a, equals(b));
    });

    test('different id not equal', () {
      final a = ProfileModel.fromJson(fullJson);
      final b = ProfileModel.fromJson({...fullJson, 'id': 'user-999'});
      expect(a, isNot(equals(b)));
    });
  });
}
