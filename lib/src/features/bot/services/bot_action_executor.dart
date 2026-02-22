import '../../../core/services/database_service.dart';
import '../models/bot_response.dart';

/// Executes bot actions that require database interaction.
/// Extracted from BasicBotService to isolate data access concerns.
/// Each method returns a BotResponse with the result of the action.
class BotActionExecutor {
  DatabaseService? _db;

  void setDatabaseService(DatabaseService db) => _db = db;

  bool get hasDatabase => _db != null;

  /// Execute the postLoad confirmation action.
  Future<BotResponse?> executePostLoad({
    required Map<String, dynamic> payload,
    required String language,
  }) async {
    if (_db == null) return null;

    try {
      // The actual post is handled by the confirm action in the UI layer.
      // This method prepares the payload for the UI to execute.
      return BotResponse(
        text: language == 'hi'
            ? '✅ लोड पोस्ट हो गया!'
            : '✅ Load posted successfully!',
        actions: [
          BotAction(
            label: language == 'hi' ? 'मेरे लोड देखें' : 'View My Loads',
            value: 'navigate',
            payload: {'route': '/my-loads'},
          ),
        ],
      );
    } catch (e) {
      return BotResponse(
        text: language == 'hi'
            ? '❌ लोड पोस्ट नहीं हो पाया। कृपया फिर से कोशिश करें।'
            : '❌ Failed to post load. Please try again.',
      );
    }
  }

  /// Fetch trucker's truck count and active trips for context.
  Future<Map<String, int>> getTruckerContext(String userId) async {
    if (_db == null) return {};
    try {
      final trucks = await _db!.getMyTrucks(userId);
      final trips = await _db!.getMyTrips(userId);
      final activeTrips =
          trips.where((t) => t['status'] != 'completed').length;
      return {
        'truck_count': trucks.length,
        'active_trips': activeTrips,
      };
    } catch (_) {
      return {};
    }
  }

  /// Fetch supplier's load summary for context.
  Future<Map<String, int>> getSupplierContext(String userId) async {
    if (_db == null) return {};
    try {
      final loads = await _db!.getMyLoads(userId);
      final active = loads.where((l) => l['status'] == 'active').length;
      final booked = loads.where((l) => l['status'] == 'booked').length;
      return {
        'total_loads': loads.length,
        'active_loads': active,
        'booked_loads': booked,
      };
    } catch (_) {
      return {};
    }
  }

  /// Fetch active trip for navigation suggestion.
  Future<Map<String, String>?> getActiveTrip(String userId) async {
    if (_db == null) return null;
    try {
      final trips = await _db!.getMyTrips(userId);
      final activeTrip = trips.cast<Map<String, dynamic>>().where(
        (t) => t['status'] == 'in_transit' || t['status'] == 'booked',
      ).toList();
      if (activeTrip.isNotEmpty) {
        final trip = activeTrip.first;
        return {
          'origin': trip['origin_city'] as String? ?? '',
          'destination': trip['dest_city'] as String? ?? '',
          'material': trip['material'] as String? ?? '',
        };
      }
    } catch (_) {}
    return null;
  }

  /// Build a trucker context response (my loads / my trips).
  Future<BotResponse> buildTruckerMyLoadsResponse({
    required String userId,
    required String language,
  }) async {
    final ctx = await getTruckerContext(userId);
    if (ctx.isNotEmpty) {
      final truckCount = ctx['truck_count'] ?? 0;
      final activeTrips = ctx['active_trips'] ?? 0;
      return BotResponse(
        text: language == 'hi'
            ? 'आपके $truckCount ट्रक हैं और $activeTrips एक्टिव ट्रिप हैं।'
            : 'You have $truckCount truck${truckCount == 1 ? '' : 's'} and $activeTrips active trip${activeTrips == 1 ? '' : 's'}.',
        actions: [
          BotAction(
            label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
            value: 'navigate',
            payload: {'route': '/my-trips'},
          ),
          BotAction(
            label: language == 'hi' ? 'लोड खोजें' : 'Find Loads',
            value: 'navigate',
            payload: {'route': '/find-loads'},
          ),
        ],
      );
    }
    return BotResponse(
      text: language == 'hi'
          ? 'आपकी ट्रिप देखने के लिए My Trips खोलें।'
          : 'Opening My Trips to view your active trips.',
      actions: [
        BotAction(
          label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
          value: 'navigate',
          payload: {'route': '/my-trips'},
        ),
      ],
    );
  }

  /// Build a supplier context response (my loads).
  Future<BotResponse> buildSupplierMyLoadsResponse({
    required String userId,
    required String language,
  }) async {
    final ctx = await getSupplierContext(userId);
    if (ctx.isNotEmpty) {
      final total = ctx['total_loads'] ?? 0;
      final active = ctx['active_loads'] ?? 0;
      final booked = ctx['booked_loads'] ?? 0;
      return BotResponse(
        text: language == 'hi'
            ? 'आपके लोड: कुल $total, एक्टिव $active, बुक $booked।'
            : 'Your loads: Total $total, Active $active, Booked $booked.',
        actions: [
          BotAction(
            label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
            value: 'navigate',
            payload: {'route': '/my-loads'},
          ),
        ],
      );
    }
    return BotResponse(
      text: language == 'hi'
          ? 'आपके लोड देखने के लिए My Loads खोलें।'
          : 'Opening My Loads to view your posted loads.',
      actions: [
        BotAction(
          label: language == 'hi' ? 'मेरे लोड' : 'My Loads',
          value: 'navigate',
          payload: {'route': '/my-loads'},
        ),
      ],
    );
  }

  /// Build a trucker trips response.
  Future<BotResponse> buildTruckerTripsResponse({
    required String userId,
    required String language,
  }) async {
    if (_db != null) {
      try {
        final trips = await _db!.getMyTrips(userId);
        final active = trips
            .where((t) =>
                t['status'] == 'booked' || t['status'] == 'in_transit')
            .length;
        final completed =
            trips.where((t) => t['status'] == 'completed').length;
        return BotResponse(
          text: language == 'hi'
              ? 'आपकी ट्रिप: एक्टिव $active, पूर्ण $completed।'
              : 'Your trips: Active $active, Completed $completed.',
          actions: [
            BotAction(
              label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
              value: 'navigate',
              payload: {'route': '/my-trips'},
            ),
          ],
        );
      } catch (_) {}
    }
    return BotResponse(
      text: language == 'hi'
          ? 'आपकी ट्रिप देखने के लिए My Trips खोलें।'
          : 'Opening My Trips to view your active trips.',
      actions: [
        BotAction(
          label: language == 'hi' ? 'मेरी ट्रिप' : 'My Trips',
          value: 'navigate',
          payload: {'route': '/my-trips'},
        ),
      ],
    );
  }

  /// Build a navigate response with active trip suggestion.
  Future<BotResponse?> buildNavigateWithTripResponse({
    required String userId,
    required String language,
  }) async {
    final trip = await getActiveTrip(userId);
    if (trip == null) return null;

    final origin = trip['origin'] ?? '';
    final dest = trip['destination'] ?? '';
    final material = trip['material'] ?? '';

    return BotResponse(
      text: language == 'hi'
          ? 'आपकी एक एक्टिव ट्रिप है: $origin से $dest ($material)। क्या इसका रास्ता दिखाऊँ?'
          : 'You have an active trip: $origin to $dest ($material). Navigate this trip?',
      actions: [
        BotAction(
          label: language == 'hi' ? 'ट्रिप नेविगेट करें' : 'Navigate Trip',
          value: 'navigate',
          payload: {
            'route': '/navigation',
            'origin': origin,
            'destination': dest,
          },
        ),
        BotAction(
          label: language == 'hi' ? 'कहीं और' : 'Somewhere else',
          value: 'navigate',
          payload: {'route': '/navigation'},
        ),
      ],
    );
  }
}
