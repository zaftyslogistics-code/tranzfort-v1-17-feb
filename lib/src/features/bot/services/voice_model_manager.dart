import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages on-demand download of the Whisper STT model.
///
/// v2.0 — Piper TTS removed. TTS now uses platform flutter_tts (0 bytes).
/// Only Whisper STT model (~39MB) needs downloading for offline voice input.
/// Models are stored in the app's documents directory under `voice_models/`.
class VoiceModelManager {
  static final VoiceModelManager _instance = VoiceModelManager._();
  factory VoiceModelManager() => _instance;
  VoiceModelManager._();

  static const _modelsDir = 'voice_models';

  // ── Whisper STT model (~39MB) ─────────────────────────────────────────────
  static const whisperModelName = 'ggml-tiny.bin';
  static const _whisperUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin';

  String? _modelsPath;

  /// Get the base directory for voice models.
  Future<String> get modelsPath async {
    if (_modelsPath != null) return _modelsPath!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_modelsDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _modelsPath = dir.path;
    return _modelsPath!;
  }

  // ── Availability ──────────────────────────────────────────────────────────

  Future<bool> get isWhisperReady async {
    final path = await modelsPath;
    return File('$path/$whisperModelName').existsSync();
  }

  /// All required models ready (Whisper only since TTS is platform-based).
  Future<bool> get isAllReady async => isWhisperReady;

  /// Full path to the Whisper model file (or null if not downloaded).
  Future<String?> get whisperModelPath async {
    final path = await modelsPath;
    final file = File('$path/$whisperModelName');
    return file.existsSync() ? file.path : null;
  }

  // ── Download ──────────────────────────────────────────────────────────────

  /// Download Whisper STT model (~39MB). Returns true on success.
  Future<bool> downloadAll({
    void Function(int downloaded, int total)? onProgress,
  }) async {
    try {
      if (await isWhisperReady) {
        onProgress?.call(1, 1);
        return true;
      }

      final path = await modelsPath;
      const estimatedTotal = 39 * 1024 * 1024; // ~39 MB

      final ok = await _downloadFile(
        _whisperUrl,
        '$path/$whisperModelName',
        onProgress: (bytes) {
          onProgress?.call(bytes, estimatedTotal);
        },
      );
      if (ok) onProgress?.call(estimatedTotal, estimatedTotal);
      return ok;
    } catch (e) {
      debugPrint('VoiceModelManager.downloadAll error: $e');
      return false;
    }
  }

  Future<bool> _downloadFile(
    String url,
    String destPath, {
    void Function(int bytesDownloaded)? onProgress,
  }) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        debugPrint('Download failed: HTTP ${response.statusCode} for $url');
        return false;
      }

      final file = File(destPath);
      final sink = file.openWrite();
      int downloaded = 0;

      await for (final chunk in response) {
        sink.add(chunk);
        downloaded += chunk.length;
        onProgress?.call(downloaded);
      }

      await sink.flush();
      await sink.close();
      client.close();
      return true;
    } catch (e) {
      debugPrint('Download error for $url: $e');
      final partial = File(destPath);
      if (partial.existsSync()) partial.deleteSync();
      return false;
    }
  }

  /// Delete all downloaded models (for storage management).
  Future<void> deleteAll() async {
    final path = await modelsPath;
    final dir = Directory(path);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _modelsPath = null;
  }
}
