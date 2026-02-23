import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Task 9.9: Pending Uploads Retry.
/// Saves photos to pending_uploads/ before upload attempt.
/// On failure: retains local file, retries on connectivity restore.
/// On success: deletes local file, returns Storage URL.
/// Max 10 pending uploads to prevent unbounded storage growth.
class UploadQueueService {
  final SupabaseClient _supabase;
  static const int _maxPending = 10;
  static const _pendingDir = 'pending_uploads';

  UploadQueueService(this._supabase);

  /// Get the pending uploads directory.
  Future<Directory> _getPendingDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_pendingDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Save a file to the pending uploads directory before attempting upload.
  /// Returns the local pending path.
  Future<String> saveToPending(File file, String fileName) async {
    final dir = await _getPendingDir();

    // Enforce max pending limit
    final existing = dir.listSync().whereType<File>().toList();
    if (existing.length >= _maxPending) {
      // Delete oldest file to make room
      existing.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      await existing.first.delete();
      debugPrint('UploadQueue: evicted oldest pending file (max $_maxPending)');
    }

    final pendingPath = '${dir.path}/$fileName';
    await file.copy(pendingPath);
    debugPrint('UploadQueue: saved to pending: $fileName');
    return pendingPath;
  }

  /// Attempt to upload a file. If it fails, the file remains in pending_uploads/.
  /// Returns the storage URL on success, null on failure.
  Future<String?> uploadWithRetry({
    required String bucket,
    required String storagePath,
    required File file,
    bool isPrivate = false,
  }) async {
    // Save to pending first
    final fileName = storagePath.replaceAll('/', '_');
    final pendingPath = await saveToPending(file, fileName);

    try {
      await _supabase.storage.from(bucket).upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );

      // Upload succeeded — delete pending file
      final pendingFile = File(pendingPath);
      if (await pendingFile.exists()) {
        await pendingFile.delete();
      }

      // Return URL
      if (isPrivate) {
        return await _supabase.storage.from(bucket).createSignedUrl(storagePath, 3600);
      }
      return _supabase.storage.from(bucket).getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('UploadQueue: upload failed, file saved at $pendingPath: $e');
      return null; // File remains in pending_uploads/ for retry
    }
  }

  /// Process all pending uploads. Call on app launch + connectivity change.
  /// [uploadHandler] maps a pending file name back to bucket + storagePath.
  Future<int> processQueue(
    Future<bool> Function(File file, String fileName) uploadHandler,
  ) async {
    final dir = await _getPendingDir();
    final files = dir.listSync().whereType<File>().toList();

    if (files.isEmpty) return 0;

    debugPrint('UploadQueue: processing ${files.length} pending uploads');
    int successCount = 0;

    for (final file in files) {
      try {
        final fileName = file.path.split(Platform.pathSeparator).last;
        final success = await uploadHandler(file, fileName);
        if (success) {
          await file.delete();
          successCount++;
          debugPrint('UploadQueue: uploaded $fileName');
        }
      } catch (e) {
        debugPrint('UploadQueue: retry failed for ${file.path}: $e');
      }
    }

    debugPrint('UploadQueue: processed $successCount/${files.length}');
    return successCount;
  }

  /// Get count of pending uploads.
  Future<int> pendingCount() async {
    final dir = await _getPendingDir();
    if (!await dir.exists()) return 0;
    return dir.listSync().whereType<File>().length;
  }

  /// Clear all pending uploads (e.g. on logout).
  Future<void> clearAll() async {
    final dir = await _getPendingDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      debugPrint('UploadQueue: cleared all pending uploads');
    }
  }
}
