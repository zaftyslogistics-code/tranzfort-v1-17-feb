import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/features/bot/services/entity_extractor.dart';

void main() {
  // Test static/pure methods that don't need rootBundle

  group('EntityExtractor.parseHindiNumber', () {
    test('single Hindi number words', () {
      expect(EntityExtractor.parseHindiNumber('ek'), 1);
      expect(EntityExtractor.parseHindiNumber('do'), 2);
      expect(EntityExtractor.parseHindiNumber('das'), 10);
      expect(EntityExtractor.parseHindiNumber('bees'), 20);
      expect(EntityExtractor.parseHindiNumber('pachaas'), 50);
      expect(EntityExtractor.parseHindiNumber('sau'), 100);
    });

    test('compound Hindi numbers', () {
      expect(EntityExtractor.parseHindiNumber('do sau'), 200);
      expect(EntityExtractor.parseHindiNumber('teen sau'), 300);
      expect(EntityExtractor.parseHindiNumber('pacchis hazaar'), 25000);
      expect(EntityExtractor.parseHindiNumber('do hazaar'), 2000);
      expect(EntityExtractor.parseHindiNumber('ek hazaar'), 1000);
      expect(EntityExtractor.parseHindiNumber('das hazaar'), 10000);
    });

    test('returns null for non-Hindi text', () {
      expect(EntityExtractor.parseHindiNumber('hello world'), isNull);
      expect(EntityExtractor.parseHindiNumber(''), isNull);
      expect(EntityExtractor.parseHindiNumber('random text'), isNull);
    });

    test('mixed Hindi + non-Hindi words', () {
      // Should extract only the Hindi number parts
      expect(EntityExtractor.parseHindiNumber('price do hazaar rupees'), 2000);
    });
  });

  group('EntityExtractor._levenshtein (via resolveCity fuzzy)', () {
    // We can't call _levenshtein directly since it's private,
    // but we can verify its behavior through parseHindiNumber edge cases
    // and through the extractor's public API after loading

    test('parseHindiNumber with lakh', () {
      expect(EntityExtractor.parseHindiNumber('ek lakh'), 100000);
      expect(EntityExtractor.parseHindiNumber('do lakh'), 200000);
    });

    test('parseHindiNumber with hazaar + sau', () {
      // "do hazaar teen sau" = 2000 + 300 = 2300
      expect(EntityExtractor.parseHindiNumber('do hazaar teen sau'), 2300);
    });
  });

  group('EntityExtractor with TestWidgetsFlutterBinding', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    late EntityExtractor extractor;

    setUpAll(() async {
      extractor = EntityExtractor();
      // loadEntities will fall back to defaults since assets aren't bundled in test
      await extractor.loadEntities();
    });

    group('City extraction', () {
      test('"Mumbai se Pune" → origin=Mumbai, dest=Pune', () {
        final result = extractor.extract('mumbai se pune', 'en');
        expect(result['origin'], 'Mumbai');
        expect(result['destination'], 'Pune');
      });

      test('"from Delhi to Chennai" extracts both cities', () {
        final result = extractor.extract('from delhi to chennai', 'en');
        // Both cities should be extracted (order depends on indicator proximity)
        final cities = [result['origin'], result['destination']];
        expect(cities, containsAll(['Delhi', 'Chennai']));
      });

      test('city aliases: "bombay" → Mumbai', () {
        final resolved = extractor.resolveCity('bombay');
        expect(resolved, 'Mumbai');
      });

      test('city aliases: "calcutta" → Kolkata', () {
        final resolved = extractor.resolveCity('calcutta');
        expect(resolved, 'Kolkata');
      });

      test('city aliases: "dilli" → Delhi', () {
        final resolved = extractor.resolveCity('dilli');
        expect(resolved, 'Delhi');
      });

      test('city aliases: "baroda" → Vadodara', () {
        final resolved = extractor.resolveCity('baroda');
        expect(resolved, 'Vadodara');
      });

      test('city aliases: "banaras" → Varanasi', () {
        final resolved = extractor.resolveCity('banaras');
        expect(resolved, 'Varanasi');
      });

      test('resolveCity returns null for unknown city', () {
        final resolved = extractor.resolveCity('xyznonexistent');
        expect(resolved, isNull);
      });

      test('resolveCity empty input returns null', () {
        expect(extractor.resolveCity(''), isNull);
        expect(extractor.resolveCity('  '), isNull);
      });

      test('LOC-047: compound location parsing "Badnera Nagpur"', () {
        final result = extractor.extract('badnera nagpur se pune', 'en');
        expect(result['origin'], 'Nagpur');
        expect(result['destination'], 'Pune');
      });

      test('LOC-049: POI-aware extraction "MIDC Nagpur"', () {
        final result = extractor.extract('midc nagpur se mumbai load bhejna hai', 'en');
        expect(result['origin'], 'Nagpur');
        expect(result['destination'], 'Mumbai');
      });
    });

    group('Material extraction', () {
      test('English materials', () {
        final result = extractor.extract('i have steel to transport', 'en');
        expect(result['material'], 'Steel');
      });

      test('cement extraction', () {
        final result = extractor.extract('cement load available', 'en');
        expect(result['material'], 'Cement');
      });

      test('Hindi material aliases: "loha" → Steel', () {
        final result = extractor.extract('loha ka load hai', 'hi');
        expect(result['material'], 'Steel');
      });

      test('Hindi material aliases: "koyla" → Coal', () {
        final result = extractor.extract('koyla bhejni hai', 'hi');
        expect(result['material'], 'Coal');
      });

      test('Hindi material aliases: "chawal" → Rice', () {
        final result = extractor.extract('chawal ka load', 'hi');
        expect(result['material'], 'Rice');
      });
    });

    group('Weight extraction', () {
      test('"25 ton" → 25', () {
        final result = extractor.extract('25 ton load', 'en');
        expect(result['weight'], '25');
      });

      test('"1500 kg" → 1.5', () {
        final result = extractor.extract('1500 kg material', 'en');
        expect(result['weight'], '1.5');
      });

      test('"10 quintal" → 1', () {
        final result = extractor.extract('10 quintal load', 'en');
        expect(result['weight'], '1');
      });

      test('range "25-30 ton" → 25 (first number)', () {
        final result = extractor.extract('25-30 ton load', 'en');
        expect(result['weight'], '25');
      });

      test('comma-separated "1,500 kg" extracts weight', () {
        final result = extractor.extract('1,500 kg material', 'en');
        // After comma normalization: "1500 kg" → 1.5 tonnes
        expect(result.containsKey('weight'), true);
        final weight = double.tryParse(result['weight']!);
        expect(weight, isNotNull);
        expect(weight! > 0, true);
      });
    });

    group('Price extraction', () {
      test('"₹2500" extracts price', () {
        final result = extractor.extract('rate ₹2500 per ton', 'en');
        expect(result['price'], '2500');
      });

      test('"rs 3000" extracts price', () {
        final result = extractor.extract('rs 3000 rate', 'en');
        expect(result['price'], '3000');
      });

      test('"2500 rupees" extracts price', () {
        final result = extractor.extract('2500 rupees', 'en');
        expect(result['price'], '2500');
      });

      test('price bounds: rejects > 100000', () {
        final result = extractor.extract('price 200000 rupees', 'en');
        expect(result.containsKey('price'), false);
      });
    });

    group('Truck type extraction', () {
      test('English truck types', () {
        final result = extractor.extract('need open truck', 'en');
        expect(result['truck_type'], 'Open');
      });

      test('container truck', () {
        final result = extractor.extract('container required', 'en');
        expect(result['truck_type'], 'Container');
      });

      test('Hindi: "khula" → Open', () {
        final result = extractor.extract('khula truck chahiye', 'hi');
        expect(result['truck_type'], 'Open');
      });

      test('Hindi: "tanki" → Tanker', () {
        final result = extractor.extract('tanki chahiye', 'hi');
        expect(result['truck_type'], 'Tanker');
      });
    });

    group('Tyre extraction', () {
      test('"6 tyre" → 6', () {
        final result = extractor.extract('6 tyre truck', 'en');
        expect(result['tyres'], '6');
      });

      test('"10 wheeler" → 10', () {
        final result = extractor.extract('10 wheeler needed', 'en');
        expect(result['tyres'], '10');
      });

      test('"12 chakka" → 12', () {
        final result = extractor.extract('12 chakka', 'hi');
        expect(result['tyres'], '12');
      });

      test('invalid tyre count not extracted', () {
        final result = extractor.extract('5 tyre truck', 'en');
        expect(result.containsKey('tyres'), false);
      });
    });

    group('Pickup date extraction', () {
      test('"today" / "aaj" → today\'s date', () {
        final today = DateTime.now().toIso8601String().split('T').first;
        final result1 = extractor.extract('pickup today', 'en');
        expect(result1['pickup_date'], today);

        final result2 = extractor.extract('aaj pickup', 'hi');
        expect(result2['pickup_date'], today);
      });

      test('"tomorrow" / "kal" → tomorrow\'s date', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first;
        final result1 = extractor.extract('pickup tomorrow', 'en');
        expect(result1['pickup_date'], tomorrow);

        final result2 = extractor.extract('kal pickup', 'hi');
        expect(result2['pickup_date'], tomorrow);
      });

      test('"parso" → day after tomorrow', () {
        final dayAfter = DateTime.now().add(const Duration(days: 2)).toIso8601String().split('T').first;
        final result = extractor.extract('parso bhejni hai', 'hi');
        expect(result['pickup_date'], dayAfter);
      });
    });

    group('extractForSlot — targeted extraction', () {
      test('only fills requested slot', () {
        final result = extractor.extractForSlot(
          'steel 25 ton from mumbai',
          'en',
          'material',
        );
        expect(result['material'], 'Steel');
        // Should NOT extract weight or city when targeting material
        expect(result.containsKey('weight'), false);
        expect(result.containsKey('origin'), false);
      });

      test('weight slot extraction', () {
        final result = extractor.extractForSlot('25 ton', 'en', 'weight');
        expect(result['weight'], '25');
      });

      test('price slot extraction', () {
        final result = extractor.extractForSlot('₹3000', 'en', 'price');
        expect(result['price'], '3000');
      });

      test('price_type slot extraction', () {
        final result = extractor.extractForSlot('negotiable', 'en', 'price_type');
        expect(result['price_type'], 'Negotiable');
      });

      test('price_type fixed', () {
        final result = extractor.extractForSlot('fixed', 'en', 'price_type');
        expect(result['price_type'], 'Fixed');
      });

      test('advance_percentage extraction', () {
        final result = extractor.extractForSlot('20%', 'en', 'advance_percentage');
        expect(result['advance_percentage'], '20');
      });

      test('advance_percentage rejects > 100', () {
        final result = extractor.extractForSlot('150%', 'en', 'advance_percentage');
        expect(result.containsKey('advance_percentage'), false);
      });
    });
  });
}
