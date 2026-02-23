import 'package:flutter/foundation.dart';
import 'sqlite_cache.dart';

/// Task 9.2: Stale-While-Revalidate pattern.
/// Returns cached data immediately, then fetches fresh data in background.
/// On success: updates cache and calls onRefresh callback.
/// On failure: keeps showing cached data (offline-resilient).
class StaleWhileRevalidate {
  /// Fetch data with stale-while-revalidate strategy.
  ///
  /// [cacheTable] — SQLite cache table name (e.g. 'cached_loads')
  /// [cacheKey] — unique key for this query (e.g. 'active_loads_pune_delhi')
  /// [fetcher] — async function that fetches fresh data from network
  /// [onData] — called with data (cached first, then fresh if different)
  /// [onError] — called if both cache and network fail
  static Future<void> fetch<T>({
    required String cacheTable,
    required String cacheKey,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
    required void Function(List<Map<String, dynamic>> data, bool isCached) onData,
    void Function(String error)? onError,
  }) async {
    // 1. Try cache first
    bool servedFromCache = false;
    try {
      final cached = await CacheService.getById(cacheTable, cacheKey);
      if (cached != null && cached['items'] != null) {
        final items = (cached['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (items.isNotEmpty) {
          onData(items, true);
          servedFromCache = true;
          debugPrint('SWR [$cacheKey]: served ${items.length} items from cache');
        }
      }
    } catch (e) {
      debugPrint('SWR [$cacheKey]: cache read failed: $e');
    }

    // 2. Fetch fresh data in background
    try {
      final fresh = await fetcher();
      // Cache the result
      await CacheService.putAll(cacheTable, [
        {
          'id': cacheKey,
          'items': fresh,
        }
      ]);
      onData(fresh, false);
      debugPrint('SWR [$cacheKey]: refreshed with ${fresh.length} items from network');
    } catch (e) {
      debugPrint('SWR [$cacheKey]: network fetch failed: $e');
      if (!servedFromCache) {
        onError?.call(e.toString());
      }
    }
  }

  /// Simpler variant: returns cached data or fetches fresh.
  /// Returns null only if both cache and network fail.
  static Future<List<Map<String, dynamic>>?> get({
    required String cacheTable,
    required String cacheKey,
    required Future<List<Map<String, dynamic>>> Function() fetcher,
  }) async {
    // 1. Try cache
    List<Map<String, dynamic>>? cached;
    try {
      final row = await CacheService.getById(cacheTable, cacheKey);
      if (row != null && row['items'] != null) {
        cached = (row['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}

    // 2. Try network
    try {
      final fresh = await fetcher();
      await CacheService.putAll(cacheTable, [
        {
          'id': cacheKey,
          'items': fresh,
        }
      ]);
      return fresh;
    } catch (e) {
      debugPrint('SWR [$cacheKey]: network failed, returning cache: $e');
      return cached;
    }
  }

  /// Cache a single JSON-serializable map.
  static Future<void> cacheSingle(
    String table,
    String key,
    Map<String, dynamic> data,
  ) async {
    await CacheService.putAll(table, [
      {'id': key, ...data},
    ]);
  }

  /// Read a single cached item.
  static Future<Map<String, dynamic>?> readSingle(
    String table,
    String key,
  ) async {
    return CacheService.getById(table, key);
  }
}
