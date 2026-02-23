import 'package:flutter_test/flutter_test.dart';
import 'package:tranzfort/src/core/models/load_status.dart';

void main() {
  group('LoadStatus.fromString', () {
    test('parses all valid DB values', () {
      expect(LoadStatus.fromString('active'), LoadStatus.active);
      expect(LoadStatus.fromString('pending_approval'), LoadStatus.pendingApproval);
      expect(LoadStatus.fromString('booked'), LoadStatus.booked);
      expect(LoadStatus.fromString('in_transit'), LoadStatus.inTransit);
      expect(LoadStatus.fromString('delivered'), LoadStatus.delivered);
      expect(LoadStatus.fromString('completed'), LoadStatus.completed);
      expect(LoadStatus.fromString('cancelled'), LoadStatus.cancelled);
      expect(LoadStatus.fromString('expired'), LoadStatus.expired);
    });

    test('null defaults to active', () {
      expect(LoadStatus.fromString(null), LoadStatus.active);
    });

    test('unknown string defaults to active', () {
      expect(LoadStatus.fromString('garbage'), LoadStatus.active);
    });
  });

  group('LoadStatus.toDbValue', () {
    test('round-trips all values', () {
      for (final status in LoadStatus.values) {
        expect(LoadStatus.fromString(status.toDbValue()), status);
      }
    });
  });

  group('canTransitionTo — valid transitions', () {
    test('active → pending_approval', () {
      expect(LoadStatus.active.canTransitionTo(LoadStatus.pendingApproval), true);
    });

    test('active → cancelled', () {
      expect(LoadStatus.active.canTransitionTo(LoadStatus.cancelled), true);
    });

    test('active → expired', () {
      expect(LoadStatus.active.canTransitionTo(LoadStatus.expired), true);
    });

    test('pendingApproval → booked', () {
      expect(LoadStatus.pendingApproval.canTransitionTo(LoadStatus.booked), true);
    });

    test('pendingApproval → active (rejection)', () {
      expect(LoadStatus.pendingApproval.canTransitionTo(LoadStatus.active), true);
    });

    test('booked → inTransit', () {
      expect(LoadStatus.booked.canTransitionTo(LoadStatus.inTransit), true);
    });

    test('booked → cancelled', () {
      expect(LoadStatus.booked.canTransitionTo(LoadStatus.cancelled), true);
    });

    test('inTransit → delivered', () {
      expect(LoadStatus.inTransit.canTransitionTo(LoadStatus.delivered), true);
    });

    test('inTransit → completed', () {
      expect(LoadStatus.inTransit.canTransitionTo(LoadStatus.completed), true);
    });

    test('delivered → completed', () {
      expect(LoadStatus.delivered.canTransitionTo(LoadStatus.completed), true);
    });
  });

  group('canTransitionTo — invalid transitions', () {
    test('completed → anything is false', () {
      for (final status in LoadStatus.values) {
        expect(LoadStatus.completed.canTransitionTo(status), false);
      }
    });

    test('cancelled → anything is false', () {
      for (final status in LoadStatus.values) {
        expect(LoadStatus.cancelled.canTransitionTo(status), false);
      }
    });

    test('expired → anything is false', () {
      for (final status in LoadStatus.values) {
        expect(LoadStatus.expired.canTransitionTo(status), false);
      }
    });

    test('active → booked is invalid (must go through pendingApproval)', () {
      expect(LoadStatus.active.canTransitionTo(LoadStatus.booked), false);
    });

    test('active → completed is invalid', () {
      expect(LoadStatus.active.canTransitionTo(LoadStatus.completed), false);
    });

    test('booked → active is invalid', () {
      expect(LoadStatus.booked.canTransitionTo(LoadStatus.active), false);
    });

    test('delivered → active is invalid', () {
      expect(LoadStatus.delivered.canTransitionTo(LoadStatus.active), false);
    });
  });

  group('isTerminal', () {
    test('completed is terminal', () {
      expect(LoadStatus.completed.isTerminal, true);
    });

    test('cancelled is terminal', () {
      expect(LoadStatus.cancelled.isTerminal, true);
    });

    test('expired is terminal', () {
      expect(LoadStatus.expired.isTerminal, true);
    });

    test('active is not terminal', () {
      expect(LoadStatus.active.isTerminal, false);
    });

    test('inTransit is not terminal', () {
      expect(LoadStatus.inTransit.isTerminal, false);
    });
  });

  group('displayName', () {
    test('supplier English — active', () {
      expect(
        LoadStatus.active.displayName('supplier', 'en'),
        'Live — waiting for truckers',
      );
    });

    test('trucker English — active', () {
      expect(
        LoadStatus.active.displayName('trucker', 'en'),
        'Available',
      );
    });

    test('supplier Hindi — active', () {
      expect(
        LoadStatus.active.displayName('supplier', 'hi'),
        contains('लाइव'),
      );
    });

    test('trucker Hindi — active', () {
      expect(
        LoadStatus.active.displayName('trucker', 'hi'),
        'उपलब्ध',
      );
    });

    test('all statuses return non-empty for both roles and locales', () {
      for (final status in LoadStatus.values) {
        for (final role in ['supplier', 'trucker']) {
          for (final locale in ['en', 'hi']) {
            final name = status.displayName(role, locale);
            expect(name, isNotEmpty, reason: '$status/$role/$locale');
          }
        }
      }
    });
  });

  group('primaryAction', () {
    test('trucker can book active load', () {
      expect(LoadStatus.active.primaryAction('trucker'), 'Book Load');
    });

    test('supplier cannot book active load', () {
      expect(LoadStatus.active.primaryAction('supplier'), isNull);
    });

    test('supplier can approve/reject pending', () {
      expect(LoadStatus.pendingApproval.primaryAction('supplier'), 'Approve / Reject');
    });

    test('trucker cannot approve pending', () {
      expect(LoadStatus.pendingApproval.primaryAction('trucker'), isNull);
    });

    test('trucker can start trip when booked', () {
      expect(LoadStatus.booked.primaryAction('trucker'), 'Start Trip');
    });

    test('trucker can mark delivered when in transit', () {
      expect(LoadStatus.inTransit.primaryAction('trucker'), 'Mark Delivered');
    });

    test('supplier can confirm delivery', () {
      expect(LoadStatus.delivered.primaryAction('supplier'), 'Confirm Delivery');
    });

    test('terminal statuses have no action', () {
      for (final status in [LoadStatus.completed, LoadStatus.cancelled, LoadStatus.expired]) {
        expect(status.primaryAction('supplier'), isNull);
        expect(status.primaryAction('trucker'), isNull);
      }
    });
  });
}
