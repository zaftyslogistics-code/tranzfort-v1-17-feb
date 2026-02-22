// LOC-081: Navigation TTS milestone announcement logic tests
// Tests the pure logic for distance milestone text generation and
// rest suggestion timing — no Flutter engine or TTS plugin required.
import 'package:flutter_test/flutter_test.dart';

// ── Pure helper extracted from ActiveNavigationScreen for testability ─────────

const _distanceMilestones = [50.0, 25.0, 10.0, 5.0, 1.0];

String? milestoneText(double remainingKm, Set<double> announced) {
  for (final milestone in _distanceMilestones) {
    if (announced.contains(milestone)) continue;
    if (remainingKm <= milestone) {
      if (milestone >= 50) {
        return 'Manzil abhi ${milestone.round()} kilometer door hai';
      } else if (milestone >= 10) {
        return 'Manzil sirf ${milestone.round()} kilometer reh gayi';
      } else if (milestone >= 5) {
        return 'Manzil paanch kilometer door hai. Taiyaar rahein';
      } else {
        return 'Manzil ek kilometer door hai. Pahunchne wale hain';
      }
    }
  }
  return null;
}

bool shouldSuggestRest({
  required DateTime drivingStartTime,
  required bool alreadyGiven,
  double restAfterMin = 240.0,
}) {
  if (alreadyGiven) return false;
  final drivingMinutes =
      DateTime.now().difference(drivingStartTime).inMinutes.toDouble();
  return drivingMinutes >= restAfterMin;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Distance milestone TTS text (LOC-081)', () {
    test('50km milestone fires when remaining ≤ 50', () {
      final announced = <double>{};
      final text = milestoneText(49.5, announced);
      expect(text, contains('50 kilometer'));
    });

    test('25km milestone fires when remaining ≤ 25', () {
      final announced = <double>{50.0};
      final text = milestoneText(24.9, announced);
      expect(text, contains('25 kilometer'));
    });

    test('10km milestone fires when remaining ≤ 10', () {
      final announced = <double>{50.0, 25.0};
      final text = milestoneText(9.8, announced);
      expect(text, contains('10 kilometer'));
    });

    test('5km milestone fires when remaining ≤ 5', () {
      final announced = <double>{50.0, 25.0, 10.0};
      final text = milestoneText(4.9, announced);
      expect(text, contains('paanch kilometer'));
    });

    test('1km milestone fires when remaining ≤ 1', () {
      final announced = <double>{50.0, 25.0, 10.0, 5.0};
      final text = milestoneText(0.9, announced);
      expect(text, contains('ek kilometer'));
    });

    test('no milestone fires when remaining > 50', () {
      final announced = <double>{};
      final text = milestoneText(51.0, announced);
      expect(text, isNull);
    });

    test('already-announced milestone does not fire again', () {
      final announced = <double>{50.0, 25.0, 10.0, 5.0, 1.0};
      final text = milestoneText(0.5, announced);
      expect(text, isNull);
    });

    test('only one milestone fires per call (lowest unannounced)', () {
      // At 0.8km remaining, only 1km milestone should fire (not 5km or 10km)
      final announced = <double>{50.0, 25.0, 10.0, 5.0};
      final text = milestoneText(0.8, announced);
      expect(text, contains('ek kilometer'));
      expect(text, isNot(contains('paanch')));
    });

    test('milestone text is in Hindi', () {
      final announced = <double>{};
      final text = milestoneText(49.0, announced);
      expect(text, isNotNull);
      // Should contain Hindi words
      expect(text, contains('kilometer'));
      expect(text, contains('Manzil'));
    });

    test('exact boundary: remaining == milestone triggers', () {
      final announced = <double>{};
      final text = milestoneText(50.0, announced);
      expect(text, isNotNull);
    });

    test('just above boundary: remaining == 50.001 does not trigger 50km', () {
      final announced = <double>{};
      final text = milestoneText(50.001, announced);
      expect(text, isNull);
    });
  });

  group('Rest suggestion logic (LOC-081)', () {
    test('no rest suggestion before 4 hours', () {
      final start = DateTime.now().subtract(const Duration(hours: 3, minutes: 59));
      final suggest = shouldSuggestRest(
        drivingStartTime: start,
        alreadyGiven: false,
      );
      expect(suggest, isFalse);
    });

    test('rest suggestion fires at exactly 4 hours', () {
      final start = DateTime.now().subtract(const Duration(hours: 4, minutes: 1));
      final suggest = shouldSuggestRest(
        drivingStartTime: start,
        alreadyGiven: false,
      );
      expect(suggest, isTrue);
    });

    test('rest suggestion does not repeat if already given', () {
      final start = DateTime.now().subtract(const Duration(hours: 5));
      final suggest = shouldSuggestRest(
        drivingStartTime: start,
        alreadyGiven: true,
      );
      expect(suggest, isFalse);
    });

    test('custom threshold: 2 hours', () {
      final start = DateTime.now().subtract(const Duration(hours: 2, minutes: 5));
      final suggest = shouldSuggestRest(
        drivingStartTime: start,
        alreadyGiven: false,
        restAfterMin: 120.0,
      );
      expect(suggest, isTrue);
    });
  });

  group('Milestone sequence integrity', () {
    test('all 5 milestones fire in correct order for a full trip', () {
      final announced = <double>{};
      final distances = [60.0, 49.0, 24.0, 9.0, 4.0, 0.8];
      final fired = <String>[];

      for (final d in distances) {
        final text = milestoneText(d, announced);
        if (text != null) {
          fired.add(text);
          // Find which milestone was triggered and mark it
          for (final m in _distanceMilestones) {
            if (!announced.contains(m) && d <= m) {
              announced.add(m);
              break;
            }
          }
        }
      }

      expect(fired.length, 5);
      expect(fired[0], contains('50 kilometer'));
      expect(fired[1], contains('25 kilometer'));
      expect(fired[2], contains('10 kilometer'));
      expect(fired[3], contains('paanch kilometer'));
      expect(fired[4], contains('ek kilometer'));
    });
  });
}
