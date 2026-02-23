import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Task 9.1: SQLite Cache Layer for offline-first data access.
/// Provides table-level caching with TTL and max row limits.
class CacheService {
  static Database? _db;
  static const _dbName = 'tranzfort_cache.db';
  static const _dbVersion = 1;

  // TTL per table (in minutes)
  static const Map<String, int> _ttlMinutes = {
    'cached_loads': 5,
    'cached_trucks': 60,
    'cached_profile': 60,
    'cached_conversations': 30,
    'cached_notifications': 30,
  };

  // Max rows per table
  static const Map<String, int> _maxRows = {
    'cached_loads': 500,
    'cached_trucks': 200,
    'cached_conversations': 100,
    'cached_notifications': 200,
  };

  /// Initialize the cache database.
  static Future<Database> init() async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );

    debugPrint('CacheService: initialized at $path');
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Generic cache table: key-value with JSON data and timestamps
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_loads (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_trucks (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_profile (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_conversations (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_notifications (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Task 9.3: Offline action queue
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Task 9.5: Location pings (moved from in-memory List)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pending_pings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        heading REAL,
        speed REAL,
        battery_level INTEGER,
        timestamp INTEGER NOT NULL
      )
    ''');

    debugPrint('CacheService: tables created');
  }

  /// Get the database instance (must call init() first).
  static Database get db {
    assert(_db != null, 'CacheService.init() must be called first');
    return _db!;
  }

  // ─── Generic CRUD ───

  /// Put a list of items into a cache table.
  static Future<void> putAll(
    String table,
    List<Map<String, dynamic>> items, {
    String idField = 'id',
  }) async {
    final database = db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = database.batch();

    for (final item in items) {
      final id = item[idField]?.toString() ?? '';
      if (id.isEmpty) continue;
      batch.insert(
        table,
        {
          'id': id,
          'data': jsonEncode(item),
          'cached_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    // Enforce max rows
    await _enforceMaxRows(table);

    debugPrint('CacheService: put ${items.length} items into $table');
  }

  /// Get all non-expired items from a cache table.
  static Future<List<Map<String, dynamic>>> getAll(String table) async {
    final database = db;
    final ttl = _ttlMinutes[table] ?? 30;
    final cutoff = DateTime.now()
        .subtract(Duration(minutes: ttl))
        .millisecondsSinceEpoch;

    final rows = await database.query(
      table,
      where: 'cached_at > ?',
      whereArgs: [cutoff],
      orderBy: 'cached_at DESC',
    );

    return rows.map((row) {
      try {
        return jsonDecode(row['data'] as String) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();
  }

  /// Get a single item by ID from a cache table (returns null if expired).
  static Future<Map<String, dynamic>?> getById(String table, String id) async {
    final database = db;
    final ttl = _ttlMinutes[table] ?? 30;
    final cutoff = DateTime.now()
        .subtract(Duration(minutes: ttl))
        .millisecondsSinceEpoch;

    final rows = await database.query(
      table,
      where: 'id = ? AND cached_at > ?',
      whereArgs: [id, cutoff],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    try {
      return jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear a specific cache table.
  static Future<void> clear(String table) async {
    await db.delete(table);
    debugPrint('CacheService: cleared $table');
  }

  /// Clear all cache tables.
  static Future<void> clearAll() async {
    for (final table in _ttlMinutes.keys) {
      await db.delete(table);
    }
    debugPrint('CacheService: cleared all tables');
  }

  /// Remove expired entries from a table.
  static Future<int> purgeExpired(String table) async {
    final ttl = _ttlMinutes[table] ?? 30;
    final cutoff = DateTime.now()
        .subtract(Duration(minutes: ttl))
        .millisecondsSinceEpoch;

    final count = await db.delete(
      table,
      where: 'cached_at <= ?',
      whereArgs: [cutoff],
    );

    if (count > 0) {
      debugPrint('CacheService: purged $count expired rows from $table');
    }
    return count;
  }

  /// Enforce max row limit by deleting oldest entries.
  static Future<void> _enforceMaxRows(String table) async {
    final maxRows = _maxRows[table];
    if (maxRows == null) return;

    final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    if (count > maxRows) {
      final excess = count - maxRows;
      await db.rawDelete(
        'DELETE FROM $table WHERE id IN '
        '(SELECT id FROM $table ORDER BY cached_at ASC LIMIT ?)',
        [excess],
      );
      debugPrint('CacheService: evicted $excess rows from $table (max $maxRows)');
    }
  }

  /// Close the database.
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
