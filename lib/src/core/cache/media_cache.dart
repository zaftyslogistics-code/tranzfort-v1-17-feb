import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Task 9.10: Media Cache with LRU Eviction.
/// Caches downloaded images/thumbnails/voice messages in media_cache/ directory.
/// LRU eviction: max 50 MB — evicts oldest on overflow.
class MediaCache {
  static const _cacheDir = 'media_cache';
  static const int maxCacheBytes = 50 * 1024 * 1024; // 50 MB

  static Directory? _dir;

  /// Get or create the media cache directory.
  static Future<Directory> _getCacheDir() async {
    if (_dir != null && await _dir!.exists()) return _dir!;
    final appDir = await getApplicationDocumentsDirectory();
    _dir = Directory('${appDir.path}/$_cacheDir');
    if (!await _dir!.exists()) {
      await _dir!.create(recursive: true);
    }
    return _dir!;
  }

  /// Generate a safe file name from a URL or key.
  static String _safeFileName(String key) {
    return key
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .substring(0, key.length.clamp(0, 100));
  }

  /// Get a cached file by key. Returns null if not cached.
  static Future<File?> get(String key) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/${_safeFileName(key)}');
    if (await file.exists()) {
      // Touch file to update access time (LRU)
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return file;
    }
    return null;
  }

  /// Put bytes into cache under the given key.
  static Future<File> put(String key, List<int> bytes) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/${_safeFileName(key)}');
    await file.writeAsBytes(bytes);
    debugPrint('MediaCache: cached ${(bytes.length / 1024).toStringAsFixed(0)} KB as $key');

    // Evict if over limit
    await _evictIfNeeded();
    return file;
  }

  /// Put a file into cache (copies it).
  static Future<File> putFile(String key, File source) async {
    final dir = await _getCacheDir();
    final dest = File('${dir.path}/${_safeFileName(key)}');
    await source.copy(dest.path);

    await _evictIfNeeded();
    return dest;
  }

  /// Check if a key is cached.
  static Future<bool> has(String key) async {
    final dir = await _getCacheDir();
    return File('${dir.path}/${_safeFileName(key)}').exists();
  }

  /// Remove a specific cached item.
  static Future<void> remove(String key) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/${_safeFileName(key)}');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get total cache size in bytes.
  static Future<int> totalSize() async {
    final dir = await _getCacheDir();
    if (!await dir.exists()) return 0;

    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Evict oldest files until cache is under the size limit.
  static Future<void> _evictIfNeeded() async {
    final dir = await _getCacheDir();
    if (!await dir.exists()) return;

    final files = <File>[];
    int totalBytes = 0;

    await for (final entity in dir.list()) {
      if (entity is File) {
        files.add(entity);
        totalBytes += await entity.length();
      }
    }

    if (totalBytes <= maxCacheBytes) return;

    // Sort by last modified (oldest first) for LRU eviction
    files.sort((a, b) {
      try {
        return a.lastModifiedSync().compareTo(b.lastModifiedSync());
      } catch (_) {
        return 0;
      }
    });

    int evicted = 0;
    for (final file in files) {
      if (totalBytes <= maxCacheBytes) break;
      try {
        final size = await file.length();
        await file.delete();
        totalBytes -= size;
        evicted++;
      } catch (_) {}
    }

    if (evicted > 0) {
      debugPrint('MediaCache: evicted $evicted files, cache now ${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB');
    }
  }

  /// Clear the entire media cache.
  static Future<void> clearAll() async {
    final dir = await _getCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _dir = null;
      debugPrint('MediaCache: cleared all');
    }
  }
}
