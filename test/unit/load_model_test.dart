import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/models/load_model.dart';

void main() {
  final fullJson = {
    'id': 'load-123',
    'supplier_id': 'sup-456',
    'origin_city': 'Mumbai',
    'origin_state': 'Maharashtra',
    'dest_city': 'Pune',
    'dest_state': 'Maharashtra',
    'material': 'Steel',
    'weight_tonnes': 25.0,
    'required_truck_type': 'Open',
    'required_tyres': [6, 10],
    'price': 3500.0,
    'price_type': 'negotiable',
    'advance_percentage': 20,
    'pickup_date': '2026-03-01',
    'status': 'active',
    'is_super_load': false,
    'super_status': null,
    'assigned_trucker_id': null,
    'assigned_truck_id': null,
    'pod_photo_url': null,
    'lr_photo_url': null,
    'trip_stage': null,
    'views_count': 5,
    'responses_count': 2,
    'created_at': '2026-02-20T10:00:00Z',
    'updated_at': '2026-02-20T12:00:00Z',
    'expires_at': null,
    'completed_at': null,
  };

  group('LoadModel.fromJson', () {
    test('all fields parse correctly', () {
      final model = LoadModel.fromJson(fullJson);
      expect(model.id, 'load-123');
      expect(model.supplierId, 'sup-456');
      expect(model.originCity, 'Mumbai');
      expect(model.originState, 'Maharashtra');
      expect(model.destCity, 'Pune');
      expect(model.destState, 'Maharashtra');
      expect(model.material, 'Steel');
      expect(model.weightTonnes, 25.0);
      expect(model.requiredTruckType, 'Open');
      expect(model.requiredTyres, [6, 10]);
      expect(model.price, 3500.0);
      expect(model.priceType, 'negotiable');
      expect(model.advancePercentage, 20);
      expect(model.pickupDate, DateTime.parse('2026-03-01'));
      expect(model.status, 'active');
      expect(model.isSuperLoad, false);
      expect(model.viewsCount, 5);
      expect(model.responsesCount, 2);
      expect(model.createdAt, isNotNull);
      expect(model.updatedAt, isNotNull);
    });

    test('nullable fields default correctly', () {
      final minJson = {
        'supplier_id': 'sup-1',
        'origin_city': 'Delhi',
        'origin_state': 'Delhi',
        'dest_city': 'Jaipur',
        'dest_state': 'Rajasthan',
        'material': 'Cement',
        'weight_tonnes': 10,
        'price': 2000,
        'pickup_date': '2026-04-01',
      };
      final model = LoadModel.fromJson(minJson);
      expect(model.id, isNull);
      expect(model.requiredTruckType, isNull);
      expect(model.requiredTyres, isNull);
      expect(model.priceType, 'negotiable');
      expect(model.advancePercentage, isNull);
      expect(model.status, 'active');
      expect(model.isSuperLoad, false);
      expect(model.superStatus, isNull);
      expect(model.assignedTruckerId, isNull);
      expect(model.podPhotoUrl, isNull);
      expect(model.lrPhotoUrl, isNull);
      expect(model.tripStage, isNull);
      expect(model.viewsCount, 0);
      expect(model.responsesCount, 0);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
      expect(model.expiresAt, isNull);
      expect(model.completedAt, isNull);
    });
  });

  group('LoadModel.toJson', () {
    test('round-trip consistency', () {
      final model = LoadModel.fromJson(fullJson);
      final json = model.toJson();
      expect(json['supplier_id'], 'sup-456');
      expect(json['origin_city'], 'Mumbai');
      expect(json['dest_city'], 'Pune');
      expect(json['material'], 'Steel');
      expect(json['weight_tonnes'], 25.0);
      expect(json['price'], 3500.0);
      expect(json['pickup_date'], '2026-03-01');
      expect(json['status'], 'active');
      expect(json['is_super_load'], false);
    });

    test('id excluded when null', () {
      final model = LoadModel(
        supplierId: 'sup-1',
        originCity: 'A',
        originState: 'B',
        destCity: 'C',
        destState: 'D',
        material: 'E',
        weightTonnes: 1,
        price: 100,
        pickupDate: DateTime(2026, 1, 1),
      );
      final json = model.toJson();
      expect(json.containsKey('id'), false);
    });
  });

  group('LoadModel.route', () {
    test('returns "Origin → Dest"', () {
      final model = LoadModel.fromJson(fullJson);
      expect(model.route, 'Mumbai → Pune');
    });
  });
}
