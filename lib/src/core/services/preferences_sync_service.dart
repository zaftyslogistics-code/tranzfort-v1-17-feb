import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Task 9.7: User Preferences Sync across devices.
/// Syncs locale, last search origin/destination, and default truck ID
/// to Supabase `user_preferences` table. Falls back to SharedPreferences
/// when offline.
class PreferencesSyncService {
  final SupabaseClient _supabase;

  PreferencesSyncService(this._supabase);

  static const _localKeys = [
    'pref_locale',
    'pref_last_search_origin',
    'pref_last_search_destination',
    'pref_default_truck_id',
  ];

  /// On login: pull preferences from Supabase and apply locally.
  Future<void> pullFromRemote(String userId) async {
    try {
      final response = await _supabase
          .from('user_preferences')
          .select('preferences')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return;

      final prefs = await SharedPreferences.getInstance();
      final remote = response['preferences'] as Map<String, dynamic>?;
      if (remote == null) return;

      for (final key in _localKeys) {
        final value = remote[key];
        if (value != null && value is String) {
          await prefs.setString(key, value);
        }
      }
      debugPrint('PreferencesSync: pulled ${remote.length} keys from remote');
    } catch (e) {
      debugPrint('PreferencesSync: pull failed (offline?): $e');
      // Silently fail — local prefs remain
    }
  }

  /// On preference change: push to Supabase (debounced by caller).
  Future<void> pushToRemote(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};

      for (final key in _localKeys) {
        final value = prefs.getString(key);
        if (value != null) {
          data[key] = value;
        }
      }

      if (data.isEmpty) return;

      await _supabase.from('user_preferences').upsert({
        'user_id': userId,
        'preferences': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      debugPrint('PreferencesSync: pushed ${data.length} keys to remote');
    } catch (e) {
      debugPrint('PreferencesSync: push failed (offline?): $e');
      // Silently fail — will sync on next connectivity
    }
  }

  /// Get a preference value (local-first).
  Future<String?> get(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  /// Set a preference value locally and queue remote sync.
  Future<void> set(String key, String value, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);

    // Push to remote if userId available
    if (userId != null) {
      await pushToRemote(userId);
    }
  }

  /// Convenience: get/set locale
  Future<String?> getLocale() => get('pref_locale');
  Future<void> setLocale(String locale, {String? userId}) =>
      set('pref_locale', locale, userId: userId);

  /// Convenience: get/set last search origin
  Future<String?> getLastSearchOrigin() => get('pref_last_search_origin');
  Future<void> setLastSearchOrigin(String origin, {String? userId}) =>
      set('pref_last_search_origin', origin, userId: userId);

  /// Convenience: get/set last search destination
  Future<String?> getLastSearchDestination() => get('pref_last_search_destination');
  Future<void> setLastSearchDestination(String dest, {String? userId}) =>
      set('pref_last_search_destination', dest, userId: userId);

  /// Convenience: get/set default truck ID
  Future<String?> getDefaultTruckId() => get('pref_default_truck_id');
  Future<void> setDefaultTruckId(String truckId, {String? userId}) =>
      set('pref_default_truck_id', truckId, userId: userId);
}
