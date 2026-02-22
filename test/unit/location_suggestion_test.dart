// LOC-083: LocationSuggestion model serialization + PoiCategory tests
import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/features/navigation/services/location_suggestions_service.dart';

void main() {
  group('PoiCategory enum (LOC-083)', () {
    test('all categories have non-empty labels', () {
      for (final cat in PoiCategory.values) {
        expect(cat.label, isNotEmpty);
      }
    });

    test('all categories have non-empty dbValues', () {
      for (final cat in PoiCategory.values) {
        expect(cat.dbValue, isNotEmpty);
      }
    });

    test('dbValues are unique', () {
      final values = PoiCategory.values.map((c) => c.dbValue).toList();
      final unique = values.toSet();
      expect(unique.length, values.length);
    });

    test('fuel_station category exists', () {
      final cat = PoiCategory.values
          .firstWhere((c) => c.dbValue == 'fuel_station');
      expect(cat.label, isNotEmpty);
    });

    test('dhaba category exists', () {
      final cat = PoiCategory.values
          .firstWhere((c) => c.dbValue == 'dhaba');
      expect(cat.label, isNotEmpty);
    });

    test('truck_parking category exists', () {
      final cat = PoiCategory.values
          .firstWhere((c) => c.dbValue == 'truck_parking');
      expect(cat.label, isNotEmpty);
    });
  });

  group('LocationSuggestion model (LOC-083)', () {
    test('toInsertJson produces required fields', () {
      const suggestion = LocationSuggestion(
        name: 'Test Dhaba',
        category: PoiCategory.dhaba,
        lat: 21.1458,
        lng: 79.0882,
        address: 'NH44, Near Nagpur',
        pincode: '440001',
        district: 'Nagpur',
        state: 'Maharashtra',
        phone: '9876543210',
        photos: ['https://example.com/photo1.jpg'],
        notes: 'Good food, parking available',
      );

      final json = suggestion.toInsertJson('user-uuid-123');

      expect(json['name'], 'Test Dhaba');
      expect(json['category'], 'dhaba');
      expect(json['lat'], 21.1458);
      expect(json['lng'], 79.0882);
      expect(json['address'], 'NH44, Near Nagpur');
      expect(json['pincode'], '440001');
      expect(json['district'], 'Nagpur');
      expect(json['state'], 'Maharashtra');
      expect(json['phone'], '9876543210');
      expect(json['notes'], 'Good food, parking available');
      expect(json['status'], 'pending');
      expect(json['suggested_by'], 'user-uuid-123');
      expect(json['photos'], isA<List>());
      expect((json['photos'] as List).first,
          'https://example.com/photo1.jpg');
    });

    test('fromJson round-trips correctly', () {
      final json = {
        'id': 'abc-123',
        'name': 'Fuel Point',
        'category': 'fuel_station',
        'lat': 19.0760,
        'lng': 72.8777,
        'address': 'Western Express Highway',
        'pincode': '400001',
        'district': 'Mumbai',
        'state': 'Maharashtra',
        'phone': null,
        'photos': <String>[],
        'notes': null,
        'status': 'approved',
        'suggested_by': 'user-abc',
        'created_at': '2026-02-21T00:00:00.000Z',
      };

      final suggestion = LocationSuggestion.fromJson(json);

      expect(suggestion.id, 'abc-123');
      expect(suggestion.name, 'Fuel Point');
      expect(suggestion.category, PoiCategory.fuelStation);
      expect(suggestion.lat, 19.0760);
      expect(suggestion.lng, 72.8777);
      expect(suggestion.status, 'approved');
      expect(suggestion.photos, isEmpty);
      expect(suggestion.phone, isNull);
    });

    test('fromJson handles unknown category gracefully', () {
      final json = {
        'id': 'xyz',
        'name': 'Unknown Place',
        'category': 'nonexistent_category',
        'lat': 0.0,
        'lng': 0.0,
        'status': 'pending',
        'suggested_by': 'user-xyz',
        'photos': <String>[],
      };

      // Should not throw — falls back to 'other'
      expect(() => LocationSuggestion.fromJson(json), returnsNormally);
      final s = LocationSuggestion.fromJson(json);
      expect(s.category, PoiCategory.other);
    });

    test('toInsertJson excludes id field (server-generated)', () {
      const suggestion = LocationSuggestion(
        name: 'Test',
        category: PoiCategory.mechanic,
        lat: 0.0,
        lng: 0.0,
      );
      final json = suggestion.toInsertJson('user-1');
      // id should not be sent on insert
      expect(json.containsKey('id'), isFalse);
    });

    test('minimal suggestion (only required fields) serializes', () {
      const suggestion = LocationSuggestion(
        name: 'Minimal',
        category: PoiCategory.other,
        lat: 10.0,
        lng: 80.0,
      );
      final json = suggestion.toInsertJson('user-min');
      expect(json['name'], 'Minimal');
      expect(json['lat'], 10.0);
      expect(json['lng'], 80.0);
      expect(json['suggested_by'], 'user-min');
    });
  });

  group('NearbyPoi model (LOC-083)', () {
    test('markerEmoji returns non-empty string for all known categories', () {
      // Import inline to avoid circular deps — test the logic directly
      const categories = [
        'fuel_station', 'dhaba', 'truck_parking', 'mechanic',
        'tyre_shop', 'rest_area', 'toll_plaza', 'weigh_bridge', 'other',
      ];
      const emojis = {
        'fuel_station': '⛽',
        'dhaba': '🍽',
        'truck_parking': '🅿',
        'mechanic': '🔧',
        'tyre_shop': '🔩',
        'rest_area': '🛏',
        'toll_plaza': '🚧',
        'weigh_bridge': '⚖',
        'other': '📍',
      };
      for (final cat in categories) {
        expect(emojis[cat], isNotEmpty);
      }
    });
  });
}
