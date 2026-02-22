import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists last-used form values for smart defaults across sessions.
class SmartDefaults {
  SmartDefaults._();

  static const _keyLastOriginCity = 'last_origin_city';
  static const _keyLastDestCity = 'last_dest_city';
  static const _keyLastSearchOrigin = 'last_search_origin';
  static const _keyLastSearchDest = 'last_search_dest';
  static const _keyLastBodyType = 'last_body_type';
  static const _keyRecentCities = 'recent_cities';
  static const _keySavedAddresses = 'saved_addresses';

  // ─── Post Load defaults ───

  static Future<void> saveLastRoute(String origin, String dest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastOriginCity, origin);
    await prefs.setString(_keyLastDestCity, dest);
  }

  static Future<(String?, String?)> getLastRoute() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getString(_keyLastOriginCity),
      prefs.getString(_keyLastDestCity),
    );
  }

  // ─── Find Loads search defaults ───

  static Future<void> saveLastSearch(String origin, String dest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSearchOrigin, origin);
    await prefs.setString(_keyLastSearchDest, dest);
  }

  static Future<(String?, String?)> getLastSearch() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getString(_keyLastSearchOrigin),
      prefs.getString(_keyLastSearchDest),
    );
  }

  // ─── Add Truck body type default ───

  static Future<void> saveLastBodyType(String bodyType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBodyType, bodyType);
  }

  static Future<String?> getLastBodyType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastBodyType);
  }

  // ─── LOC-B: Recent cities (last 5 unique) ───

  static Future<void> addRecentCity(String city, String state) async {
    if (city.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyRecentCities) ?? [];

    // Each entry stored as "city|state"
    final entry = '${city.trim()}|${state.trim()}';
    raw.remove(entry); // deduplicate
    raw.insert(0, entry); // most recent first
    if (raw.length > 5) raw.removeRange(5, raw.length);

    await prefs.setStringList(_keyRecentCities, raw);
  }

  static Future<List<({String city, String state})>> getRecentCities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyRecentCities) ?? [];
    return raw.map((e) {
      final parts = e.split('|');
      return (city: parts[0], state: parts.length > 1 ? parts[1] : '');
    }).toList();
  }

  // ─── LOC-A: Saved addresses (up to 10) ───

  static Future<void> saveAddress(String label, String city, String state) async {
    if (city.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedAddresses) ?? [];

    // Each entry stored as JSON: {"label":"...", "city":"...", "state":"..."}
    final entry = jsonEncode({
      'label': label.trim(),
      'city': city.trim(),
      'state': state.trim(),
    });

    // Deduplicate by city+state
    raw.removeWhere((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return m['city'] == city.trim() && m['state'] == state.trim();
      } catch (_) {
        return false;
      }
    });

    raw.insert(0, entry);
    if (raw.length > 10) raw.removeRange(10, raw.length);

    await prefs.setStringList(_keySavedAddresses, raw);
  }

  static Future<void> removeSavedAddress(String city, String state) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedAddresses) ?? [];
    raw.removeWhere((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return m['city'] == city && m['state'] == state;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_keySavedAddresses, raw);
  }

  static Future<List<({String label, String city, String state})>> getSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedAddresses) ?? [];
    return raw.map((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return (
          label: m['label'] as String? ?? '',
          city: m['city'] as String? ?? '',
          state: m['state'] as String? ?? '',
        );
      } catch (_) {
        return (label: '', city: '', state: '');
      }
    }).where((a) => a.city.isNotEmpty).toList();
  }

  // ─── TRK-2: Bookmarked / Saved Loads ───

  static const _keyBookmarkedLoads = 'bookmarked_load_ids';

  static Future<void> toggleBookmark(String loadId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyBookmarkedLoads) ?? [];
    if (ids.contains(loadId)) {
      ids.remove(loadId);
    } else {
      ids.add(loadId);
    }
    await prefs.setStringList(_keyBookmarkedLoads, ids);
  }

  static Future<bool> isBookmarked(String loadId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyBookmarkedLoads) ?? [];
    return ids.contains(loadId);
  }

  static Future<List<String>> getBookmarkedLoadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyBookmarkedLoads) ?? [];
  }

  // ─── P2-9: Saved Search Presets ───

  static const _keySavedSearches = 'saved_search_presets';

  /// Save a search preset as JSON. Max 5 presets.
  static Future<void> saveSearchPreset({
    required String origin,
    required String dest,
    String? truckType,
    String? material,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedSearches) ?? [];
    final entry = jsonEncode({
      'origin': origin,
      'dest': dest,
      if (truckType != null && truckType != 'Any') 'truck_type': truckType,
      if (material != null && material != 'Any') 'material': material,
    });
    // Deduplicate by origin+dest
    raw.removeWhere((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return m['origin'] == origin && m['dest'] == dest;
      } catch (_) {
        return false;
      }
    });
    raw.insert(0, entry);
    if (raw.length > 5) raw.removeRange(5, raw.length);
    await prefs.setStringList(_keySavedSearches, raw);
  }

  static Future<List<Map<String, String>>> getSavedSearchPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedSearches) ?? [];
    return raw.map((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return m.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        return <String, String>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  static Future<void> removeSavedSearch(String origin, String dest) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySavedSearches) ?? [];
    raw.removeWhere((e) {
      try {
        final m = jsonDecode(e) as Map<String, dynamic>;
        return m['origin'] == origin && m['dest'] == dest;
      } catch (_) {
        return false;
      }
    });
    await prefs.setStringList(_keySavedSearches, raw);
  }
}
