import 'package:shared_preferences/shared_preferences.dart';

/// Persists last-used form values for smart defaults across sessions.
class SmartDefaults {
  SmartDefaults._();

  static const _keyLastOriginCity = 'last_origin_city';
  static const _keyLastDestCity = 'last_dest_city';
  static const _keyLastSearchOrigin = 'last_search_origin';
  static const _keyLastSearchDest = 'last_search_dest';
  static const _keyLastBodyType = 'last_body_type';

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
}
