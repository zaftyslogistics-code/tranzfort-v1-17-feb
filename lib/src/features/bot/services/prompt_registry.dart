import 'dart:convert';
import 'package:flutter/services.dart';

class PromptRegistry {
  final Map<String, Map<String, dynamic>> _cache = {};
  String _locale = 'en';
  String _version = '1.0.0';
  bool _isLoaded = false;

  static const _files = <String>[
    // System
    'system/identity',
    'system/rules',
    'system/onboarding',
    'system/domain',
    'system/safety',
    // Roles
    'roles/trucker',
    'roles/supplier',
    // Tasks
    'tasks/post_load/slots',
    'tasks/post_load/confirmation',
    'tasks/find_loads/slots',
    'tasks/find_loads/results',
    'tasks/book_load/slots',
    'tasks/book_load/confirmation',
    'tasks/super_load/slots',
    'tasks/super_load/confirmation',
    'tasks/navigate/slots',
    'tasks/check_status/prompts',
    // Clarify
    'clarify/clarify',
    // Errors
    'errors/errors',
    // Voice
    'voice/bot',
    'voice/navigation',
    // Offline
    'offline/fallbacks',
    // Admin
    'admin/canned_responses',
    'admin/notifications',
  ];

  String get version => _version;
  String get locale => _locale;
  bool get isLoaded => _isLoaded;

  Future<void> load({String locale = 'en'}) async {
    _locale = locale;
    _cache.clear();

    // Load meta
    try {
      final metaStr = await rootBundle.loadString('assets/prompts/_meta.json');
      final meta = json.decode(metaStr) as Map<String, dynamic>;
      _version = meta['version'] as String? ?? '1.0.0';
    } catch (_) {}

    // Load all prompt files for current locale
    for (final file in _files) {
      final path = 'assets/prompts/${file}_$locale.json';
      try {
        final content = await rootBundle.loadString(path);
        _cache[file] = json.decode(content) as Map<String, dynamic>;
      } catch (_) {
        // Try English fallback if locale file missing
        if (locale != 'en') {
          try {
            final fallbackPath = 'assets/prompts/${file}_en.json';
            final content = await rootBundle.loadString(fallbackPath);
            _cache[file] = json.decode(content) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    }

    _isLoaded = true;
  }

  Future<void> switchLocale(String locale) async {
    if (locale == _locale && _isLoaded) return;
    await load(locale: locale);
  }

  /// Get a prompt by dotted key path. Example: 'system.identity.greeting'
  /// Returns the template string, or [fallback] if not found.
  String get(String key, {String? fallback}) {
    final parts = key.split('.');
    if (parts.length < 2) return fallback ?? key;

    // Map dotted key to file + json key
    // e.g. 'system.identity.greeting' → file='system/identity', jsonKey='greeting'
    // e.g. 'tasks.post_load.slots.origin' → file='tasks/post_load/slots', jsonKey='origin'
    // e.g. 'errors.errors.network' → file='errors/errors', jsonKey='network'
    String filePath;
    String jsonKey;

    if (parts.length == 3 && parts[0] == 'tasks') {
      // tasks.post_load.slots → not enough parts
      filePath = '${parts[0]}/${parts[1]}/${parts[2]}';
      jsonKey = '';
    } else if (parts.length >= 4 && parts[0] == 'tasks') {
      filePath = '${parts[0]}/${parts[1]}/${parts[2]}';
      jsonKey = parts.sublist(3).join('.');
    } else if (parts.length == 3) {
      filePath = '${parts[0]}/${parts[1]}';
      jsonKey = parts[2];
    } else if (parts.length == 2) {
      filePath = parts[0];
      jsonKey = parts[1];
    } else {
      return fallback ?? key;
    }

    final fileData = _cache[filePath];
    if (fileData == null) return fallback ?? key;
    if (jsonKey.isEmpty) return fallback ?? key;

    final value = fileData[jsonKey];
    if (value is String) return value;
    return fallback ?? key;
  }

  /// Convenience: get prompt for current locale with automatic file resolution.
  String getForLocale(String key, String locale, {String? fallback}) {
    // If locale differs from loaded, return fallback (caller should switchLocale first)
    if (locale != _locale && _isLoaded) {
      return fallback ?? key;
    }
    return get(key, fallback: fallback);
  }
}
