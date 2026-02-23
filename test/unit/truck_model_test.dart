import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/models/truck_model.dart';

void main() {
  final fullJson = {
    'id': 'truck-001',
    'owner_id': 'user-123',
    'truck_number': 'MH12AB1234',
    'body_type': 'Open',
    'tyres': 10,
    'capacity_tonnes': 25.0,
    'rc_photo_url': 'https://example.com/rc.jpg',
    'status': 'verified',
    'rejection_reason': null,
    'verified_at': '2026-02-01T10:00:00Z',
    'created_at': '2026-01-15T08:00:00Z',
    'truck_model_id': 'model-abc',
  };

  group('TruckModel.fromJson', () {
    test('all fields parse correctly', () {
      final model = TruckModel.fromJson(fullJson);
      expect(model.id, 'truck-001');
      expect(model.ownerId, 'user-123');
      expect(model.truckNumber, 'MH12AB1234');
      expect(model.bodyType, 'Open');
      expect(model.tyres, 10);
      expect(model.capacityTonnes, 25.0);
      expect(model.rcPhotoUrl, 'https://example.com/rc.jpg');
      expect(model.status, 'verified');
      expect(model.rejectionReason, isNull);
      expect(model.verifiedAt, isNotNull);
      expect(model.createdAt, isNotNull);
      expect(model.truckModelId, 'model-abc');
    });

    test('nullable fields default correctly', () {
      final minJson = {
        'owner_id': 'user-1',
        'truck_number': 'KA01XY9999',
        'body_type': 'Container',
        'tyres': 6,
        'capacity_tonnes': 10,
      };
      final model = TruckModel.fromJson(minJson);
      expect(model.id, isNull);
      expect(model.rcPhotoUrl, isNull);
      expect(model.status, 'pending');
      expect(model.rejectionReason, isNull);
      expect(model.verifiedAt, isNull);
      expect(model.createdAt, isNull);
      expect(model.truckModelId, isNull);
    });
  });

  group('TruckModel.toJson', () {
    test('includes required fields', () {
      final model = TruckModel.fromJson(fullJson);
      final json = model.toJson();
      expect(json['owner_id'], 'user-123');
      expect(json['truck_number'], 'MH12AB1234');
      expect(json['body_type'], 'Open');
      expect(json['tyres'], 10);
      expect(json['capacity_tonnes'], 25.0);
    });

    test('excludes id when null', () {
      final model = TruckModel(
        ownerId: 'u1',
        truckNumber: 'XX00YY0000',
        bodyType: 'Flatbed',
        tyres: 6,
        capacityTonnes: 12,
      );
      final json = model.toJson();
      expect(json.containsKey('id'), false);
    });

    test('includes truck_model_id when present', () {
      final model = TruckModel.fromJson(fullJson);
      final json = model.toJson();
      expect(json['truck_model_id'], 'model-abc');
    });
  });

  group('status helpers', () {
    test('isVerified', () {
      final model = TruckModel.fromJson(fullJson);
      expect(model.isVerified, true);
      expect(model.isPending, false);
      expect(model.isRejected, false);
    });

    test('isPending', () {
      final model = TruckModel.fromJson({...fullJson, 'status': 'pending'});
      expect(model.isPending, true);
      expect(model.isVerified, false);
    });

    test('isRejected', () {
      final model = TruckModel.fromJson({
        ...fullJson,
        'status': 'rejected',
        'rejection_reason': 'RC photo blurry',
      });
      expect(model.isRejected, true);
      expect(model.rejectionReason, 'RC photo blurry');
    });
  });
}
